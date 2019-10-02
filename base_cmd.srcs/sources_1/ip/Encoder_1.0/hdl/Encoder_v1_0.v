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
	parameter integer C_S00_AXI_ADDR_WIDTH = 4,

	// Parameters for AXI Master 00.
	parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
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
	input wire [1023:0] LL1_concat,
	
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

// AXI Master arming signal
wire m00_axi_armed;

// AXI Master 00 signals.
reg axi_init_txn;
reg [(C_M00_AXI_ADDR_WIDTH-1):0] axi_awaddr_init;
reg [(C_M00_AXI_DATA_WIDTH-1):0] axi_wdata;
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

genvar i;

// Compressor quantizer settings. These should be mapped to AXI-Lite Slave registers.
wire signed [9:0] q_mult_HH1;
wire signed [9:0] q_mult_HL1;
wire signed [9:0] q_mult_LH1;
wire signed [9:0] q_mult_LL1;
assign q_mult_HH1 = 9'sh20;
assign q_mult_HL1 = 9'sh20;
assign q_mult_LH1 = 9'sh20;
assign q_mult_LL1 = 9'sh80;

// Pixel counters at the interface between the vertical wavelet cores and the compressor.
// These are offset for the known latency of the wavelet stage(s):
// {HH1, HL1, LH1, LL1} R1 and G2 color field wavelet stage: 517 px_clk.
// {HH1, HL1, LH1, LL1} G2 and B1 color field wavelet stage: 518 px_clk.
wire signed [23:0] px_count_c_XX1_R1G2;
assign px_count_c_XX1_R1G2 = px_count - 24'sh000205;
wire signed [23:0] px_count_c_XX1_G1B1;
assign px_count_c_XX1_G1B1 = px_count - 24'sh000206;

// Shared FIFO read enable signal, controlled by the AXI Master round-robin.
wire fifo_rd_en;

// Independent compressor FIFO controls and data.
wire fifo_rd_next[15:0];
wire [13:0] fifo_rd_count[15:0];
wire [127:0] fifo_rd_data[15:0];

// Compressor instantiation and mapping.
// --------------------------------------------------------------------------------
compressor c_HH1_R1     // Stream 00, handling HH1.R1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
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
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
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
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
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
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
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
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
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
    .px_count_c(px_count_c_XX1_R1G2),
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
    .px_count_c(px_count_c_XX1_G1B1),
    .q_mult(q_mult_LH1),
    
    .in_2px_concat(LH1_concat[768+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[11]),
    .fifo_rd_count(fifo_rd_count[11]),
    .fifo_rd_data(fifo_rd_data[11])
);
compressor c_LL1_R1     // Stream 12, handling LL1.R1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_c(px_count_c_XX1_R1G2),
    .q_mult(q_mult_LL1),
    
    .in_2px_concat(LL1_concat[0+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[12]),
    .fifo_rd_count(fifo_rd_count[12]),
    .fifo_rd_data(fifo_rd_data[12])
);
compressor c_LL1_G1     // Stream 13, handling LL1.G1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_c(px_count_c_XX1_G1B1),
    .q_mult(q_mult_LL1),
    
    .in_2px_concat(LL1_concat[256+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[13]),
    .fifo_rd_count(fifo_rd_count[13]),
    .fifo_rd_data(fifo_rd_data[13])
);
compressor c_LL1_G2     // Stream 14, handling LL1.G2[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_c(px_count_c_XX1_R1G2),
    .q_mult(q_mult_LL1),
    
    .in_2px_concat(LL1_concat[512+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[14]),
    .fifo_rd_count(fifo_rd_count[14]),
    .fifo_rd_data(fifo_rd_data[14])
);
compressor c_LL1_B1     // Stream 15, handling LL1.B1[7:0]
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_c(px_count_c_XX1_G1B1),
    .q_mult(q_mult_LL1),
    
    .in_2px_concat(LL1_concat[768+:256]),
    
    .m00_axi_aclk(m00_axi_aclk),
    .fifo_rd_next(fifo_rd_next[15]),
    .fifo_rd_count(fifo_rd_count[15]),
    .fifo_rd_data(fifo_rd_data[15])
);
// --------------------------------------------------------------------------------

// Dumb muxer just to see if the correct number of resources are used.
assign fifo_rd_en = 1'b1;       // Always read.
reg [3:0] fifo_rd_state;

always @(posedge m00_axi_aclk)
begin
    if (~axi_init_txn & ~axi_busy)
    begin
        // Request to transmit.
        axi_init_txn <= 1'b1;
    end
    else if (axi_init_txn & axi_busy)
    begin
        // Request received, end pulse and increment address.
        axi_init_txn <= 1'b0;
        fifo_rd_state <= fifo_rd_state + 1'b1;
    end

    axi_wdata <= fifo_rd_data[fifo_rd_state];
end

// User logic ends

endmodule
