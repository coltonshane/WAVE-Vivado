`timescale 1 ns / 1 ps
/*
=================================================================================
HDMI_v1_0_S00_AXI.v
AXI slave controller for configuring and controlling the HDMI output pipeline.
The slave registers are mapped to PS memory, so the ARM cores have access to the 
encoder block as a peripheral.

Also includes six URAM buffers for LUTs and UI overlays. Addressing:

0x00000 to 0x0004F    Peripheral Registers (20x32b)
0x00050 to 0x07FFF    Reserved
0x08000 to 0x0FFFF    uram0: R LUT
0x10000 to 0x17FFF    uram1: G LUT
0x18000 to 0x1FFFF    uram2: B LUT
0x20000 to 0x27FFF    uram3: Top UI Overlay
0x28000 to 0x2FFFF    uram4: Bottom UI Overlay
0x30000 to 0x37FFF    uram5: Pop-up UI Overlay
0x38000 to 0x3FFFF    Rserved

Total address space is 256K (18-bit).

Copyright (C) 2020 by Shane W. Colton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=================================================================================
*/

module HDMI_v1_0_S00_AXI 
#(
  // Users to add parameters here

  // User parameters ends
	// Do not modify the parameters beyond this line

	// Width of S_AXI data bus
	parameter integer C_S_AXI_DATA_WIDTH = 32,
	// Width of S_AXI address bus
	parameter integer C_S_AXI_ADDR_WIDTH = 18
)
(
  // Users to add ports here
	
  // Slave Reg 0
  output wire [15:0] vx0,
  output wire [15:0] vy0,
  // Slave Reg 1
  output wire [15:0] vxDiv,
  output wire [15:0] vyDiv,
  // Slave Reg 2
  output wire [15:0] wHDMI,
  output wire [10:0] hImage2048,
  // Slave Reg 3
  output wire signed [17:0] q_mult_inv_HL2_LH2,
  // Slave Reg 4
  output wire signed [17:0] q_mult_inv_HH2,
  // Slave Reg 5
  output wire m00_axi_armed,
  output wire VSYNC_IF_reg,     // Registered value, drives the interrupt line.
  input wire VSYNC_IF_mod,      // Module input for setting FOT interrupt flag.
  // Slave Reg 6
  input wire [9:0] fifo_wr_count_LL2,
  input wire [9:0] fifo_wr_count_LH2,
  // Slave Reg 7
  input wire [9:0] fifo_wr_count_HL2,
  input wire [9:0] fifo_wr_count_HH2,
  // Slave Reg 8-11
  output wire [127:0] dc_RAM_addr_update_concat,
  // Slave Reg 12
  output wire [23:0] bit_discard_update_LL2,
  // Slave Reg 13
  output wire [23:0] bit_discard_update_LH2,
  // Slave Reg 14
  output wire [23:0] bit_discard_update_HL2,
  // Slave Reg 15
  output wire [23:0] bit_discard_update_HH2,
  // Slave Reg 16
  output wire [23:0] debug_shift0,
  output wire [1:0] debug_phase0,
  // Slave Reg 17
  output wire [23:0] debug_shift1,
  output wire [1:0] debug_phase1,
  // Slave Reg 18
  output wire [23:0] debug_shift2,
  output wire [1:0] debug_phase2,
  // Slave Reg 19
  output wire [23:0] debug_shift3,
  output wire [1:0] debug_phase3,
  // Slave Reg 20
  output wire [11:0] pop_ui_x0,
  output wire [11:0] pop_ui_y0,
  output wire pop_ui_enabled,
  output wire bot_ui_enabled,
  output wire top_ui_enabled,
  // URAM 3
  input wire [11:0] top_ui_raddr,
  output wire [63:0] top_ui_rdata,
  // URAM 4
  input wire [11:0] bot_ui_raddr,
  output wire [63:0] bot_ui_rdata,
  // URAM 5
  input wire [11:0] pop_ui_raddr,
  output wire [63:0] pop_ui_rdata,
  
	// User ports ends
	// Do not modify the ports beyond this line

	// Global Clock Signal
	input wire  S_AXI_ACLK,
	// Global Reset Signal. This Signal is Active LOW
	input wire  S_AXI_ARESETN,
	// Write address (issued by master, acceped by Slave)
	input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
	// Write channel Protection type. This signal indicates the
        // privilege and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
	input wire [2 : 0] S_AXI_AWPROT,
	// Write address valid. This signal indicates that the master signaling
        // valid write address and control information.
	input wire  S_AXI_AWVALID,
	// Write address ready. This signal indicates that the slave is ready
        // to accept an address and associated control signals.
	output wire  S_AXI_AWREADY,
	// Write data (issued by master, acceped by Slave) 
	input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
	// Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.    
	input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
	// Write valid. This signal indicates that valid write
        // data and strobes are available.
	input wire  S_AXI_WVALID,
	// Write ready. This signal indicates that the slave
        // can accept the write data.
	output wire  S_AXI_WREADY,
	// Write response. This signal indicates the status
        // of the write transaction.
	output wire [1 : 0] S_AXI_BRESP,
	// Write response valid. This signal indicates that the channel
        // is signaling a valid write response.
	output wire  S_AXI_BVALID,
	// Response ready. This signal indicates that the master
   		// can accept a write response.
	input wire  S_AXI_BREADY,
	// Read address (issued by master, acceped by Slave)
	input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
	// Protection type. This signal indicates the privilege
   		// and security level of the transaction, and whether the
   		// transaction is a data access or an instruction access.
	input wire [2 : 0] S_AXI_ARPROT,
	// Read address valid. This signal indicates that the channel
   		// is signaling valid read address and control information.
	input wire  S_AXI_ARVALID,
	// Read address ready. This signal indicates that the slave is
   		// ready to accept an address and associated control signals.
	output wire  S_AXI_ARREADY,
	// Read data (issued by slave)
	output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
	// Read response. This signal indicates the status of the
   		// read transfer.
	output wire [1 : 0] S_AXI_RRESP,
	// Read valid. This signal indicates that the channel is
   		// signaling the required read data.
	output wire  S_AXI_RVALID,
	// Read ready. This signal indicates that the master can
   		// accept the read data and response information.
	input wire  S_AXI_RREADY
);

// AXI4LITE signals
reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
reg  	axi_awready;
reg  	axi_wready;
reg [1 : 0] 	axi_bresp;
reg  	axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
reg  	axi_arready;
reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
reg [1 : 0] 	axi_rresp;
reg  	axi_rvalid;

// Example-specific design signals
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 4;
//----------------------------------------------
//-- Signals for user logic register space example
//------------------------------------------------
//-- Number of Slave Registers: 21 <= 2^(OPT_MEM_ADDR_BITS+1)
reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg [20:0];
wire	 slv_reg_rden;
wire	 slv_reg_wren;
reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
integer	 byte_index;
reg	 aw_en;

// I/O Connections assignments
assign S_AXI_AWREADY	= axi_awready;
assign S_AXI_WREADY	= axi_wready;
assign S_AXI_BRESP	= axi_bresp;
assign S_AXI_BVALID	= axi_bvalid;
assign S_AXI_ARREADY	= axi_arready;
assign S_AXI_RDATA	= axi_rdata;
assign S_AXI_RRESP	= axi_rresp;
assign S_AXI_RVALID	= axi_rvalid;

// Implement axi_awready generation
// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
// de-asserted when reset is low.
always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
        axi_awready <= 1'b0;
        aw_en <= 1'b1;
    end 
    else
    begin    
	   if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	   begin
	       // slave is ready to accept write address when 
	       // there is a valid write address and write data
	       // on the write address and data bus. This design 
	       // expects no outstanding transactions. 
	       axi_awready <= 1'b1;
	       aw_en <= 1'b0;
	   end
	   else if (S_AXI_BREADY && axi_bvalid)
	   begin
	       aw_en <= 1'b1;
	       axi_awready <= 1'b0;
	   end
	   else           
	   begin
	       axi_awready <= 1'b0;
	   end
    end 
end       

// Implement axi_awaddr latching
// This process is used to latch the address when both 
// S_AXI_AWVALID and S_AXI_WVALID are valid. 
always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
        axi_awaddr <= 0;
    end 
    else
    begin    
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
        begin
            // Write Address latching 
	        axi_awaddr <= S_AXI_AWADDR;
	   end
    end 
end       

// Implement axi_wready generation
// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
// de-asserted when reset is low. 
always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
        axi_wready <= 1'b0;
    end 
    else
    begin    
        if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	    begin
	       // slave is ready to accept write data when 
	       // there is a valid write address and write data
	       // on the write address and data bus. This design 
	       // expects no outstanding transactions. 
	       axi_wready <= 1'b1;
        end
        else
        begin
	       axi_wready <= 1'b0;
	    end
	end 
end       

// Implement memory mapped register select and write logic generation
// The write data is accepted and written to memory mapped registers when
// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
// select byte enables of slave registers while writing.
// These registers are cleared when reset (active low) is applied.
// Slave register write enable is asserted when valid address and data are available
// and the slave is ready to accept the write address and write data.
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h0);

always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin : s_axi_areset_block
        integer i;
        for(i = 0; i < 21; i = i + 1)
        begin
            slv_reg[i] <= 0;
        end
	end : s_axi_areset_block
	else 
	begin
	    if (slv_reg_wren)
	    begin
            slv_reg[axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]] <= S_AXI_WDATA[C_S_AXI_DATA_WIDTH-1:0];
	    end
	    else
	    
	    // Latch in read values from input ports.
	    begin : in_latch
          // Slave Reg 5
          slv_reg[5][16] <= VSYNC_IF_mod;
          // Slave Reg 6
          slv_reg[6] <= {6'b0, fifo_wr_count_LH2, 6'b0, fifo_wr_count_LL2};
          // Slave Reg 7
          slv_reg[7] <= {6'b0, fifo_wr_count_HH2, 6'b0, fifo_wr_count_HL2};
	    end : in_latch
	    
	end
end    

// Implement write response logic generation
// The write response and response valid signals are asserted by the slave 
// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
// This marks the acceptance of address and indicates the status of 
// write transaction.

always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
	begin
        axi_bvalid  <= 0;
	    axi_bresp   <= 2'b0;
	end 
	else
	begin    
        if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	    begin
            // indicates a valid write response is available
	        axi_bvalid <= 1'b1;
	        axi_bresp  <= 2'b0; // 'OKAY' response 
	    end                   // work error responses in future
	    else
	    begin
	        if (S_AXI_BREADY && axi_bvalid) 
	        //check if bready is asserted while bvalid is high) 
	        //(there is a possibility that bready is always asserted high)   
	        begin
                axi_bvalid <= 1'b0; 
	        end  
	    end
	end
end   

// Implement axi_arready generation
// axi_arready is asserted for one S_AXI_ACLK clock cycle when
// S_AXI_ARVALID is asserted. axi_awready is 
// de-asserted when reset (active low) is asserted. 
// The read address is also latched when S_AXI_ARVALID is 
// asserted. axi_araddr is reset to zero on reset assertion.

always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
	begin
	   axi_arready <= 1'b0;
	   axi_araddr  <= 32'b0;
	end 
	else
	begin    
	    if (~axi_arready && S_AXI_ARVALID)
	    begin       
	        // indicates that the slave has acceped the valid read address
	        axi_arready <= 1'b1;
	        // Read address latching
	        axi_araddr  <= S_AXI_ARADDR;
	    end
	    else
	    begin
	        axi_arready <= 1'b0;
	    end
    end 
end       

// Implement axi_arvalid generation
// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
// data are available on the axi_rdata bus at this instance. The 
// assertion of axi_rvalid marks the validity of read data on the 
// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
// is deasserted on reset (active low). axi_rresp and axi_rdata are 
// cleared to zero on reset (active low).  
always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
	begin
        axi_rvalid <= 0;
	    axi_rresp  <= 0;
	end 
	else
	begin    
	    if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	    begin
	        // Valid read data is available at the read data bus
	        axi_rvalid <= 1'b1;
	        axi_rresp  <= 2'b0; // 'OKAY' response
	    end   
	    else if (axi_rvalid && S_AXI_RREADY)
	    begin
            // Read data is accepted by the master
	        axi_rvalid <= 1'b0;
	    end                
	end
end    

// Memory-mapped URAM buffers.
// --------------------------------------------------------------------------------------------------------
// Write enable switch.
wire uram0_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h1);
wire uram1_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h2);
wire uram2_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h3);
wire uram3_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h4);
wire uram4_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h5);
wire uram5_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[17:15] == 3'h6);

// Read data (after 64b to 32b translation).
wire [31:0] uram0_rdata;
wire [31:0] uram1_rdata;
wire [31:0] uram2_rdata;
wire [31:0] uram3_rdata;
wire [31:0] uram4_rdata;
wire [31:0] uram5_rdata;

// URAM module instanciations.
axi_slave_uram uram0
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram0_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram0_rdata),
  .mod_raddr(),
  .mod_rdata()
);
axi_slave_uram uram1
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram1_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram1_rdata),
  .mod_raddr(),
  .mod_rdata()
);
axi_slave_uram uram2
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram2_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram2_rdata),
  .mod_raddr(),
  .mod_rdata()
);
axi_slave_uram uram3
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram3_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram3_rdata),
  .mod_raddr(top_ui_raddr),
  .mod_rdata(top_ui_rdata)
);
axi_slave_uram uram4
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram4_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram4_rdata),
  .mod_raddr(bot_ui_raddr),
  .mod_rdata(bot_ui_rdata)
);
axi_slave_uram uram5
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram5_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram5_rdata),
  .mod_raddr(pop_ui_raddr),
  .mod_rdata(pop_ui_rdata)
);
// --------------------------------------------------------------------------------------------------------

// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
always @(*)
begin
  case (axi_araddr[17:15])
  default: reg_data_out <= slv_reg[axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]];
  3'h1: reg_data_out <= uram0_rdata;
  3'h2: reg_data_out <= uram1_rdata;
  3'h3: reg_data_out <= uram2_rdata;
  3'h4: reg_data_out <= uram3_rdata;
  3'h5: reg_data_out <= uram4_rdata;
  3'h6: reg_data_out <= uram5_rdata;
  endcase
end

// Output register or memory read data
always @( posedge S_AXI_ACLK )
begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
	    axi_rdata  <= 0;
    end 
    else
	begin    
	    // When there is a valid read address (S_AXI_ARVALID) with 
	    // acceptance of read address by the slave (axi_arready), 
	    // output the read dada 
	    if (slv_reg_rden)
        begin
            axi_rdata <= reg_data_out;     // register read data
	    end   
	end
end    

// Add user logic here
genvar i;

// Slave Reg 0
assign vx0 = slv_reg[0][15:0];
assign vy0 = slv_reg[0][31:16];
// Slave Reg 1
assign vxDiv = slv_reg[1][15:0];
assign vyDiv = slv_reg[1][31:16];
// Slave Reg 2
assign wHDMI = slv_reg[2][15:0];
assign hImage2048 = slv_reg[2][26:16];
// Slave Reg 3
assign q_mult_inv_HL2_LH2 = slv_reg[3][17:0];
// Slave Reg 4
assign q_mult_inv_HH2 = slv_reg[4][17:0];
// Slave Reg 5
assign m00_axi_armed = slv_reg[5][28];
assign VSYNC_IF_reg = slv_reg[5][16];
for(i = 0; i < 4; i = i + 1)
begin
  // Slave Reg 8-11
  assign dc_RAM_addr_update_concat[32*i+:32] = slv_reg[i+8];
end
// Slave Reg 12
assign bit_discard_update_LL2 = slv_reg[12][23:0];
// Slave Reg 13
assign bit_discard_update_LH2 = slv_reg[13][23:0];
// Slave Reg 14
assign bit_discard_update_HL2 = slv_reg[14][23:0];
// Slave Reg 15
assign bit_discard_update_HH2 = slv_reg[15][23:0];
// Slave Reg 16
assign debug_shift0 = slv_reg[16][23:0];
assign debug_phase0 = slv_reg[16][25:24];
// Slave Reg 17
assign debug_shift1 = slv_reg[17][23:0];
assign debug_phase1 = slv_reg[17][25:24];
// Slave Reg 18
assign debug_shift2 = slv_reg[18][23:0];
assign debug_phase2 = slv_reg[18][25:24];
// Slave Reg 19
assign debug_shift3 = slv_reg[19][23:0];
assign debug_phase3 = slv_reg[19][25:24];
// Slave Reg 20
assign pop_ui_x0 = slv_reg[20][11:0];
assign pop_ui_y0 = slv_reg[20][23:12];
assign pop_ui_enabled = slv_reg[20][24];
assign bot_ui_enabled = slv_reg[20][25];
assign top_ui_enabled = slv_reg[20][26];

// User logic ends

endmodule