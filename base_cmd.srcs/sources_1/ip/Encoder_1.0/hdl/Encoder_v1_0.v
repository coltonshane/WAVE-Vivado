`timescale 1 ns / 1 ps
/*
===================================================================================
Encoderv1_0.v
Top module of encoder/quantizer. Receives output data from the wavelet stages,
quantizes and encodes it, and writes the compressed stream to PS DDR4 using a 
250MHz x 128b AXI master. Configuration and control is done via an AXI-Lite slave.
===================================================================================
*/

module Encoder_v1_0
#(
	// Parameters for AXI-Lite Slave.
	parameter integer C_S00_AXI_DATA_WIDTH = 32,
	parameter integer C_S00_AXI_ADDR_WIDTH = 6,

	// Parameters for AXI Master 00.
    parameter C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h00000000,
	parameter integer C_M00_AXI_BURST_LEN = 16,
	parameter integer C_M00_AXI_ID_WIDTH = 1,
	parameter integer C_M00_AXI_ADDR_WIDTH = 32,
	parameter integer C_M00_AXI_DATA_WIDTH = 128,
	parameter integer C_M00_AXI_AWUSER_WIDTH = 0,
	parameter integer C_M00_AXI_ARUSER_WIDTH = 0,
	parameter integer C_M00_AXI_WUSER_WIDTH = 0,
	parameter integer C_M00_AXI_RUSER_WIDTH = 0,
	parameter integer C_M00_AXI_BUSER_WIDTH = 0
)
(
	// Users to add ports here
	
	input wire px_clk,
	input wire px_clk_2x,
	input wire signed [23:0] px_count,
	input wire [1023:0] HH1_concat,
	input wire [1023:0] HL1_concat,
	input wire [1023:0] LH1_concat,
	input wire [511:0] HH2_concat,
	input wire [511:0] HL2_concat,
	input wire [511:0] LH2_concat,
	input wire [255:0] HH3_concat,
	input wire [255:0] HL3_concat,
	input wire [255:0] LH3_concat,
	input wire [255:0] LL3_concat,
	
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
	input wire  s00_axi_rready,

	// Ports for AXI Master 00.
	input wire  m00_axi_aclk,
	input wire  m00_axi_aresetn,
	output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_awid,
	output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
	output wire [7 : 0] m00_axi_awlen,
	output wire [2 : 0] m00_axi_awsize,
	output wire [1 : 0] m00_axi_awburst,
	output wire  m00_axi_awlock,
	output wire [3 : 0] m00_axi_awcache,
	output wire [2 : 0] m00_axi_awprot,
	output wire [3 : 0] m00_axi_awqos,
	output wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] m00_axi_awuser,
	output wire  m00_axi_awvalid,
	input wire  m00_axi_awready,
	output wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
	output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
	output wire  m00_axi_wlast,
	output wire [C_M00_AXI_WUSER_WIDTH-1 : 0] m00_axi_wuser,
	output wire  m00_axi_wvalid,
	input wire  m00_axi_wready,
	input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_bid,
	input wire [1 : 0] m00_axi_bresp,
	input wire [C_M00_AXI_BUSER_WIDTH-1 : 0] m00_axi_buser,
	input wire  m00_axi_bvalid,
	output wire  m00_axi_bready,
	output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_arid,
	output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr,
	output wire [7 : 0] m00_axi_arlen,
	output wire [2 : 0] m00_axi_arsize,
	output wire [1 : 0] m00_axi_arburst,
	output wire  m00_axi_arlock,
	output wire [3 : 0] m00_axi_arcache,
	output wire [2 : 0] m00_axi_arprot,
	output wire [3 : 0] m00_axi_arqos,
	output wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] m00_axi_aruser,
	output wire  m00_axi_arvalid,
	input wire  m00_axi_arready,
	input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_rid,
	input wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata,
	input wire [1 : 0] m00_axi_rresp,
	input wire  m00_axi_rlast,
	input wire [C_M00_AXI_RUSER_WIDTH-1 : 0] m00_axi_ruser,
	input wire  m00_axi_rvalid,
	output wire  m00_axi_rready
);

// Debug signals mapped to AXI slave registers.
wire debug_m00_axi_armed;
wire [4:0] debug_c_state;
wire signed [9:0] q_mult_HH1;
wire signed [9:0] q_mult_HL1;
wire signed [9:0] q_mult_LH1;
wire signed [9:0] q_mult_LL1;
wire signed [23:0] debug_c_XX3_offset;
wire signed [23:0] debug_e_XX3_offset;
wire [255:0] debug_fifo_rd_count_concat;

// AXI Master 00 signals.
reg axi_init_txn;
reg [(C_M00_AXI_ADDR_WIDTH-1):0] axi_awaddr_init;
wire [(C_M00_AXI_DATA_WIDTH-1):0] axi_wdata;
wire axi_wnext;
wire axi_busy;

// Instantiation of AXI-Lite Slave.
Encoder_v1_0_S00_AXI 
#( 
	.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) 
Encoder_v1_0_S00_AXI_inst 
(
    .debug_m00_axi_armed(debug_m00_axi_armed),
    .debug_c_state(debug_c_state),
    .q_mult_HH1(q_mult_HH1),
    .q_mult_HL1(q_mult_HL1),
    .q_mult_LH1(q_mult_LH1),
    .q_mult_LL1(q_mult_LL1),
    .debug_c_XX3_offset(debug_c_XX3_offset),
    .debug_e_XX3_offset(debug_e_XX3_offset),
    .debug_fifo_rd_count_concat(debug_fifo_rd_count_concat),

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

// Instantiation of AXI Master.
Encoder_v1_0_M00_AXI 
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
Encoder_v1_0_M00_AXI_inst
(
	.axi_init_txn(axi_init_txn),
	.axi_awaddr_init(axi_awaddr_init),
	.axi_wdata(axi_wdata),
    .axi_wnext(axi_wnext),
    .axi_busy(axi_busy),
     
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

// Pixel counters at the interface between the vertical wavelet cores and the compressor.
// These are offset for the known latency of the wavelet stage(s):
// {HH1, HL1, LH1, LL1} R1 and G2 color field wavelet stage: 532 px_clk.
// {HH1, HL1, LH1, LL1} G2 and B1 color field wavelet stage: 533 px_clk.
// {HH2, HL2, LH2, LL2} All four color fields wavelet stage: 1582 px_clk.
// {HH3, HL3, LH3, LL3} All four color fields wavelet stage:
wire signed [23:0] px_count_c_XX1_R1G2;
assign px_count_c_XX1_R1G2 = px_count - 24'sh000214;
wire signed [23:0] px_count_c_XX1_G1B1;
assign px_count_c_XX1_G1B1 = px_count - 24'sh000215;
wire signed [23:0] px_count_c_XX2;
assign px_count_c_XX2 = px_count - 24'sh00062E;
wire signed [23:0] px_count_c_XX3;
assign px_count_c_XX3 = px_count - debug_c_XX3_offset;

// Pixel counters at the interface between the encoders and their output buffer.
// These are offset for the known latency of the wavelet stage(s) + the encoder and quantizer:
// {HH1, HL1, LH1, LL1} R1 and G2 color field: 538 px_clk. (+6 for compressor)
// {HH1, HL1, LH1, LL1} G2 and B1 color field: 539 px_clk. (+6 for compressor)
// {HH2, HL2, LH2, LL2} All four color fields: 1592 px_clk. (+10 for compressor_16in)
// {HH3, HL3, LH3, LL3} All four color fields:
wire signed [23:0] px_count_e_XX1_R1G2;
assign px_count_e_XX1_R1G2 = px_count - 24'sh00021A;
wire signed [23:0] px_count_e_XX1_G1B1;
assign px_count_e_XX1_G1B1 = px_count - 24'sh00021B;
wire signed [23:0] px_count_e_XX2;
assign px_count_e_XX2 = px_count - 24'sh000638;
wire signed [23:0] px_count_e_XX3;
assign px_count_c_XX3 = px_count - debug_e_XX3_offset;

// Create a shared phase flag for px_clk_2x, px_clk_2x_phase:
// 0: The previous px_clk_2x rising edge was aligned with a px_clk rising edge.
// 1: The previous px_clk_2x rising edge was aligned with a px_clk falling edge.
reg px_count_prev_LSB_2x; 
wire px_clk_2x_phase;
always @(posedge px_clk_2x)
begin
    px_count_prev_LSB_2x <= px_count[0];
end
assign px_clk_2x_phase = (px_count[0] == px_count_prev_LSB_2x);

// Shared FIFO read enable signal, controlled by the AXI Master round-robin.
wire fifo_rd_en;

// Independent compressor FIFO controls and data.
wire fifo_rd_next[15:0];
wire [9:0] fifo_rd_count[15:0];
wire [127:0] fifo_rd_data[15:0];

// Compressor instantiation and mapping.
// --------------------------------------------------------------------------------
compressor c_HH1_R1     // Stream 00, handling HH1.R1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_HH1),
    
    .in_2px_concat(HH1_concat[0+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[0]),
    .fifo_rd_count(fifo_rd_count[0]),
    .fifo_rd_data(fifo_rd_data[0])
);
compressor c_HH1_G1     // Stream 01, handling HH1.G1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_HH1),
    
    .in_2px_concat(HH1_concat[256+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[1]),
    .fifo_rd_count(fifo_rd_count[1]),
    .fifo_rd_data(fifo_rd_data[1])
);
compressor c_HH1_G2     // Stream 02, handling HH1.G2[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_HH1),
    
    .in_2px_concat(HH1_concat[512+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[2]),
    .fifo_rd_count(fifo_rd_count[2]),
    .fifo_rd_data(fifo_rd_data[2])
);
compressor c_HH1_B1     // Stream 03, handling HH1.B1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_HH1),
    
    .in_2px_concat(HH1_concat[768+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[3]),
    .fifo_rd_count(fifo_rd_count[3]),
    .fifo_rd_data(fifo_rd_data[3])
);
compressor c_HL1_R1     // Stream 04, handling HL1.R1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_HL1),
    
    .in_2px_concat(HL1_concat[0+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[4]),
    .fifo_rd_count(fifo_rd_count[4]),
    .fifo_rd_data(fifo_rd_data[4])
);
compressor c_HL1_G1     // Stream 05, handling HL1.G1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_HL1),
    
    .in_2px_concat(HL1_concat[256+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[5]),
    .fifo_rd_count(fifo_rd_count[5]),
    .fifo_rd_data(fifo_rd_data[5])
);
compressor c_HL1_G2     // Stream 06, handling HL1.G2[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_HL1),
    
    .in_2px_concat(HL1_concat[512+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[6]),
    .fifo_rd_count(fifo_rd_count[6]),
    .fifo_rd_data(fifo_rd_data[6])
);
compressor c_HL1_B1     // Stream 07, handling HL1.B1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_HL1),
    
    .in_2px_concat(HL1_concat[768+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[7]),
    .fifo_rd_count(fifo_rd_count[7]),
    .fifo_rd_data(fifo_rd_data[7])
);
compressor c_LH1_R1     // Stream 08, handling LH1.R1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_LH1),
    
    .in_2px_concat(LH1_concat[0+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[8]),
    .fifo_rd_count(fifo_rd_count[8]),
    .fifo_rd_data(fifo_rd_data[8])
);
compressor c_LH1_G1     // Stream 09, handling LH1.G1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_LH1),
    
    .in_2px_concat(LH1_concat[256+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[9]),
    .fifo_rd_count(fifo_rd_count[9]),
    .fifo_rd_data(fifo_rd_data[9])
);
compressor c_LH1_G2     // Stream 10, handling LH1.G2[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_R1G2),
    .px_count_e(px_count_e_XX1_R1G2),
    .q_mult(q_mult_LH1),
    
    .in_2px_concat(LH1_concat[512+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[10]),
    .fifo_rd_count(fifo_rd_count[10]),
    .fifo_rd_data(fifo_rd_data[10])
);
compressor c_LH1_B1     // Stream 11, handling LH1.B1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX1_G1B1),
    .px_count_e(px_count_e_XX1_G1B1),
    .q_mult(q_mult_LH1),
    
    .in_2px_concat(LH1_concat[768+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[11]),
    .fifo_rd_count(fifo_rd_count[11]),
    .fifo_rd_data(fifo_rd_data[11])
);
compressor_16in c_HH2     // Stream 12, handling HH2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX2),
    .px_count_e(px_count_e_XX2),
    .q_mult(q_mult_HH1),    // TO-DO: Give this its own setting.
    
    .in_2px_concat(HH2_concat),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[12]),
    .fifo_rd_count(fifo_rd_count[12]),
    .fifo_rd_data(fifo_rd_data[12])
);
compressor_16in c_HL2     // Stream 13, handling HL2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX2),
    .px_count_e(px_count_e_XX2),
    .q_mult(q_mult_HL1),    // TO-DO: Give this its own setting.
    
    .in_2px_concat(HL2_concat),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[13]),
    .fifo_rd_count(fifo_rd_count[13]),
    .fifo_rd_data(fifo_rd_data[13])
);
compressor_16in c_LH2     // Stream 14, handling LH2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX2),
    .px_count_e(px_count_e_XX2),
    .q_mult(q_mult_LH1),    // TO-DO: Give this its own setting.
    
    .in_2px_concat(LH2_concat),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[14]),
    .fifo_rd_count(fifo_rd_count[14]),
    .fifo_rd_data(fifo_rd_data[14])
);
compressor_32in c_XX3     // Stream 15, handling HH3, HL3, LH3, and LL3
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_clk_2x_phase(px_clk_2x_phase),
    .px_count_c(px_count_c_XX3),
    .px_count_e(px_count_e_XX3),
    .q_mult_HH3(q_mult_HH1),    // TO-DO: Give these their own setting.
    .q_mult_HL3(q_mult_HL1),
    .q_mult_LH3(q_mult_LH1),
    .q_mult_LL3(q_mult_LL1),
    
    .in_2px_HH3_concat(HH3_concat),
    .in_2px_HL3_concat(HL3_concat),
    .in_2px_LH3_concat(LH3_concat),
    .in_2px_LL3_concat(LL3_concat),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[15]),
    .fifo_rd_count(fifo_rd_count[15]),
    .fifo_rd_data(fifo_rd_data[15])
);
// --------------------------------------------------------------------------------

// Round-robin RAM writer.
// --------------------------------------------------------------------------------
// RAM writer state, cycles through the 16 compressors.
reg [3:0] c_state;

// Data switch.
assign axi_wdata = fifo_rd_data[c_state];

// Read next data switch.
genvar i;
for (i = 0; i < 16; i = i + 1)
begin
    assign fifo_rd_next[i] = axi_wnext & (c_state == i);
end

// Address generation.
reg [31:0] c_RAM_offset [15:0];
localparam [511:0] c_RAM_base_concat = 
{32'h68000000, 32'h60000000, 32'h58000000, 32'h50000000,    // LL1
 32'h4C000000, 32'h48000000, 32'h44000000, 32'h40000000,    // LH1
 32'h3C000000, 32'h38000000, 32'h34000000, 32'h30000000,    // HL1
 32'h2C000000, 32'h28000000, 32'h24000000, 32'h20000000};   // HH1
localparam [511:0] c_RAM_mask = 
{32'h07FFFFFF, 32'h07FFFFFF, 32'h07FFFFFF, 32'h07FFFFFF,    // LL1
 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF,    // LH1
 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF,    // HL1
 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF, 32'h03FFFFFF};   // HH1
wire [31:0] c_RAM_base;
wire [31:0] c_RAM_offset_masked;
assign c_RAM_base = c_RAM_base_concat[32*c_state+:32];
assign c_RAM_offset_masked = c_RAM_offset[c_state] & c_RAM_mask[32*c_state+:32];

// Trigger on FIFO fill level.
wire fifo_trigger;
assign fifo_trigger = (fifo_rd_count[c_state] > 10'h80);

// Fun times state machine.
reg axi_busy_wait;
always @(posedge m00_axi_aclk)
begin
    if (~debug_m00_axi_armed)
    begin : axi_rst
        // Synchronous reset of the RAM writer.
        integer j;
        for(j = 0; j < 16; j = j + 1)
        begin
            c_RAM_offset[j] <= 32'h0;
        end
        c_state <= 4'h0;
        axi_awaddr_init <= 1'b0;
        axi_init_txn <= 1'b0;
        axi_busy_wait <= 1'b0;
    end : axi_rst
    else
    begin
        if (fifo_trigger & ~axi_init_txn & ~axi_busy_wait)
        begin
            // FIFO threshold is met, start a transcation.
            axi_awaddr_init <= c_RAM_base + c_RAM_offset_masked;
            axi_init_txn <= 1'b1;
        end
        else if (axi_init_txn & axi_busy)
        begin
            // Transaction started, end init pulse and set busy wait.
            axi_init_txn <= 1'b0;
            axi_busy_wait <= 1'b1;
        end
        else if (axi_busy_wait & ~axi_busy)
        begin
            // Transaction complete, end the busy wait. 
            // Increment the write offset by 256B and increment the state.
            axi_busy_wait <= 1'b0;
            c_RAM_offset[c_state] <= c_RAM_offset[c_state] + 32'h100;
            c_state <= c_state + 4'h1;
        end
        else if(~fifo_trigger & ~axi_init_txn & ~axi_busy_wait)
        begin
            // FIFO threshold is not met. Just increment the state.
            c_state <= c_state + 4'h1;
        end
        
        if (debug_c_state[4])
        begin
            c_state <= debug_c_state[3:0];
        end
    end
end

// --------------------------------------------------------------------------------

// Debug signals.
for (i = 0; i < 16; i = i + 1)
begin
    assign debug_fifo_rd_count_concat[16*i+:16] = fifo_rd_count[i];
end

// User logic ends

endmodule
