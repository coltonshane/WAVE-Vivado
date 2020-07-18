`timescale 1 ns / 1 ps
/*
===================================================================================
HDMI_v1_0.v
Top module of HDMI output pipeline. This module includes:
- AXI Master for reading encoded image data from RAM.
- Decoding and dequantizing of LH2, HL2, and HH2. (LL2 is raw.)
- Vertical and horizontal IDWT for Stage 2, to recover LL1 color fields.
- Bilinear interpolation on LL1 color fields for scaling and debayer.
- Menu overlay.
- Generation of 8b (s)RGB 4:4:4 HDMI outputs.
- Generation of HDMI pixel clock, HSYNC, VSYNC, and DE signals.

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
===================================================================================
*/

// Decompressor state enumeration.
`define DC_STATE_FIFO_RST 2'b00
`define DC_STATE_FIFO_FILL 2'b01
`define DC_STATE_BIT_DISCARD 2'b10
`define DC_STATE_PX_CONSUME 2'b11

module HDMI_v1_0
#(
  // User Parameters
  parameter integer PX_MATH_WIDTH = 12,

	// Parameters for AXI-Lite Slave.
	parameter integer C_S00_AXI_DATA_WIDTH = 32,
	parameter integer C_S00_AXI_ADDR_WIDTH = 19,
	
  // Parameters of AXI Master.
  parameter C_M00_AXI_TARGET_SLAVE_BASE_ADDR = 32'h00000000,
  parameter integer C_M00_AXI_BURST_LEN = 16,
  parameter integer C_M00_AXI_ID_WIDTH = 1,
  parameter integer C_M00_AXI_ADDR_WIDTH = 32,
  parameter integer C_M00_AXI_DATA_WIDTH = 64,
  parameter integer C_M00_AXI_AWUSER_WIDTH = 0,
  parameter integer C_M00_AXI_ARUSER_WIDTH = 0,
  parameter integer C_M00_AXI_WUSER_WIDTH = 0,
  parameter integer C_M00_AXI_RUSER_WIDTH = 0,
  parameter integer C_M00_AXI_BUSER_WIDTH = 0
)
(
	// Users to add ports here
	
	// HDMI clock control.
	input wire hdmi_clk_en,
	input wire hdmi_pll_locked,
	input wire hdmi_clk,
	
	// ADV7513 interface.
	output wire [7:0] R,
	output wire [7:0] G,
	output wire [7:0] B,
	output wire HSYNC,
	output wire VSYNC,
	output wire DE,
	output wire CLK,
	
	// VSYNC interrupt output to PS.
  output wire VSYNC_int,
	
	// User ports ends
	// Do not modify the ports beyond this line

  // Ports for AXI-Lite Slave.
  input wire s00_axi_aclk,
  input wire s00_axi_aresetn,
  input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
  input wire [2 : 0] s00_axi_awprot,
  input wire s00_axi_awvalid,
  output wire s00_axi_awready,
  input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
  input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
  input wire s00_axi_wvalid,
  output wire s00_axi_wready,
  output wire [1 : 0] s00_axi_bresp,
  output wire s00_axi_bvalid,
  input wire s00_axi_bready,
  input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
  input wire [2 : 0] s00_axi_arprot,
  input wire s00_axi_arvalid,
  output wire s00_axi_arready,
  output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
  output wire [1 : 0] s00_axi_rresp,
  output wire s00_axi_rvalid,
  input wire s00_axi_rready,
  
  // Ports for AXI Master.
  input wire m00_axi_aclk,
  input wire m00_axi_aresetn,
  output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_awid,
  output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
  output wire [7 : 0] m00_axi_awlen,
  output wire [2 : 0] m00_axi_awsize,
  output wire [1 : 0] m00_axi_awburst,
  output wire m00_axi_awlock,
  output wire [3 : 0] m00_axi_awcache,
  output wire [2 : 0] m00_axi_awprot,
  output wire [3 : 0] m00_axi_awqos,
  output wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] m00_axi_awuser,
  output wire m00_axi_awvalid,
  input wire m00_axi_awready,
  output wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
  output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
  output wire m00_axi_wlast,
  output wire [C_M00_AXI_WUSER_WIDTH-1 : 0] m00_axi_wuser,
  output wire m00_axi_wvalid,
  input wire m00_axi_wready,
  input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_bid,
  input wire [1 : 0] m00_axi_bresp,
  input wire [C_M00_AXI_BUSER_WIDTH-1 : 0] m00_axi_buser,
  input wire m00_axi_bvalid,
  output wire m00_axi_bready,
  output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_arid,
  output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr,
  output wire [7 : 0] m00_axi_arlen,
  output wire [2 : 0] m00_axi_arsize,
  output wire [1 : 0] m00_axi_arburst,
  output wire m00_axi_arlock,
  output wire [3 : 0] m00_axi_arcache,
  output wire [2 : 0] m00_axi_arprot,
  output wire [3 : 0] m00_axi_arqos,
  output wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] m00_axi_aruser,
  output wire m00_axi_arvalid,
  input wire m00_axi_arready,
  input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_rid,
  input wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata,
  input wire [1 : 0] m00_axi_rresp,
  input wire m00_axi_rlast,
  input wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m00_axi_ruser,
  input wire m00_axi_rvalid,
  output wire m00_axi_rready
);

// AXI-Lite Slave IP interface.
// Slave Reg 0
wire [15:0] vx0;
wire [15:0] vy0;
// Slave Reg 1
wire [15:0] vxDiv;
wire [15:0] vyDiv;
// Slave Reg 2
wire [15:0] wHDMI;
wire [10:0] hImage2048;
// Slave Reg 3
wire signed [17:0] q_mult_inv_HL2_LH2;
// Slave Reg 4
wire signed [17:0] q_mult_inv_HH2;
// Slave Reg 5
wire m00_axi_armed;
wire VSYNC_IF_reg;
wire VSYNC_IF_mod;
// Slave Reg 6-7
wire [9:0] fifo_wr_count[3:0];
// Slave Reg 8-11
wire [127:0] dc_RAM_addr_update_concat;
// Slave Reg 12
wire [23:0] bit_discard_update_LL2;
// Slave Reg 13
wire [23:0] bit_discard_update_LH2;
// Slave Reg 14
wire [23:0] bit_discard_update_HL2;
// Slave Reg 15
wire [23:0] bit_discard_update_HH2;
// Slave Reg 16
wire signed [23:0] opx_count_iv2_out_offset;
// Slave Reg 17
wire signed [23:0] opx_count_iv2_in_offset;
// Slave Reg 18
wire signed [23:0] opx_count_dc_en_offset;
// Slave Reg 19
wire SS;
// Slave Reg 20
wire [11:0] pop_ui_x0;
wire [11:0] pop_ui_y0;
wire pop_ui_enabled;
wire bot_ui_enabled;
wire top_ui_enabled;
// URAM 00
wire [11:0] lut_g1_raddr;
wire [63:0] lut_g1_rdata;
// URAM 01
wire [11:0] lut_r1_raddr;
wire [63:0] lut_r1_rdata;
// URAM 02
wire [11:0] lut_b1_raddr;
wire [63:0] lut_b1_rdata;
// URAM 03
wire [11:0] lut_g2_raddr;
wire [63:0] lut_g2_rdata;
// URAM 04
wire [11:0] lut3d_c30_r_raddr;
wire [63:0] lut3d_c30_r_rdata;
// URAM 05
wire [11:0] lut3d_c74_r_raddr;
wire [63:0] lut3d_c74_r_rdata;
// URAM 06
wire [11:0] lut3d_c30_g_raddr;
wire [63:0] lut3d_c30_g_rdata;
// URAM 07
wire [11:0] lut3d_c74_g_raddr;
wire [63:0] lut3d_c74_g_rdata;
// URAM 08
wire [11:0] lut3d_c30_b_raddr;
wire [63:0] lut3d_c30_b_rdata;
// URAM 09
wire [11:0] lut3d_c74_b_raddr;
wire [63:0] lut3d_c74_b_rdata;
// URAM 10
wire [11:0] top_ui_raddr;
wire [63:0] top_ui_rdata;
// URAM 11
wire [11:0] bot_ui_raddr;
wire [63:0] bot_ui_rdata;
// URAM 12
wire [11:0] pop_ui_raddr;
wire [63:0] pop_ui_rdata;

// Instantiation of AXI-Lite Slave.
HDMI_v1_0_S00_AXI 
#( 
	.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) 
HDMI_v1_0_S00_AXI_inst 
(
  // Slave Reg 0
  .vx0(vx0),
  .vy0(vy0),
  // Slave Reg 1
  .vxDiv(vxDiv),
  .vyDiv(vyDiv),
  // Slave Reg 2
  .wHDMI(wHDMI),
  .hImage2048(hImage2048),
  // Slave Reg 3
  .q_mult_inv_HL2_LH2(q_mult_inv_HL2_LH2),
  // Slave Reg 4
  .q_mult_inv_HH2(q_mult_inv_HH2),
  // Slave Reg 5
  .m00_axi_armed(m00_axi_armed),
  .VSYNC_IF_reg(VSYNC_IF_reg),
  .VSYNC_IF_mod(VSYNC_IF_mod),
  // Slave Reg 6
  .fifo_wr_count_LL2(fifo_wr_count[0]),
  .fifo_wr_count_LH2(fifo_wr_count[1]),
  // Slave Reg 7
  .fifo_wr_count_HL2(fifo_wr_count[2]),
  .fifo_wr_count_HH2(fifo_wr_count[3]),
  // Slave Reg 8-11
  .dc_RAM_addr_update_concat(dc_RAM_addr_update_concat),
  // Slave Reg 12
  .bit_discard_update_LL2(bit_discard_update_LL2),
  // Slave Reg 13
  .bit_discard_update_LH2(bit_discard_update_LH2),
  // Slave Reg 14
  .bit_discard_update_HL2(bit_discard_update_HL2),
  // Slave Reg 15
  .bit_discard_update_HH2(bit_discard_update_HH2),
  // Slave Reg 16
  .opx_count_iv2_out_offset(opx_count_iv2_out_offset),
  // Slave Reg 17
  .opx_count_iv2_in_offset(opx_count_iv2_in_offset),
  // Slave Reg 18
  .opx_count_dc_en_offset(opx_count_dc_en_offset),
  // Slave Reg 19
  .SS(SS),
  // Slave Reg 20
  .pop_ui_x0(pop_ui_x0),
  .pop_ui_y0(pop_ui_y0),
  .pop_ui_enabled(pop_ui_enabled),
  .bot_ui_enabled(bot_ui_enabled),
  .top_ui_enabled(top_ui_enabled),
  // URAM 00
  .lut_g1_raddr(lut_g1_raddr),
  .lut_g1_rdata(lut_g1_rdata),
  // URAM 01
  .lut_r1_raddr(lut_r1_raddr),
  .lut_r1_rdata(lut_r1_rdata),
  // URAM 02
  .lut_b1_raddr(lut_b1_raddr),
  .lut_b1_rdata(lut_b1_rdata),
  // URAM 03
  .lut_g2_raddr(lut_g2_raddr),
  .lut_g2_rdata(lut_g2_rdata),
  // URAM 04
  .lut3d_c30_r_raddr(lut3d_c30_r_raddr),
  .lut3d_c30_r_rdata(lut3d_c30_r_rdata),
  // URAM 05
  .lut3d_c74_r_raddr(lut3d_c74_r_raddr),
  .lut3d_c74_r_rdata(lut3d_c74_r_rdata),
  // URAM 06
  .lut3d_c30_g_raddr(lut3d_c30_g_raddr),
  .lut3d_c30_g_rdata(lut3d_c30_g_rdata),
  // URAM 07
  .lut3d_c74_g_raddr(lut3d_c74_g_raddr),
  .lut3d_c74_g_rdata(lut3d_c74_g_rdata),
  // URAM 08
  .lut3d_c30_b_raddr(lut3d_c30_b_raddr),
  .lut3d_c30_b_rdata(lut3d_c30_b_rdata),
  // URAM 09
  .lut3d_c74_b_raddr(lut3d_c74_b_raddr),
  .lut3d_c74_b_rdata(lut3d_c74_b_rdata),
  // URAM 10
  .top_ui_raddr(top_ui_raddr),
  .top_ui_rdata(top_ui_rdata),
  // URAM 11
  .bot_ui_raddr(bot_ui_raddr),
  .bot_ui_rdata(bot_ui_rdata),
  // URAM 12
  .pop_ui_raddr(pop_ui_raddr),
  .pop_ui_rdata(pop_ui_rdata),
   
   // AXI-Lite slave controller signals.
	.S_AXI_ACLK(s00_axi_aclk),
	.S_AXI_ARESETN(s00_axi_aresetn),
	.S_AXI_AWADDR(s00_axi_awaddr),
	.S_AXI_AWPROT(s00_axi_awprot),
	.S_AXI_AWVALID(s00_axi_awvalid),
	.S_AXI_AWREADY(s00_axi_awready),
	.S_AXI_WDATA(s00_axi_wdata),
	.S_AXI_WSTRB(s00_axi_wstrb),
	.S_AXI_WVALID(s00_axi_wvalid),
	.S_AXI_WREADY(s00_axi_wready),
	.S_AXI_BRESP(s00_axi_bresp),
	.S_AXI_BVALID(s00_axi_bvalid),
	.S_AXI_BREADY(s00_axi_bready),
	.S_AXI_ARADDR(s00_axi_araddr),
	.S_AXI_ARPROT(s00_axi_arprot),
	.S_AXI_ARVALID(s00_axi_arvalid),
	.S_AXI_ARREADY(s00_axi_arready),
	.S_AXI_RDATA(s00_axi_rdata),
	.S_AXI_RRESP(s00_axi_rresp),
	.S_AXI_RVALID(s00_axi_rvalid),
	.S_AXI_RREADY(s00_axi_rready)
);

// AXI Master IP interface.
wire axi_dir = 1'b1;  // Always read.
reg axi_init_txn;
wire axi_busy;
reg [(C_M00_AXI_ADDR_WIDTH-1):0] axi_awaddr_init;
wire [(C_M00_AXI_DATA_WIDTH-1):0] axi_wdata;
wire axi_wnext;
reg [(C_M00_AXI_ADDR_WIDTH-1):0] axi_araddr_init;
wire [(C_M00_AXI_DATA_WIDTH-1):0] axi_rdata;
wire axi_rnext;

// Instantiation of AXI Master.
HDMI_v1_0_M00_AXI 
#( 
  .C_M_TARGET_SLAVE_BASE_ADDR(C_M00_AXI_TARGET_SLAVE_BASE_ADDR),
  .C_M_AXI_BURST_LEN(C_M00_AXI_BURST_LEN),
  .C_M_AXI_ID_WIDTH(C_M00_AXI_ID_WIDTH),
  .C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
  .C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
  .C_M_AXI_AWUSER_WIDTH(C_M00_AXI_AWUSER_WIDTH),
  .C_M_AXI_ARUSER_WIDTH(C_M00_AXI_ARUSER_WIDTH),
  .C_M_AXI_WUSER_WIDTH(C_M00_AXI_WUSER_WIDTH),
  .C_M_AXI_RUSER_WIDTH(C_M00_AXI_RUSER_WIDTH),
  .C_M_AXI_BUSER_WIDTH(C_M00_AXI_BUSER_WIDTH)
)
HDMI_v1_0_M00_AXI_inst 
(
  .axi_dir(axi_dir),
  .axi_init_txn(axi_init_txn),
  .axi_busy(axi_busy),
  .axi_awaddr_init(axi_awaddr_init),
  .axi_wdata(axi_wdata),
  .axi_wnext(axi_wnext),
  .axi_araddr_init(axi_araddr_init),
  .axi_rdata(axi_rdata),
  .axi_rnext(axi_rnext),
		
  .M_AXI_ACLK(m00_axi_aclk),
  .M_AXI_ARESETN(m00_axi_aresetn),
  .M_AXI_AWID(m00_axi_awid),
  .M_AXI_AWADDR(m00_axi_awaddr),
  .M_AXI_AWLEN(m00_axi_awlen),
  .M_AXI_AWSIZE(m00_axi_awsize),
  .M_AXI_AWBURST(m00_axi_awburst),
  .M_AXI_AWLOCK(m00_axi_awlock),
  .M_AXI_AWCACHE(m00_axi_awcache),
  .M_AXI_AWPROT(m00_axi_awprot),
  .M_AXI_AWQOS(m00_axi_awqos),
  .M_AXI_AWUSER(m00_axi_awuser),
  .M_AXI_AWVALID(m00_axi_awvalid),
  .M_AXI_AWREADY(m00_axi_awready),
  .M_AXI_WDATA(m00_axi_wdata),
  .M_AXI_WSTRB(m00_axi_wstrb),
  .M_AXI_WLAST(m00_axi_wlast),
  .M_AXI_WUSER(m00_axi_wuser),
  .M_AXI_WVALID(m00_axi_wvalid),
  .M_AXI_WREADY(m00_axi_wready),
  .M_AXI_BID(m00_axi_bid),
  .M_AXI_BRESP(m00_axi_bresp),
  .M_AXI_BUSER(m00_axi_buser),
  .M_AXI_BVALID(m00_axi_bvalid),
  .M_AXI_BREADY(m00_axi_bready),
  .M_AXI_ARID(m00_axi_arid),
  .M_AXI_ARADDR(m00_axi_araddr),
  .M_AXI_ARLEN(m00_axi_arlen),
  .M_AXI_ARSIZE(m00_axi_arsize),
  .M_AXI_ARBURST(m00_axi_arburst),
  .M_AXI_ARLOCK(m00_axi_arlock),
  .M_AXI_ARCACHE(m00_axi_arcache),
  .M_AXI_ARPROT(m00_axi_arprot),
  .M_AXI_ARQOS(m00_axi_arqos),
  .M_AXI_ARUSER(m00_axi_aruser),
  .M_AXI_ARVALID(m00_axi_arvalid),
  .M_AXI_ARREADY(m00_axi_arready),
  .M_AXI_RID(m00_axi_rid),
  .M_AXI_RDATA(m00_axi_rdata),
  .M_AXI_RRESP(m00_axi_rresp),
  .M_AXI_RLAST(m00_axi_rlast),
  .M_AXI_RUSER(m00_axi_ruser),
  .M_AXI_RVALID(m00_axi_rvalid),
  .M_AXI_RREADY(m00_axi_rready)
);

// Add user logic here

// HDMI clock output.
// -------------------------------------------------------------------------------------------------
wire clk_out;
wire oddr_en = hdmi_clk_en & hdmi_pll_locked;

ODDRE1 ODDRE1_hdmi_clk
(
    .Q(clk_out),        // 1-bit output: Data output to IOB
    .C(hdmi_clk),       // 1-bit input: High-speed clock input
    .D1(1'b0),          // 1-bit input: Parallel data input 1
    .D2(oddr_en),       // 1-bit input: Parallel data input 2
    .SR(1'b0)           // 1-bit input: Active High Async Reset
 );
 
OBUF OBUF_hdmi_clk (
   .O(CLK),
   .I(clk_out)
);
// -------------------------------------------------------------------------------------------------

// Horizontal and vertical counters. HSYNC, VSYNC, DE generation.
// -------------------------------------------------------------------------------------------------
localparam integer hsync_off = 44;
localparam integer h_de_on = 192;
localparam integer h_de_off = 2112;

localparam integer hHDMI = 1125;
localparam integer vsync_off = 5;
localparam integer v_de_on = 41;
localparam integer v_de_off = 1121;

reg [15:0] h_count[8:0];
reg [15:0] v_count[8:0];

always @(posedge hdmi_clk)
begin
  
  // Incremeting logic.
  if (h_count[0] < (wHDMI - 1))
  begin
    h_count[0] <= h_count[0] + 16'sh1;
  end
  else
  begin
    h_count[0] <= 16'sh0;
      if (v_count[0] < (hHDMI - 1))
      begin
        v_count[0] <= v_count[0] + 16'sh1;
      end
      else
      begin
        v_count[0] <= 16'sh0;
      end
  end
  
  // Pipeline.
  begin : hv_count_pipeline
  integer i;
  for (i = 0; i < 8; i = i + 1)
  begin
    h_count[i+1] <= h_count[i];
    v_count[i+1] <= v_count[i];
  end
  end : hv_count_pipeline
  
end

// Combinational HSYNC, VSYNC, and DE generation based on h_count and v_count.
assign HSYNC = (h_count[8] < hsync_off);
assign VSYNC = (v_count[8] < vsync_off);
assign DE = (h_count[8] >= h_de_on) && (h_count[8] < h_de_off) && (v_count[8] >= v_de_on) & (v_count[8] < v_de_off);

// Handle VSYNC interrupt: Set once near the bottom of the frame scan, to give the sotware
// a bit of time to prepare register update values for VSYNC. Cleared by software.
wire VSYNC_coming = (v_count[8] == v_de_off);
reg VSYNC_coming_prev;
always @(posedge hdmi_clk)
begin
    VSYNC_coming_prev <= VSYNC_coming;
end
assign VSYNC_IF_mod = (VSYNC_coming && (~VSYNC_coming_prev)) ? 1'b1 : VSYNC_IF_reg;
assign VSYNC_int = VSYNC_IF_reg;
// -------------------------------------------------------------------------------------------------

// Get viewport normalized coordinates and in-viewport mask.
// -------------------------------------------------------------------------------------------------
wire [15:0] vxNorm;
wire signed [16:0] vyNorm;  // Signed to accommodate negative space for top margin operations.
reg [15:0] vxNormP;
reg [15:0] vyNormP;
wire inViewport;
reg inViewportP[5:0];

viewport_normalize vn
(
  .clk(hdmi_clk),
  
  .hImage2048(hImage2048),

  .vx0(vx0),
  .vy0(vy0),
  .vxDiv(vxDiv),
  .vyDiv(vyDiv),
  
  .vx(h_count[0]),
  .vy(v_count[0]),
 
  .vxNorm(vxNorm),
  .vyNorm(vyNorm),
  
  .inViewport(inViewport)
);

// Pipeline.
always @(posedge hdmi_clk)
begin
  inViewportP[0] <= inViewport;
  inViewportP[1] <= inViewportP[0];
  inViewportP[2] <= inViewportP[1];
  inViewportP[3] <= inViewportP[2];
  inViewportP[4] <= inViewportP[3];
  inViewportP[5] <= inViewportP[4];
  vxNormP <= vxNorm;
  vyNormP <= vyNorm[15:0];
end

// -------------------------------------------------------------------------------------------------

// Generate output pixel counters. These can be negative to accommodate top margin operations.
// -------------------------------------------------------------------------------------------------
wire [15:0] vxNorm_SW = SS ? (vxNorm >> 1) : vxNorm; 
wire signed [16:0] vyNorm_SW = SS ? (vyNorm >>> 1) : vyNorm;

wire [9:0] vx10b_G1B1 = (vxNorm_SW - 16'h10) >> 6;    // Rollover is okay in X.
wire [9:0] vx10b_R1G2 = (vxNorm_SW - 16'h30) >> 6;       
wire signed [23:0] vy16b_G1R1 = (vyNorm_SW - 17'sh10);   // Using signed 24b intermediate result to
wire signed [23:0] vy16b_B1G2 = (vyNorm_SW - 17'sh30);   // get the required sign extension.

// Color field-specific pixel counts for IV2 -> IH2 -> Output.
// 4K Mode: X dimension is 1024.
wire signed [23:0] opx_count_G1_4K = {vy16b_G1R1[19:6], vx10b_G1B1[9:0]};
wire signed [23:0] opx_count_R1_4K = {vy16b_G1R1[19:6], vx10b_R1G2[9:0]};
wire signed [23:0] opx_count_B1_4K = {vy16b_B1G2[19:6], vx10b_G1B1[9:0]};
wire signed [23:0] opx_count_G2_4K = {vy16b_B1G2[19:6], vx10b_R1G2[9:0]};
// 2K Mode: X dimension is 512.
wire signed [23:0] opx_count_G1_2K = {vy16b_G1R1[20:6], vx10b_G1B1[8:0]};
wire signed [23:0] opx_count_R1_2K = {vy16b_G1R1[20:6], vx10b_R1G2[8:0]};
wire signed [23:0] opx_count_B1_2K = {vy16b_B1G2[20:6], vx10b_G1B1[8:0]};
wire signed [23:0] opx_count_G2_2K = {vy16b_B1G2[20:6], vx10b_R1G2[8:0]};
// 4K/2K Mode Switch:
wire signed [23:0] opx_count_G1 = SS ? opx_count_G1_2K : opx_count_G1_4K;
wire signed [23:0] opx_count_R1 = SS ? opx_count_R1_2K : opx_count_R1_4K;
wire signed [23:0] opx_count_B1 = SS ? opx_count_B1_2K : opx_count_B1_4K;
wire signed [23:0] opx_count_G2 = SS ? opx_count_G2_2K : opx_count_G2_4K;

// Synchronized pixel counnts for Decompressor -> IV2.
wire signed [23:0] opx_count_sync = opx_count_G1;
wire signed [23:0] opx_count_iv2_in = opx_count_sync + opx_count_iv2_in_offset;
wire signed [23:0] opx_count_dc_en = opx_count_sync + opx_count_dc_en_offset;

// Global pixel enable when opx_count_sync hits a new value.
// (LSB increments AND not in a repeated row.)
wire opx_count_sync_x_LSB = opx_count_sync[0];
wire opx_count_sync_y_LSB = SS ? opx_count_sync[9] : opx_count_sync[10];
reg opx_count_sync_x_LSB_prev;
reg opx_count_sync_y_LSB_prev;
wire x_inc = (opx_count_sync_x_LSB ^ opx_count_sync_x_LSB_prev);
wire y_inc = (opx_count_sync_y_LSB ^ opx_count_sync_y_LSB_prev);
wire last_px_in_row = SS ? (opx_count_sync[8:0] == 9'h1FF) : (opx_count_sync[9:0] == 10'h3FF);

always @(posedge hdmi_clk)
begin
    opx_count_sync_x_LSB_prev <= opx_count_sync_x_LSB;
    if(x_inc & last_px_in_row)
    begin
      opx_count_sync_y_LSB_prev <= opx_count_sync_y_LSB;
    end
end

wire px_en = x_inc & y_inc;
wire px_en_div4 = px_en & (opx_count_sync[1:0] == 2'b00);

wire iv2_en = (opx_count_iv2_in >= 24'sh0) & px_en;
wire dc_en = (opx_count_dc_en >= 24'sh0);
// -------------------------------------------------------------------------------------------------

// Decompressor State Driver
// -------------------------------------------------------------------------------------------------
reg [1:0] dc_state;
always @(posedge hdmi_clk)
begin
  if (v_count[0] == 16'h0000)
  begin
    dc_state <= `DC_STATE_FIFO_RST;     // HDMI Row 0.
  end
  else if(v_count[0] == 16'h0001)
  begin
    dc_state <= `DC_STATE_FIFO_FILL;    // HDMI Row 1.
  end
  else
  begin
    if (dc_en)
    begin
      dc_state <= `DC_STATE_PX_CONSUME;
    end
    else
    begin
      dc_state <= `DC_STATE_BIT_DISCARD;
    end
  end
end
// -------------------------------------------------------------------------------------------------

// Decompressors
// -------------------------------------------------------------------------------------------------
wire fifo_rst;
wire fifo_wr_next[3:0];
// wire [9:0] fifo_wr_count[3:0];
wire [63:0] dc_out_4px_LL2;
wire [63:0] dc_out_4px_LH2;
wire [63:0] dc_out_4px_HL2;
wire [63:0] dc_out_4px_HH2;

decompressor_LL2 dc_LL2   // Stream 00, handling LL2
(
  .m00_axi_aclk(m00_axi_aclk),
  .fifo_wr_next(fifo_wr_next[0]),
  .fifo_wr_data(axi_rdata),
  .fifo_wr_count(fifo_wr_count[0]),
  
  .opx_clk(hdmi_clk),
  .fifo_rst(fifo_rst),
  .dc_state(dc_state),
  .px_en_div4(px_en_div4),
  .bit_discard_update(bit_discard_update_LL2),
  .out_4px(dc_out_4px_LL2)
);

decompressor dc_LH2   // Stream 01, handling LH2
(
  .m00_axi_aclk(m00_axi_aclk),
  .fifo_wr_next(fifo_wr_next[1]),
  .fifo_wr_data(axi_rdata),
  .fifo_wr_count(fifo_wr_count[1]),
  
  .opx_clk(hdmi_clk),
  .fifo_rst(fifo_rst),
  .dc_state(dc_state),
  .px_en_div4(px_en_div4),
  .bit_discard_update(bit_discard_update_LH2),
  .q_mult_inv(q_mult_inv_HL2_LH2),
  .out_4px(dc_out_4px_LH2)
);

decompressor dc_HL2   // Stream 02, handling HL2
(
  .m00_axi_aclk(m00_axi_aclk),
  .fifo_wr_next(fifo_wr_next[2]),
  .fifo_wr_data(axi_rdata),
  .fifo_wr_count(fifo_wr_count[2]),
  
  .opx_clk(hdmi_clk), 
  .fifo_rst(fifo_rst),
  .dc_state(dc_state),
  .px_en_div4(px_en_div4),
  .bit_discard_update(bit_discard_update_HL2),
  .q_mult_inv(q_mult_inv_HL2_LH2),
  .out_4px(dc_out_4px_HL2)
);

decompressor dc_HH2   // Stream 03, handling HH2
(
  .m00_axi_aclk(m00_axi_aclk),
  .fifo_wr_next(fifo_wr_next[3]),
  .fifo_wr_data(axi_rdata),
  .fifo_wr_count(fifo_wr_count[3]),
  
  .opx_clk(hdmi_clk),
  .fifo_rst(fifo_rst),
  .dc_state(dc_state),
  .px_en_div4(px_en_div4),
  .bit_discard_update(bit_discard_update_HH2),
  .q_mult_inv(q_mult_inv_HH2),
  .out_4px(dc_out_4px_HH2)
);
// -------------------------------------------------------------------------------------------------

// Round-robin RAM reader.
// -------------------------------------------------------------------------------------------------
genvar i;

// RAM reader state, cycles through the 4 compressors.
reg [1:0] c_state;
reg axi_busy_wait;
wire axi_txn_done;
assign axi_txn_done = axi_busy_wait & ~axi_busy;

// Over?built clock domain crossing for address reset request.
reg [1:0] dc_state_prev;
reg dc_RAM_addr_update_request_0_hdmi;
reg dc_RAM_addr_update_request_1_axi;
reg dc_RAM_addr_update_request_2_axi;
always @(posedge hdmi_clk)
begin
  dc_state_prev <= dc_state;
  dc_RAM_addr_update_request_0_hdmi <= (dc_state == `DC_STATE_FIFO_RST);
end
always @(posedge m00_axi_aclk)
begin
  dc_RAM_addr_update_request_1_axi <= dc_RAM_addr_update_request_0_hdmi;
  dc_RAM_addr_update_request_2_axi <= dc_RAM_addr_update_request_1_axi;
end

// Address generation.
reg [31:0] dc_RAM_addr [3:0];
// Update the RAM read base addresses during FIFO_RST state (first row after VSYNC).
// (Wait for in-progress transactions to end first.)
wire dc_RAM_addr_update_request = dc_RAM_addr_update_request_2_axi & (~axi_init_txn) & (~axi_busy_wait);
reg dc_RAM_addr_update_complete;
assign fifo_rst = (dc_RAM_addr_update_request & ~dc_RAM_addr_update_complete);
always @(posedge m00_axi_aclk)
begin
  if (~m00_axi_armed)
  begin : axi_rst
    // Reset.
    integer j;
    for(j = 0; j < 4; j = j + 1)
    begin
      dc_RAM_addr[j] <= 32'h0;
      dc_RAM_addr_update_complete <= 1'b0;
    end
  end : axi_rst
  else
  begin
    if(fifo_rst)
    begin : axi_addr_update
      // Address update.
      integer j;
      for(j = 0; j < 4; j = j + 1)
      begin
        dc_RAM_addr[j] <= dc_RAM_addr_update_concat[32*j+:32];
      end
      dc_RAM_addr_update_complete <= 1'b1;
    end : axi_addr_update
    else 
    begin
      // Running.
      if(axi_txn_done)
      begin
        dc_RAM_addr[c_state] <= dc_RAM_addr[c_state] + 32'h200;
        dc_RAM_addr_update_complete <= 1'b0;
      end
    end
  end
end

// FIFO write enable based on writes remaining and axi_rnext.
reg [6:0] fifo_writes_remaining;
wire fifo_wr_en = (fifo_writes_remaining > 0) && axi_rnext;

// Writes remaining counter. Reloads on axi_init_txn.
always @(posedge m00_axi_aclk)
begin
  if (~m00_axi_armed || dc_RAM_addr_update_request)
  begin
    // Clear the write counter between frames or if disarmed.
    fifo_writes_remaining <= 7'd0;
  end
  else if(axi_init_txn && (fifo_writes_remaining == 0))
  begin
    fifo_writes_remaining <= 7'd64;
  end
  else if(fifo_wr_en)
  begin
    fifo_writes_remaining <= fifo_writes_remaining - 7'd1;
  end
end

// Route the write enable only to the selected compressor FIFO.
for (i = 0; i < 4; i = i + 1)
begin
  assign fifo_wr_next[i] = fifo_wr_en & (c_state == i);
end
    
// Trigger on FIFO fill level.
wire fifo_trigger;
assign fifo_trigger = (fifo_wr_count[c_state] < 10'h180);

// Fun times state machine.
always @(posedge m00_axi_aclk)
begin
  if (~m00_axi_armed || dc_RAM_addr_update_request)
  begin
    // Reset the RAM reader between frames or if disarmed.
    c_state <= 4'h0;
    axi_araddr_init <= 1'b0;
    axi_init_txn <= 1'b0;
    axi_busy_wait <= 1'b0;
  end 
  else
  begin
    if (fifo_trigger & ~axi_init_txn & ~axi_busy_wait)
    begin
      // FIFO threshold is met, start a transcation.
      axi_araddr_init <= dc_RAM_addr[c_state];
      axi_init_txn <= 1'b1;
    end
    else if (axi_init_txn & axi_busy)
    begin
      // Transaction started, end init pulse and set busy wait.
      axi_init_txn <= 1'b0;
      axi_busy_wait <= 1'b1;
    end
    else if (axi_txn_done)
    begin
      // Transaction complete, end the busy wait. 
      // Increment the read offset by 512B and increment the state.
      axi_busy_wait <= 1'b0;
      c_state <= c_state + 4'h1;
    end
    else if(~fifo_trigger & ~axi_init_txn & ~axi_busy_wait)
    begin
      // FIFO threshold is not met. Just increment the state.
      c_state <= c_state + 4'h1;
    end
  end
end
// -------------------------------------------------------------------------------------------------

// Inverse DWT Vertical Second Stages
// -------------------------------------------------------------------------------------------------
// IV2 FIFO write.
reg iv2_wr_en_G1;
reg iv2_wr_en_R1;
reg iv2_wr_en_B1;
reg iv2_wr_en_G2;
reg [11:0] iv2_wr_addr;  // Shared.
reg [63:0] iv2_wr_data;  // Shared.

// IV2 outputs.
wire [63:0] iv2_out_4px_row0_G1;
wire [63:0] iv2_out_4px_row1_G1;
wire [63:0] iv2_out_4px_row0_R1;
wire [63:0] iv2_out_4px_row1_R1;
wire [63:0] iv2_out_4px_row0_B1;
wire [63:0] iv2_out_4px_row1_B1;
wire [63:0] iv2_out_4px_row0_G2;
wire [63:0] iv2_out_4px_row1_G2;

idwt26_v2
#(
  .PX_MATH_WIDTH(PX_MATH_WIDTH)
)
iv2_G1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count_iv2_out(opx_count_G1 + opx_count_iv2_out_offset),
  .wr_en(iv2_wr_en_G1),
  .wr_addr(iv2_wr_addr),
  .wr_data(iv2_wr_data),
  .out_4px_row0(iv2_out_4px_row0_G1),
  .out_4px_row1(iv2_out_4px_row1_G1)
);

idwt26_v2 
#(
  .PX_MATH_WIDTH(PX_MATH_WIDTH)
)
iv2_R1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count_iv2_out(opx_count_R1 + opx_count_iv2_out_offset),
  .wr_en(iv2_wr_en_R1),
  .wr_addr(iv2_wr_addr),
  .wr_data(iv2_wr_data),
  .out_4px_row0(iv2_out_4px_row0_R1),
  .out_4px_row1(iv2_out_4px_row1_R1)
);

idwt26_v2 
#(
  .PX_MATH_WIDTH(PX_MATH_WIDTH)
)
iv2_B1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count_iv2_out(opx_count_B1 + opx_count_iv2_out_offset),
  .wr_en(iv2_wr_en_B1),
  .wr_addr(iv2_wr_addr),
  .wr_data(iv2_wr_data),
  .out_4px_row0(iv2_out_4px_row0_B1),
  .out_4px_row1(iv2_out_4px_row1_B1)
);

idwt26_v2 
#(
  .PX_MATH_WIDTH(PX_MATH_WIDTH)
)
iv2_G2
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count_iv2_out(opx_count_G2 + opx_count_iv2_out_offset),
  .wr_en(iv2_wr_en_G2),
  .wr_addr(iv2_wr_addr),
  .wr_data(iv2_wr_data),
  .out_4px_row0(iv2_out_4px_row0_G2),
  .out_4px_row1(iv2_out_4px_row1_G2)
);
// -------------------------------------------------------------------------------------------------

// Decompressor Output Distributor
// -------------------------------------------------------------------------------------------------

// Write Enable Switch
always @(posedge hdmi_clk)
begin
if (iv2_en)
begin
  // TO-DO: Change order of color fields to match Bayer grid and codestream order.
  iv2_wr_en_R1 <= (opx_count_iv2_in[5:4] == 2'b00) ? 1'b1 : 1'b0;
  iv2_wr_en_G1 <= (opx_count_iv2_in[5:4] == 2'b01) ? 1'b1 : 1'b0;
  iv2_wr_en_G2 <= (opx_count_iv2_in[5:4] == 2'b10) ? 1'b1 : 1'b0;
  iv2_wr_en_B1 <= (opx_count_iv2_in[5:4] == 2'b11) ? 1'b1 : 1'b0;
end
else
begin
  // Don't write until there's a new valid pixel.
  iv2_wr_en_R1 <= 1'b0;
  iv2_wr_en_G1 <= 1'b0;
  iv2_wr_en_G2 <= 1'b0;
  iv2_wr_en_B1 <= 1'b0;
end
end

// Write Address Switch
always @(posedge hdmi_clk)
begin
if (iv2_en)
begin
  if(SS)
  begin
    // 2K Mode
    iv2_wr_addr[11:7] <= opx_count_iv2_in[14:10] + {opx_count_iv2_in[1], 4'b0};
    iv2_wr_addr[6:5] <= opx_count_iv2_in[3:2];
    iv2_wr_addr[4:1] <= opx_count_iv2_in[9:6];
    iv2_wr_addr[0] <= opx_count_iv2_in[0];
  end
  else
  begin
    // 4K Mode
    iv2_wr_addr[11:8] <= opx_count_iv2_in[14:11] + {opx_count_iv2_in[1], 3'b0};
    iv2_wr_addr[7:6] <= opx_count_iv2_in[3:2];
    iv2_wr_addr[5:1] <= opx_count_iv2_in[10:6];
    iv2_wr_addr[0] <= opx_count_iv2_in[0];
  end
end
end

// Write Data Switch
always @(posedge hdmi_clk)
begin
if (iv2_en)
begin
  case (opx_count_iv2_in[1:0])
  2'b00: iv2_wr_data <= {dc_out_4px_HL2[16+:16], dc_out_4px_LL2[16+:16], dc_out_4px_HL2[0+:16], dc_out_4px_LL2[0+:16]};
  2'b01: iv2_wr_data <= {dc_out_4px_HL2[48+:16], dc_out_4px_LL2[48+:16], dc_out_4px_HL2[32+:16], dc_out_4px_LL2[32+:16]};
  2'b10: iv2_wr_data <= {dc_out_4px_HH2[16+:16], dc_out_4px_LH2[16+:16], dc_out_4px_HH2[0+:16], dc_out_4px_LH2[0+:16]};
  2'b11: iv2_wr_data <= {dc_out_4px_HH2[48+:16], dc_out_4px_LH2[48+:16], dc_out_4px_HH2[32+:16], dc_out_4px_LH2[32+:16]};
  endcase
end
end

// -------------------------------------------------------------------------------------------------

// Inverse DWT Horizontal Second Stages
// -------------------------------------------------------------------------------------------------
wire [31:0] out_2px_row0_G1;
wire [31:0] out_2px_row1_G1;
wire [31:0] out_2px_row0_R1;
wire [31:0] out_2px_row1_R1;
wire [31:0] out_2px_row0_B1;
wire [31:0] out_2px_row1_B1;
wire [31:0] out_2px_row0_G2;
wire [31:0] out_2px_row1_G2;

idwt26_h2 ih2_G1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count(opx_count_G1),
  .in_4px_row0(iv2_out_4px_row0_G1),
  .in_4px_row1(iv2_out_4px_row1_G1),
  .out_2px_row0(out_2px_row0_G1),
  .out_2px_row1(out_2px_row1_G1)
);

idwt26_h2 ih2_R1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count(opx_count_R1),
  .in_4px_row0(iv2_out_4px_row0_R1),
  .in_4px_row1(iv2_out_4px_row1_R1),
  .out_2px_row0(out_2px_row0_R1),
  .out_2px_row1(out_2px_row1_R1)
);

idwt26_h2 ih2_B1
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count(opx_count_B1),
  .in_4px_row0(iv2_out_4px_row0_B1),
  .in_4px_row1(iv2_out_4px_row1_B1),
  .out_2px_row0(out_2px_row0_B1),
  .out_2px_row1(out_2px_row1_B1)
);

idwt26_h2 ih2_G2
(
  .SS(SS),
  .opx_clk(hdmi_clk),
  .opx_count(opx_count_G2),
  .in_4px_row0(iv2_out_4px_row0_G2),
  .in_4px_row1(iv2_out_4px_row1_G2),
  .out_2px_row0(out_2px_row0_G2),
  .out_2px_row1(out_2px_row1_G2)
);
// -------------------------------------------------------------------------------------------------

// Bilinear ineterpolators.
// -------------------------------------------------------------------------------------------------
// Switch in extra 2x scaling for 2K Mode (SS == 1).
wire [15:0] vxNormP_SW = SS ? (vxNormP >> 1) : vxNormP;
wire [15:0] vyNormP_SW = SS ? (vyNormP >> 1) : vyNormP;

// Calculate (x0, y0), the upper-left corner of the grid square used to interpolate within a given
// color field, outside of the interpolators to avoid redundant shared-edge logic.
wire [15:0] x0_G1B1 = ((vxNormP_SW - 16'h10) & 16'hFFC0) + 16'h10;
wire [15:0] x0_R1G2 = ((vxNormP_SW - 16'h30) & 16'hFFC0) + 16'h30;
wire [15:0] y0_G1R1 = ((vyNormP_SW - 16'h10) & 16'hFFC0) + 16'h10;
wire [15:0] y0_B1G2 = ((vyNormP_SW - 16'h30) & 16'hFFC0) + 16'h30;

wire signed [15:0] out_G1;
wire signed [15:0] out_R1;
wire signed [15:0] out_B1;
wire signed [15:0] out_G2;

bilinear_16b bilinear_G1 
(
  .clk(hdmi_clk),
  .x0(x0_G1B1),
  .y0(y0_G1R1),
  .xOut(vxNormP_SW),
  .yOut(vyNormP_SW),
  .in00(out_2px_row0_G1[15:0]),
  .in10(out_2px_row0_G1[31:16]),
  .in01(out_2px_row1_G1[15:0]),
  .in11(out_2px_row1_G1[31:16]),
  .out(out_G1)
);

bilinear_16b bilinear_R1
(
  .clk(hdmi_clk),
  .x0(x0_R1G2),
  .y0(y0_G1R1),
  .xOut(vxNormP_SW),
  .yOut(vyNormP_SW),
  .in00(out_2px_row0_R1[15:0]),
  .in10(out_2px_row0_R1[31:16]),
  .in01(out_2px_row1_R1[15:0]),
  .in11(out_2px_row1_R1[31:16]),
  .out(out_R1)
);

bilinear_16b bilinear_B1
(
  .clk(hdmi_clk),
  .x0(x0_G1B1),
  .y0(y0_B1G2),
  .xOut(vxNormP_SW),
  .yOut(vyNormP_SW),
  .in00(out_2px_row0_B1[15:0]),
  .in10(out_2px_row0_B1[31:16]),
  .in01(out_2px_row1_B1[15:0]),
  .in11(out_2px_row1_B1[31:16]),
  .out(out_B1)
);

bilinear_16b bilinear_G2
(
  .clk(hdmi_clk),
  .x0(x0_R1G2),
  .y0(y0_B1G2),
  .xOut(vxNormP_SW),
  .yOut(vyNormP_SW),
  .in00(out_2px_row0_G2[15:0]),
  .in10(out_2px_row0_G2[31:16]),
  .in01(out_2px_row1_G2[15:0]),
  .in11(out_2px_row1_G2[31:16]),
  .out(out_G2)
);
// -------------------------------------------------------------------------------------------------

// Color correction.
// -------------------------------------------------------------------------------------------------
wire signed [15:0] R_14b;
wire signed [15:0] G_14b;
wire signed [15:0] B_14b;

color_1dlut color_1dlut_inst
(
  .clk(hdmi_clk),

  .out_G1(out_G1),
  .out_R1(out_R1),
  .out_B1(out_B1),
  .out_G2(out_G2),

  .lut_g1_rdata(lut_g1_rdata),
  .lut_r1_rdata(lut_r1_rdata),
  .lut_b1_rdata(lut_b1_rdata),
  .lut_g2_rdata(lut_g2_rdata),
  .lut_g1_raddr(lut_g1_raddr),
  .lut_r1_raddr(lut_r1_raddr),
  .lut_b1_raddr(lut_b1_raddr),
  .lut_g2_raddr(lut_g2_raddr),
  
  .R_14b(R_14b),
  .G_14b(G_14b),
  .B_14b(B_14b)
);

wire [7:0] R_8b;
wire [7:0] G_8b;
wire [7:0] B_8b;

color_3dlut color_3dlut_inst
(
  .clk(hdmi_clk),

  .R_14b(R_14b),
  .G_14b(G_14b),
  .B_14b(B_14b),

  .lut3d_c30_r_rdata(lut3d_c30_r_rdata),
  .lut3d_c74_r_rdata(lut3d_c74_r_rdata),
  .lut3d_c30_g_rdata(lut3d_c30_g_rdata),
  .lut3d_c74_g_rdata(lut3d_c74_g_rdata),
  .lut3d_c30_b_rdata(lut3d_c30_b_rdata),
  .lut3d_c74_b_rdata(lut3d_c74_b_rdata),
  .lut3d_c30_r_raddr(lut3d_c30_r_raddr),
  .lut3d_c74_r_raddr(lut3d_c74_r_raddr),
  .lut3d_c30_g_raddr(lut3d_c30_g_raddr),
  .lut3d_c74_g_raddr(lut3d_c74_g_raddr),
  .lut3d_c30_b_raddr(lut3d_c30_b_raddr),
  .lut3d_c74_b_raddr(lut3d_c74_b_raddr),
  
  .R_8b(R_8b),
  .G_8b(G_8b),
  .B_8b(B_8b)
);
// -------------------------------------------------------------------------------------------------

// Color outputs.
// -------------------------------------------------------------------------------------------------
ui_mixer ui_mixer_inst
(
  .hdmi_clk(hdmi_clk),
  .s00_axi_aclk(s00_axi_aclk),
  
  .R_8b(R_8b),
  .G_8b(G_8b),
  .B_8b(B_8b),
  
  .h_count(h_count[7]),
  .v_count(v_count[7]),
  .inViewport(inViewportP[5]),
  
  .top_ui_enabled(top_ui_enabled),
  .bot_ui_enabled(bot_ui_enabled),
  .pop_ui_enabled(pop_ui_enabled),
  .pop_ui_x0(pop_ui_x0),
  .pop_ui_y0(pop_ui_y0),
  
  .top_ui_rdata(top_ui_rdata),
  .bot_ui_rdata(bot_ui_rdata),
  .pop_ui_rdata(pop_ui_rdata),
  .top_ui_raddr(top_ui_raddr),
  .bot_ui_raddr(bot_ui_raddr),
  .pop_ui_raddr(pop_ui_raddr),
  
  .R_out(R),
  .G_out(G),
  .B_out(B)
);
// -------------------------------------------------------------------------------------------------

// User logic ends

endmodule
