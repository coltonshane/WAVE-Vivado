`timescale 1 ns / 1 ps
/*
===================================================================================
Encoderv1_0.v
Top module of encoder/quantizer. Receives output data from the wavelet stages,
quantizes and encoders it, and writes the compressed stream to PS DDR4 using a 
250MHz x 128b AXI master. Configuration and control is done via an AXI-Lite slave.
===================================================================================
*/

module Encoder_v1_0
#(
	// Parameters for AXI-Lite Slave.
	parameter integer C_S00_AXI_DATA_WIDTH = 32,
	parameter integer C_S00_AXI_ADDR_WIDTH = 10,

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

// Debug signals.
wire [31:0] debug_rd_addr;
wire debug_arm_axi;

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

// Input views of individual color fields.
wire [255:0] HH1_R1_concat;
wire [255:0] HH1_G1_concat;
wire [255:0] HH1_G2_concat;
wire [255:0] HH1_B1_concat;
wire [255:0] HL1_R1_concat;
wire [255:0] HL1_G1_concat;
wire [255:0] HL1_G2_concat;
wire [255:0] HL1_B1_concat;
wire [255:0] LH1_R1_concat;
wire [255:0] LH1_G1_concat;
wire [255:0] LH1_G2_concat;
wire [255:0] LH1_B1_concat;

assign HH1_R1_concat = HH1_concat[255:0] ;
assign HH1_G1_concat = HH1_concat[511:256];
assign HH1_G2_concat = HH1_concat[767:512];
assign HH1_B1_concat = HH1_concat[1023:768];
assign HL1_R1_concat = HL1_concat[255:0];
assign HL1_G1_concat = HL1_concat[511:256];
assign HL1_G2_concat = HL1_concat[767:512];
assign HL1_B1_concat = HL1_concat[1023:768];
assign LH1_R1_concat = LH1_concat[255:0];
assign LH1_G1_concat = LH1_concat[511:256];
assign LH1_G2_concat = LH1_concat[767:512];
assign LH1_B1_concat = LH1_concat[1023:768];

// Pixel counters at the interface between the first-stage wavelet core outputs
// and the first-stage quantizer input. These are offset by the known latency
// of the first-stage wavelet cores:
// R1 and G2 color field first-stage wavelet cores: 532 px_clk.
// G2 and B1 color field first-stage wavelet cores: 533 px_clk.
wire signed [23:0] px_count_q1_R1G2;
assign px_count_q1_R1G2 = px_count - 24'sh000214;
wire signed [23:0] px_count_q1_G1B1;
assign px_count_q1_G1B1 = px_count - 24'sh000215;

// Output views for debugging.
wire [63:0] debug_out_4px_HH1_R1;
wire [63:0] debug_out_4px_HH1_G1;
wire [63:0] debug_out_4px_HH1_G2;
wire [63:0] debug_out_4px_HH1_B1;
wire [63:0] debug_out_4px_HL1_R1;
wire [63:0] debug_out_4px_HL1_G1;
wire [63:0] debug_out_4px_HL1_G2;
wire [63:0] debug_out_4px_HL1_B1;
wire [63:0] debug_out_4px_LH1_R1;
wire [63:0] debug_out_4px_LH1_G1;
wire [63:0] debug_out_4px_LH1_G2;
wire [63:0] debug_out_4px_LH1_B1;

// Instantiate quantizer / row buffer for each subband color field.
quantizer1 q1_HH1_R1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(HH1_R1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HH1_R1)
);

quantizer1 q1_HH1_G1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(HH1_G1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HH1_G1)
);

quantizer1 q1_HH1_G2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(HH1_G2_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HH1_G1)
);

quantizer1 q1_HH1_B1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(HH1_B1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HH1_B1)
);

quantizer1 q1_HL1_R1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(HL1_R1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HL1_R1)
);

quantizer1 q1_HL1_G1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(HL1_G1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HL1_G1)
);

quantizer1 q1_HL1_G2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(HL1_G2_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HL1_G1)
);

quantizer1 q1_HL1_B1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(HL1_B1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_HL1_B1)
);

quantizer1 q1_LH1_R1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(LH1_R1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_LH1_R1)
);

quantizer1 q1_LH1_G1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(LH1_G1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_LH1_G1)
);

quantizer1 q1_LH1_G2
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_R1G2),
    
    .q_level(3'b0),
    
    .in_2px_concat(LH1_G2_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_LH1_G1)
);

quantizer1 q1_LH1_B1
(
    .px_clk(px_clk),
    .px_clk_2x(px_clk_2x),
    .px_count_q1(px_count_q1_G1B1),
    
    .q_level(3'b0),
    
    .in_2px_concat(LH1_B1_concat),
    .rd_addr(debug_rd_addr[8:0]),
    .out_4px(debug_out_4px_LH1_B1)
);

// User logic ends

endmodule
