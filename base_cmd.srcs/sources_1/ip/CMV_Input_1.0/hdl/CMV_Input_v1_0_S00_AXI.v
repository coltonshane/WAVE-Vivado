`timescale 1 ns / 1 ps
/*
=================================================================================
CMV_Input_v1_0_S00_AXI.v
AXI slave controller for controlling and configuring the CMV12000 read-in. The 
slave registers are mapped to PS memory, so the ARM cores have access to the CMV
input block as a peripheral, for configuration and control (link training).

Also includes URAM buffers for dark row/col bias LUTs. Addressing:

0x00000 to 0x00123    Peripheral Registers (73x32b)
0x00124 to 0x07FFF    Reserved
0x08000 to 0x0FFFF    uram00: Dark Col 0
0x10000 to 0x17FFF    uram01: Dark Col 1
0x18000 to 0x1FFFF    uram02: Dark Col 2
0x20000 to 0x27FFF    uram03: Dark Col 3
0x28000 to 0x2FFFF    uram04: Dark Col 4
0x30000 to 0x37FFF    uram05: Dark Col 5
0x38000 to 0x3FFFF    uram06: Dark Col 6
0x40000 to 0x47FFF    uram07: Dark Col 7
0x48000 to 0x4FFFF    uram08: Dark Row
0x50000 to 0x7FFFF    Reserved

Total address space is 512K (19-bit).

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

module CMV_Input_v1_0_S00_AXI #
(
    // Users to add parameters here

    // User parameters ends
	// Do not modify the parameters beyond this line

	// Width of S_AXI data bus
	parameter integer C_S_AXI_DATA_WIDTH = 32,
	// Width of S_AXI address bus
	parameter integer C_S_AXI_ADDR_WIDTH = 19
)
(
	// Users to add ports here
	    
  // CMV12000 pixel channels config and data. 
  // These are arrayed  and tied to slave registers in user logic.
  output wire [575:0] cmv_chXX_delay_target_concat,
  output wire [255:0] cmv_chXX_bitslip_concat,
  output wire [127:0] cmv_chXX_px_phase_concat,
  input wire [1023:0] cmv_chXX_px_data_concat,

  // CMV12000 control channel config and data.
  output wire [8:0] cmv_ctr_delay_target,
  output wire [3:0] cmv_ctr_bitslip,
  output wire [1:0] cmv_ctr_px_phase,
  input wire [15:0] cmv_ctr_px_data,
   
  // Pixel counter limit.
  output wire signed [23:0] px_count_limit,
   
  // Master pixel counter.
  input wire signed [23:0] px_count,
    
  // FOT interrupt flag.
  output wire FOT_IF_reg,     // Registered value, drives the interrupt line.
  input wire FOT_IF_mod,      // Module input for setting FOT interrupt flag.
    
  // CMV12000 timining control.
  output wire [31:0] frame_interval,
  output wire [31:0] FRAME_REQ_on,
  output wire [31:0] T_EXP1_on,
  output wire [31:0] T_EXP2_on,
  
  // URAM 00
  input wire [11:0] lut_dark_col_0_raddr,
  output wire [63:0] lut_dark_col_0_rdata,
  // URAM 01
  input wire [11:0] lut_dark_col_1_raddr,
  output wire [63:0] lut_dark_col_1_rdata,
  // URAM 02
  input wire [11:0] lut_dark_col_2_raddr,
  output wire [63:0] lut_dark_col_2_rdata,
  // URAM 03
  input wire [11:0] lut_dark_col_3_raddr,
  output wire [63:0] lut_dark_col_3_rdata,
  // URAM 04
  input wire [11:0] lut_dark_col_4_raddr,
  output wire [63:0] lut_dark_col_4_rdata,
  // URAM 05
  input wire [11:0] lut_dark_col_5_raddr,
  output wire [63:0] lut_dark_col_5_rdata,
  // URAM 06
  input wire [11:0] lut_dark_col_6_raddr,
  output wire [63:0] lut_dark_col_6_rdata,
  // URAM 07
  input wire [11:0] lut_dark_col_7_raddr,
  output wire [63:0] lut_dark_col_7_rdata,
  // URAM 08
  input wire [11:0] lut_dark_row_raddr,
  output wire [63:0] lut_dark_row_rdata,
  
  // Always-on pixel counter. Used by AXI slave for data synchronization.
  input wire [1:0] px_count_always_on,
    
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
localparam integer OPT_MEM_ADDR_BITS = 6;
//----------------------------------------------
//-- Signals for user logic register space example
//------------------------------------------------
//-- Number of Slave Registers: 73 <= 2^(OPT_MEM_ADDR_BITS+1)
reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg [72:0];

// Make array views of the CMV12000 pixel channel I/O ports.
wire [8:0] cmv_chXX_delay_target [63:0];
wire [3:0] cmv_chXX_bitslip [63:0];
wire [1:0] cmv_chXX_px_phase [63:0];
wire [15:0] cmv_chXX_px_data [63:0];
genvar i;
for(i = 0; i < 64; i = i + 1)
begin
    assign cmv_chXX_delay_target[i] = cmv_chXX_delay_target_concat[9*i+:9];
    assign cmv_chXX_bitslip[i] = cmv_chXX_bitslip_concat[4*i+:4];
    assign cmv_chXX_px_phase[i] = cmv_chXX_px_phase_concat[2*i+:2];
    assign cmv_chXX_px_data[i] = cmv_chXX_px_data_concat[16*i+:16];
end

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

// Synchronization gates for data capture.
// 1. capture_hold_sw: Inhibit capture to allow synchonous read by software. Set by software through a slave register.
// 2. capture_en_hw: Hardware enables capture on the second S_AXI_ACLK after a px_clk, to ensure data validity.
wire capture_hold_sw;
wire capture_en_hw;
reg signed [1:0] px_count_always_on_prev[1:0];
always @(posedge S_AXI_ACLK)
begin
  px_count_always_on_prev[0] <= px_count_always_on;
  px_count_always_on_prev[1] <= px_count_always_on_prev[0];
end
assign capture_en_hw = (px_count_always_on == px_count_always_on_prev[0]) && (px_count_always_on_prev[0] != px_count_always_on_prev[1]);     

// Implement memory mapped register select and write logic generation
// The write data is accepted and written to memory mapped registers when
// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
// select byte enables of slave registers while writing.
// These registers are cleared when reset (active low) is applied.
// Slave register write enable is asserted when valid address and data are available
// and the slave is ready to accept the write address and write data.
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h0);

always @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
  begin : s_axi_areset_block
    integer i;
    for(i = 0; i < 73; i = i + 1)
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
    begin
      // Latch in read values from input ports.
	    if(capture_en_hw & ~capture_hold_sw)
	    begin : data_capture
	      // Pixel channels.
        integer j;
        for(j = 0; j < 64; j = j + 1)
        begin
          slv_reg[j][15:0] <= cmv_chXX_px_data [j];
        end
    
        // Control channel.
        slv_reg[64][15:0] <= cmv_ctr_px_data;
            
        // Master pixel counter.
        slv_reg[66][23:0] <= px_count;
      end : data_capture   
      
      // Interrupt flag.
      slv_reg[67][0] <= FOT_IF_mod;
	  end
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
wire uram00_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h1);
wire uram01_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h2);
wire uram02_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h3);
wire uram03_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h4);
wire uram04_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h5);
wire uram05_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h6);
wire uram06_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h7);
wire uram07_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h8);
wire uram08_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID && (axi_awaddr[18:15] == 4'h9);

// Read data (after 64b to 32b translation).
wire [31:0] uram00_rdata;
wire [31:0] uram01_rdata;
wire [31:0] uram02_rdata;
wire [31:0] uram03_rdata;
wire [31:0] uram04_rdata;
wire [31:0] uram05_rdata;
wire [31:0] uram06_rdata;
wire [31:0] uram07_rdata;
wire [31:0] uram08_rdata;

// URAM module instanciations.
axi_slave_uram uram00
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram00_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram00_rdata),
  .mod_raddr(lut_dark_col_0_raddr),
  .mod_rdata(lut_dark_col_0_rdata)
);
axi_slave_uram uram01
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram01_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram01_rdata),
  .mod_raddr(lut_dark_col_1_raddr),
  .mod_rdata(lut_dark_col_1_rdata)
);
axi_slave_uram uram02
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram02_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram02_rdata),
  .mod_raddr(lut_dark_col_2_raddr),
  .mod_rdata(lut_dark_col_2_rdata)
);
axi_slave_uram uram03
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram03_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram03_rdata),
  .mod_raddr(lut_dark_col_3_raddr),
  .mod_rdata(lut_dark_col_3_rdata)
);
axi_slave_uram uram04
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram04_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram04_rdata),
  .mod_raddr(lut_dark_col_4_raddr),
  .mod_rdata(lut_dark_col_4_rdata)
);
axi_slave_uram uram05
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram05_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram05_rdata),
  .mod_raddr(lut_dark_col_5_raddr),
  .mod_rdata(lut_dark_col_5_rdata)
);
axi_slave_uram uram06
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram06_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram06_rdata),
  .mod_raddr(lut_dark_col_6_raddr),
  .mod_rdata(lut_dark_col_6_rdata)
);
axi_slave_uram uram07
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram07_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram07_rdata),
  .mod_raddr(lut_dark_col_7_raddr),
  .mod_rdata(lut_dark_col_7_rdata)
);
axi_slave_uram uram08
(
  .s_axi_aclk(S_AXI_ACLK),
  .axi_wen(uram08_wen),
  .axi_waddr(axi_awaddr),
  .axi_wdata(S_AXI_WDATA),
  .axi_raddr(S_AXI_ARADDR),
  .axi_rdata(uram08_rdata),
  .mod_raddr(lut_dark_row_raddr),
  .mod_rdata(lut_dark_row_rdata)
);

// --------------------------------------------------------------------------------------------------------

// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
always @(*)
begin
  case (axi_araddr[18:15])
  default: reg_data_out <= slv_reg[axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]];
  4'h1: reg_data_out <= uram00_rdata;
  4'h2: reg_data_out <= uram01_rdata;
  4'h3: reg_data_out <= uram02_rdata;
  4'h4: reg_data_out <= uram03_rdata;
  4'h5: reg_data_out <= uram04_rdata;
  4'h6: reg_data_out <= uram05_rdata;
  4'h7: reg_data_out <= uram06_rdata;
  4'h8: reg_data_out <= uram07_rdata;
  4'h9: reg_data_out <= uram08_rdata;
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

// Map the slave register outputs to the output ports.
// Pixel channels.
for(i = 0; i < 64; i = i + 1)
begin
    assign cmv_chXX_px_phase [i] = slv_reg [i] [29:28];
    assign cmv_chXX_bitslip [i] = slv_reg [i] [27:24];
    assign cmv_chXX_delay_target [i] = {slv_reg [i] [23:16], 1'b0}; // << 1 for 9-bit delay 
end

// Control channel.
assign cmv_ctr_px_phase = slv_reg [64] [29:28];
assign cmv_ctr_bitslip = slv_reg [64] [27:24];
assign cmv_ctr_delay_target = {slv_reg [64] [23:16], 1'b0}; // << 1 for 9-bit delay

// Pixel counter limit.
assign px_count_limit = slv_reg[65][23:0];

// FOT interrupt flag registered value.
assign FOT_IF_reg = slv_reg[67][0];

// CMV12000 timining control.
assign frame_interval = slv_reg[68];
assign FRAME_REQ_on = slv_reg[69];
assign T_EXP1_on = slv_reg[70];
assign T_EXP2_on = slv_reg[71];

// Capture hold.
assign capture_hold_sw = slv_reg[72][0];

// User logic ends

endmodule