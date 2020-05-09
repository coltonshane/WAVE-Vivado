`timescale 1 ns / 1 ps
/*
=================================================================================
CMV_Input_v1_0.v
Top module of CMV12000 read-in IP. Reads the LVDS channels (64 data + 1 control)
at 600Mb/s and presents a pixel clock and 10-bit pixel data to the wavelet core.
Configuration and control (link training) are done via an AXI-Lite slave.

Copyright (C) 2019 by Shane W. Colton

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

module CMV_Input_v1_0
#(
	// Parameters for AXI-Lite Slave.
	parameter integer C_S00_AXI_DATA_WIDTH = 32,
	parameter integer C_S00_AXI_ADDR_WIDTH = 9
)
(
	// Users to add ports here
	
	input wire px_in_rst,
    input wire lvds_clk_p,
    input wire lvds_clk_n,
    input wire cmv_ctr_p,
    input wire cmv_ctr_n,
    input wire [63:0] cmv_ch_p,
    input wire [63:0] cmv_ch_n,
    
    // 1:10 Pixel clock (60MHz), derived from the 300MHz LVDS input clock.
    // Also used to drive CMV12000 CLK_IN for temperature sensor, through ODDRE1/OBUF.
    output wire px_clk,
    output wire ts_clk,
                   
    // Master pixel counter. Increments by one every px_clk with valid pixel data.
    // Normal Mode: 2 Rows x 4096px = 8192px = 128 px_count increments.
    // Subsampled Mode: 4 Rows x 2048px = 8192px = 128 px_count increments.
    output reg signed [23:0] px_count,
    
    // 10-bit control channel output.
    output wire [9:0] px_ctr,
    
    // Concatenation of 10-bit pixel channel outputs.
    output wire [639:0] px_chXX_concat,
    
    // FOT interrupt output to PS.
    output wire FOT_int,
    
    // CMV12000 timining control.
    output wire FRAME_REQ,
    output wire T_EXP1,
    output wire T_EXP2,

	// User ports ends
	// Do not modify the ports beyond this line

	// Ports for AXI-Lite Slave.
	input wire  s00_axi_aclk,
	input wire  s00_axi_aresetn,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
	input wire [2 : 0] s00_axi_awprot,
	input wire  s00_axi_awvalid,
	output wire  s00_axi_awready,
	input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
	input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
	input wire  s00_axi_wvalid,
	output wire  s00_axi_wready,
	output wire [1 : 0] s00_axi_bresp,
	output wire  s00_axi_bvalid,
	input wire  s00_axi_bready,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
	input wire [2 : 0] s00_axi_arprot,
	input wire  s00_axi_arvalid,
	output wire  s00_axi_arready,
	output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
	output wire [1 : 0] s00_axi_rresp,
	output wire  s00_axi_rvalid,
	input wire  s00_axi_rready
);

// CMV12000 pixel channels config and data for AXI-Lite Slave. 
// These are arrayed  and tied to slave registers in user logic.
wire [575:0] cmv_chXX_delay_target_concat;
wire [255:0] cmv_chXX_bitslip_concat;
wire [127:0] cmv_chXX_px_phase_concat;
wire [1023:0] cmv_chXX_px_data_concat;

// CMV12000 control channel config and data.
wire [8:0] cmv_ctr_delay_target;
wire [3:0] cmv_ctr_bitslip;
wire [1:0] cmv_ctr_px_phase;
wire [15:0] cmv_ctr_px_data;

// Pixel counter limit, used to stop pixel capture in mid-frame for debugging.
wire [23:0] px_count_limit;

// FOT interrupt flag.
wire FOT_IF_reg;     // Registered value, drives the interrupt line.
wire FOT_IF_mod;     // Module input for setting FOT interrupt flag.

// CMV12000 timining control.
wire [31:0] frame_interval;
wire [31:0] FRAME_REQ_on;
wire [31:0] T_EXP1_on;
wire [31:0] T_EXP2_on;
wire [9:0] exp_bias;

// Instantiation of AXI-Lite Slave.
CMV_Input_v1_0_S00_AXI 
#( 
	.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) 
CMV_Input_v1_0_S00_AXI_inst 
(
    // CMV12000 pixel channels config and data. 
    // These are arrayed  and tied to slave registers in user logic.
    .cmv_chXX_delay_target_concat(cmv_chXX_delay_target_concat),
    .cmv_chXX_bitslip_concat(cmv_chXX_bitslip_concat),
    .cmv_chXX_px_phase_concat(cmv_chXX_px_phase_concat),
    .cmv_chXX_px_data_concat(cmv_chXX_px_data_concat),

    // CMV12000 control channel config and data.
    .cmv_ctr_delay_target(cmv_ctr_delay_target),
    .cmv_ctr_bitslip(cmv_ctr_bitslip),
    .cmv_ctr_px_phase(cmv_ctr_px_phase),
    .cmv_ctr_px_data(cmv_ctr_px_data),
    
    // Pixel counter limit.
    .px_count_limit(px_count_limit),
    
    // Maser pixel counter.
    .px_count(px_count),
    
    // FOT interrupt flag.
    .FOT_IF_reg(FOT_IF_reg),
    .FOT_IF_mod(FOT_IF_mod),
    
    // CMV12000 timining control.
    .frame_interval(frame_interval),
    .FRAME_REQ_on(FRAME_REQ_on),
    .T_EXP1_on(T_EXP1_on),
    .T_EXP2_on(T_EXP2_on),
    .exp_bias(exp_bias),

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

// Add user logic here

// Clock input and distribution module.
wire lvds_clk;             // LVDS Rx clock from CMV12000 (300Mz).
wire lvds_clk_div4;        // 1:8 DDR deserializer clock (75MHz).
lvds_clk_in lvds_clk_in_0
(
   .lvds_clk_p(lvds_clk_p),
   .lvds_clk_n(lvds_clk_n),
   .lvds_clk(lvds_clk),
   .lvds_clk_div4(lvds_clk_div4),
   .px_clk(px_clk)
);

// Buffer 60MHz px_clk for output to CMV12000 CLK_IN (temperature sensor clock).
wire ts_clk_out;
ODDRE1 ODDRE1_inst 
(
  .Q(ts_clk_out),     // 1-bit output: Data output to IOB
  .C(px_clk),         // 1-bit input: High-speed clock input
  .D1(1'b0),          // 1-bit input: Parallel data input 1
  .D2(1'b1),          // 1-bit input: Parallel data input 2
  .SR(1'b0)           // 1-bit input: Active High Async Reset
);
  
OBUF OBUF_inst 
(
  .O(ts_clk),         // 1-bit output: Buffer output
  .I(ts_clk_out)      // 1-bit input: Buffer input
);

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

// CMV12000 pixel channel inputs.
localparam cmv_chXX_inverted = {1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,     // 64-57
                                1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1,     // 56-49                            
                                1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0,     // 48-41
                                1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1,     // 40-33
                                1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,     // 32-25
                                1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,     // 24-17
                                1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1,     // 16-09
                                1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};    // 08-01

for(i = 0; i < 64; i = i + 1)
begin : cmv_chXX

    px_in
    #(
        .LVDS_INVERTED(cmv_chXX_inverted[i])
    )
    px_in_chXX
    (
        .px_in_rst(px_in_rst),
    
        .lvds_in_p(cmv_ch_p[i]),
        .lvds_in_n(cmv_ch_n[i]),
        .lvds_clk(lvds_clk),
        .lvds_clk_div4(lvds_clk_div4),
        .px_clk(px_clk),
        .delay_target(cmv_chXX_delay_target[i]),
        .bitslip(cmv_chXX_bitslip[i]),
        .px_phase(cmv_chXX_px_phase[i]),
        
        .px_out(cmv_chXX_px_data[i][9:0]),
        .idelay_actual(),
        .odelay_actual()
    );
    assign cmv_chXX_px_data[i][15:10] = 6'b000000;
    
end : cmv_chXX

// CMV12000 control channel input.
px_in
#(
    .LVDS_INVERTED(1'b1)
)
px_in_ctr
(
    .px_in_rst(px_in_rst),

    .lvds_in_p(cmv_ctr_p),
    .lvds_in_n(cmv_ctr_n),
    .lvds_clk(lvds_clk),
    .lvds_clk_div4(lvds_clk_div4),
    .px_clk(px_clk),
    .delay_target(cmv_ctr_delay_target),
    .bitslip(cmv_ctr_bitslip),
    .px_phase(cmv_ctr_px_phase),
        
    .px_out(cmv_ctr_px_data[9:0]),
    .idelay_actual(),
    .odelay_actual()
);
assign cmv_ctr_px_data[15:10] = 6'b000000;

// 10-bit control channel output to wavelet block.
// DVAL is masked out by the pixel count limit for debugging.
assign px_ctr = cmv_ctr_px_data[9:0] & {9'b11111111, (px_count < px_count_limit)};

// Map CMV12000 control channel signals.
wire CMV_DVAL = px_ctr[0];
wire CMV_FOT = px_ctr[3];
wire CMV_INTE1 = px_ctr[4];

// Concatenated 10-bit pixel channel output to wavelet block.
for (i = 0; i < 64; i = i + 1)
begin
    assign px_chXX_concat[10*i+:10] = cmv_chXX_px_data[i][9:0] + (CMV_INTE1 ? exp_bias : 10'h0);
end

// Master pixel counter.
always @(posedge px_clk)
begin
    if (CMV_FOT)
    begin
        px_count <= 24'sh000000;
    end
    else if (CMV_DVAL)
    begin
        px_count <= px_count + 24'sh000001;
    end
end

// Handle FOT interrupt: Set once per FOT rising edge, 
// otherwise use registered value (allows software reset).
reg CMV_FOT_prev;
always @(posedge px_clk)
begin
    CMV_FOT_prev <= CMV_FOT;
end
assign FOT_IF_mod = (CMV_FOT && (~CMV_FOT_prev)) ? 1'b1 : FOT_IF_reg;
assign FOT_int = FOT_IF_reg;

// CMV12000 timining control. Generate ~1us pulses on FRAME_REQ, T_EXP1, and T_EXP2;
reg [31:0] frame_interval_count;
always @(posedge px_clk)
begin
  if(frame_interval_count < frame_interval)
  begin
    frame_interval_count <= frame_interval_count + 32'h1;
  end
  else
  begin
    frame_interval_count <= 32'h0;
  end
end
assign FRAME_REQ = (frame_interval_count >= FRAME_REQ_on) && (frame_interval_count < (FRAME_REQ_on + 32'h40));
assign T_EXP1 = (frame_interval_count >= T_EXP1_on) && (frame_interval_count < (T_EXP1_on + 32'h40));
assign T_EXP2 = (frame_interval_count >= T_EXP2_on) && (frame_interval_count < (T_EXP2_on + 32'h40));

// User logic ends

endmodule