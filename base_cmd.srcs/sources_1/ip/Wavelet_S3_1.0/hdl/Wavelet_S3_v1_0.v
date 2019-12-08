
`timescale 1 ns / 1 ps
/*
=================================================================================
Wavelet_S3_v1_0.v
Top module for third stage of wavelet engine. Receives pixel pairs from the
second stage and performs a 2D DWT via separate horizontal and then vertical
wavelet cores. The results are passed to an encoder (XX3 channel). Control  and 
configuration is done through an AXI-Lite slave.
=================================================================================
*/

// Color field enumeration.
`define COLOR_R1 2'b00
`define COLOR_G1 2'b01
`define COLOR_G2 2'b10
`define COLOR_B1 2'b11

module Wavelet_S3_v1_0 #
(
	// Users to add parameters here
    parameter integer PX_MATH_WIDTH = 12,
	// User parameters ends
	// Do not modify the parameters beyond this line

	// Parameters of Axi Slave Bus Interface S00_AXI
	parameter integer C_S00_AXI_DATA_WIDTH	= 32,
	parameter integer C_S00_AXI_ADDR_WIDTH	= 5
)
(
	// Users to add ports here
		
	input wire px_clk,
	input wire px_clk_2x,
	input wire signed [23:0] px_count,
	input wire [511:0] LL2_concat,
		
    output wire [255:0] HH3_concat,
	output wire [255:0] HL3_concat,
	output wire [255:0] LH3_concat,
	output wire [255:0] LL3_concat,
	
	// User ports ends
		
	// Do not modify the ports beyond this line

	// Ports of Axi Slave Bus Interface S00_AXI
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

// Debug port for peeking at wavelet core data through AXI.
wire signed [23:0] debug_px_count_trig;
wire [31:0] debug_core_addr;
reg [31:0] debug_core_HH3_data;
reg [31:0] debug_core_HL3_data;
reg [31:0] debug_core_LH3_data;
reg [31:0] debug_core_LL3_data;

// Instantiation of Axi Bus Interface S00_AXI
Wavelet_S3_v1_0_S00_AXI 
#( 
    .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) 
Wavelet_S3_v1_0_S00_AXI_inst 
(
    .debug_px_count_trig(debug_px_count_trig),
    .debug_core_addr(debug_core_addr),
    .debug_core_HH3_data(debug_core_HH3_data),
    .debug_core_HL3_data(debug_core_HL3_data),
    .debug_core_LH3_data(debug_core_LH3_data),
    .debug_core_LL3_data(debug_core_LL3_data),
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

genvar i;

// Pixel counter at the interface between the vertical S2 wavelet cores and the horizontal 
// S3 wavelet cores. These are offset for the known latency of S2: 1582 px_clk.
wire signed [23:0] px_count_h3;
assign px_count_h3 = px_count - 24'sh00062E;

// Extract pixel pair index within a row from the pixel counter. This increments every
// eight pixels, when a new pixel pair is available from S2. When it increments, a flag is
// set for the horizontal S3 cores to execute a step.
wire [5:0] px_idx;
reg px_idx_prev_LSB;
wire px_idx_updated;
assign px_idx = px_count_h3[8:3];
always @(posedge px_clk)
begin
    px_idx_prev_LSB <= px_idx[0];
end
assign px_idx_updated = px_idx[0] ^ px_idx_prev_LSB;

// Declare I/O arrays for the horizontal wavelet cores.
wire signed [15:0] S_pp0_fromR_R1 [3:0];
wire signed [15:0] D_pp0_fromR_R1 [3:0];
wire signed [15:0] S_pp1_fromR_R1 [3:0];
wire signed [15:0] S_pp0_toL_R1 [3:0];
wire signed [15:0] D_pp0_toL_R1 [3:0];
wire signed [15:0] S_pp1_toL_R1 [3:0];
wire signed [15:0] S_out_R1 [3:0];
wire signed [15:0] D_out_R1 [3:0];

wire signed [15:0] S_pp0_fromR_G1 [3:0];
wire signed [15:0] D_pp0_fromR_G1 [3:0];
wire signed [15:0] S_pp1_fromR_G1 [3:0];
wire signed [15:0] S_pp0_toL_G1 [3:0];
wire signed [15:0] D_pp0_toL_G1 [3:0];
wire signed [15:0] S_pp1_toL_G1 [3:0];
wire signed [15:0] S_out_G1 [3:0];
wire signed [15:0] D_out_G1 [3:0];

wire signed [15:0] S_pp0_fromR_G2 [3:0];
wire signed [15:0] D_pp0_fromR_G2 [3:0];
wire signed [15:0] S_pp1_fromR_G2 [3:0];
wire signed [15:0] S_pp0_toL_G2 [3:0];
wire signed [15:0] D_pp0_toL_G2 [3:0];
wire signed [15:0] S_pp1_toL_G2 [3:0];
wire signed [15:0] S_out_G2 [3:0];
wire signed [15:0] D_out_G2 [3:0];

wire signed [15:0] S_pp0_fromR_B1 [3:0];
wire signed [15:0] D_pp0_fromR_B1 [3:0];
wire signed [15:0] S_pp1_fromR_B1 [3:0];
wire signed [15:0] S_pp0_toL_B1 [3:0];
wire signed [15:0] D_pp0_toL_B1 [3:0];
wire signed [15:0] S_pp1_toL_B1 [3:0];
wire signed [15:0] S_out_B1 [3:0];
wire signed [15:0] D_out_B1 [3:0];

// Tie adjacent cores together (in circular fashion).
for(i = 0; i < 4; i = i + 1)
begin
    // Link data from pixel pairs 0 and 1 across cores from right to left.
    // The link is circular, i.e. core 3 is linked to core 0.
    assign S_pp0_fromR_R1[i] = S_pp0_toL_R1[(i+1) & 32'h3];
    assign D_pp0_fromR_R1[i] = D_pp0_toL_R1[(i+1) & 32'h3];
    assign S_pp1_fromR_R1[i] = S_pp1_toL_R1[(i+1) & 32'h3];
    
    assign S_pp0_fromR_G1[i] = S_pp0_toL_G1[(i+1) & 32'h3];
    assign D_pp0_fromR_G1[i] = D_pp0_toL_G1[(i+1) & 32'h3];
    assign S_pp1_fromR_G1[i] = S_pp1_toL_G1[(i+1) & 32'h3];
    
    assign S_pp0_fromR_G2[i] = S_pp0_toL_G2[(i+1) & 32'h3];
    assign D_pp0_fromR_G2[i] = D_pp0_toL_G2[(i+1) & 32'h3];
    assign S_pp1_fromR_G2[i] = S_pp1_toL_G2[(i+1) & 32'h3];
    
    assign S_pp0_fromR_B1[i] = S_pp0_toL_B1[(i+1) & 32'h3];
    assign D_pp0_fromR_B1[i] = D_pp0_toL_B1[(i+1) & 32'h3];
    assign S_pp1_fromR_B1[i] = S_pp1_toL_B1[(i+1) & 32'h3];
end

// Instantiate 16 horizontal wavelet cores (4 each for R1, G1, G2, and B1 color fields).
generate
for (i = 0; i < 4; i = i + 1)
begin : dwt26_h3_array

    dwt26_h3
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    R1
    (
        .px_clk(px_clk),
        .px_idx(px_idx),
        .px_idx_updated(px_idx_updated),
        .X_even(LL2_concat[(32*i+0)+:16]),  // LL2_R1[i] low pixel
        .X_odd(LL2_concat[(32*i+16)+:16]),  // LL2_R1[i] high pixel
        .S_pp0_fromR(S_pp0_fromR_R1[i]),
        .D_pp0_fromR(D_pp0_fromR_R1[i]),
        .S_pp1_fromR(S_pp1_fromR_R1[i]),
        .S_pp0_toL(S_pp0_toL_R1[i]),
        .D_pp0_toL(D_pp0_toL_R1[i]),
        .S_pp1_toL(S_pp1_toL_R1[i]),
        .S_out(S_out_R1[i]),
        .D_out(D_out_R1[i])
    );
    
    dwt26_h3
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    G1
    (
        .px_clk(px_clk),
        .px_idx(px_idx),
        .px_idx_updated(px_idx_updated),
        .X_even(LL2_concat[(32*i+128)+:16]),  // LL2_G1[i] low pixel
        .X_odd(LL2_concat[(32*i+144)+:16]),   // LL2_G1[i] high pixel
        .S_pp0_fromR(S_pp0_fromR_G1[i]),
        .D_pp0_fromR(D_pp0_fromR_G1[i]),
        .S_pp1_fromR(S_pp1_fromR_G1[i]),
        .S_pp0_toL(S_pp0_toL_G1[i]),
        .D_pp0_toL(D_pp0_toL_G1[i]),
        .S_pp1_toL(S_pp1_toL_G1[i]),
        .S_out(S_out_G1[i]),
        .D_out(D_out_G1[i])
    );
    
    dwt26_h3
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    G2
    (
        .px_clk(px_clk),
        .px_idx(px_idx),
        .px_idx_updated(px_idx_updated),
        .X_even(LL2_concat[(32*i+256)+:16]),  // LL2_G2[i] low pixel
        .X_odd(LL2_concat[(32*i+272)+:16]),   // LL2_G2[i] high pixel
        .S_pp0_fromR(S_pp0_fromR_G2[i]),
        .D_pp0_fromR(D_pp0_fromR_G2[i]),
        .S_pp1_fromR(S_pp1_fromR_G2[i]),
        .S_pp0_toL(S_pp0_toL_G2[i]),
        .D_pp0_toL(D_pp0_toL_G2[i]),
        .S_pp1_toL(S_pp1_toL_G2[i]),
        .S_out(S_out_G2[i]),
        .D_out(D_out_G2[i])
    );
    
    dwt26_h3
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    B1
    (
        .px_clk(px_clk),
        .px_idx(px_idx),
        .px_idx_updated(px_idx_updated),
        .X_even(LL2_concat[(32*i+384)+:16]),  // LL2_B1[i] low pixel
        .X_odd(LL2_concat[(32*i+400)+:16]),   // LL2_B1[i] high pixel
        .S_pp0_fromR(S_pp0_fromR_B1[i]),
        .D_pp0_fromR(D_pp0_fromR_B1[i]),
        .S_pp1_fromR(S_pp1_fromR_B1[i]),
        .S_pp0_toL(S_pp0_toL_B1[i]),
        .D_pp0_toL(D_pp0_toL_B1[i]),
        .S_pp1_toL(S_pp1_toL_B1[i]),
        .S_out(S_out_B1[i]),
        .D_out(D_out_B1[i])
    );

end : dwt26_h3_array
endgenerate

// Pixel counter at the interface between the vertical and horizontal third-stage cores.
// This is offset for the known latency of the pipeline up to the third-stage 
// horizontal cores. All color fields have the same latency here: 1608 px_clk.
wire signed [23:0] px_count_v3;
assign px_count_v3 = px_count - 24'sh000648;

// Arrays for third-stage vertical core output data.
wire [31:0] HH3_R1 [1:0];
wire [31:0] HL3_R1 [1:0];
wire [31:0] LH3_R1 [1:0];
wire [31:0] LL3_R1 [1:0];
wire [31:0] HH3_G1 [1:0];
wire [31:0] HL3_G1 [1:0];
wire [31:0] LH3_G1 [1:0];
wire [31:0] LL3_G1 [1:0];
wire [31:0] HH3_G2 [1:0];
wire [31:0] HL3_G2 [1:0];
wire [31:0] LH3_G2 [1:0];
wire [31:0] LL3_G2 [1:0];
wire [31:0] HH3_B1 [1:0];
wire [31:0] HL3_B1 [1:0];
wire [31:0] LH3_B1 [1:0];
wire [31:0] LL3_B1 [1:0];

// These arrays are concatenated into 256-bit interfaces to the encoder (HH3, HL3, LH3, LL3).
for(i = 0; i < 2; i = i + 1)
begin
    assign HH3_concat[32*i+:32] = HH3_R1[i];
    assign HH3_concat[(32*i+64)+:32] = HH3_G1[i];
    assign HH3_concat[(32*i+128)+:32] = HH3_G2[i];
    assign HH3_concat[(32*i+192)+:32] = HH3_B1[i];
    assign HL3_concat[32*i+:32] = HL3_R1[i];
    assign HL3_concat[(32*i+64)+:32] = HL3_G1[i];
    assign HL3_concat[(32*i+128)+:32] = HL3_G2[i];
    assign HL3_concat[(32*i+192)+:32] = HL3_B1[i];
    assign LH3_concat[32*i+:32] = LH3_R1[i];
    assign LH3_concat[(32*i+64)+:32] = LH3_G1[i];
    assign LH3_concat[(32*i+128)+:32] = LH3_G2[i];
    assign LH3_concat[(32*i+192)+:32] = LH3_B1[i];
    assign LL3_concat[32*i+:32] = LL3_R1[i];
    assign LL3_concat[(32*i+64)+:32] = LL3_G1[i];
    assign LL3_concat[(32*i+128)+:32] = LL3_G2[i];
    assign LL3_concat[(32*i+192)+:32] = LL3_B1[i];
end

// Instantiate 8 vertical wavelet cores (2 each for R1, G1, G2, and B1 color fields).
// Each vertical core input is fed by the outputs of two adjacent horizontal cores.
generate
for (i = 0; i < 2; i = i + 1)
begin : dwt26_v3_array

    dwt26_v3 
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    R1
    (
        .px_clk(px_clk),
        .px_count_v3(px_count_v3),
        .S_in_0(S_out_R1[2*i+0]),
        .D_in_0(D_out_R1[2*i+0]),
        .S_in_1(S_out_R1[2*i+1]),
        .D_in_1(D_out_R1[2*i+1]),

        .HH3_out(HH3_R1[i]),
        .HL3_out(HL3_R1[i]),
        .LH3_out(LH3_R1[i]),
        .LL3_out(LL3_R1[i])
    );
    
    dwt26_v3 
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    G1
    (
        .px_clk(px_clk),
        .px_count_v3(px_count_v3),
        .S_in_0(S_out_G1[2*i+0]),
        .D_in_0(D_out_G1[2*i+0]),
        .S_in_1(S_out_G1[2*i+1]),
        .D_in_1(D_out_G1[2*i+1]),

        .HH3_out(HH3_G1[i]),
        .HL3_out(HL3_G1[i]),
        .LH3_out(LH3_G1[i]),
        .LL3_out(LL3_G1[i])
    );
    
    dwt26_v3 
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    G2
    (
        .px_clk(px_clk),
        .px_count_v3(px_count_v3),
        .S_in_0(S_out_G2[2*i+0]),
        .D_in_0(D_out_G2[2*i+0]),
        .S_in_1(S_out_G2[2*i+1]),
        .D_in_1(D_out_G2[2*i+1]),

        .HH3_out(HH3_G2[i]),
        .HL3_out(HL3_G2[i]),
        .LH3_out(LH3_G2[i]),
        .LL3_out(LL3_G2[i])
    );
    
    dwt26_v3 
    #(
        .PX_MATH_WIDTH(PX_MATH_WIDTH)
    )
    B1
    (
        .px_clk(px_clk),
        .px_count_v3(px_count_v3),
        .S_in_0(S_out_B1[2*i+0]),
        .D_in_0(D_out_B1[2*i+0]),
        .S_in_1(S_out_B1[2*i+1]),
        .D_in_1(D_out_B1[2*i+1]),

        .HH3_out(HH3_B1[i]),
        .HL3_out(HL3_B1[i]),
        .LH3_out(LH3_B1[i]),
        .LL3_out(LL3_B1[i])
    );
    
end : dwt26_v3_array
endgenerate

// Debug access to core output data.
/*
always @(posedge px_clk)
begin
if (px_count == debug_px_count_trig)
begin
    case (debug_core_addr[2:1])
        `COLOR_R1:
        begin 
            debug_core_HH3_data <= HH3_R1[debug_core_addr[0]];
            debug_core_HL3_data <= HL3_R1[debug_core_addr[0]];
            debug_core_LH3_data <= LH3_R1[debug_core_addr[0]];
            debug_core_LL3_data <= LL3_R1[debug_core_addr[0]];
        end
        `COLOR_G1:
        begin 
            debug_core_HH3_data <= HH3_G1[debug_core_addr[0]];
            debug_core_HL3_data <= HL3_G1[debug_core_addr[0]];
            debug_core_LH3_data <= LH3_G1[debug_core_addr[0]];
            debug_core_LL3_data <= LL3_G1[debug_core_addr[0]];
        end
        `COLOR_G2:
        begin 
            debug_core_HH3_data <= HH3_G2[debug_core_addr[0]];
            debug_core_HL3_data <= HL3_G2[debug_core_addr[0]];
            debug_core_LH3_data <= LH3_G2[debug_core_addr[0]];
            debug_core_LL3_data <= LL3_G2[debug_core_addr[0]];
        end
        `COLOR_B1:
        begin 
            debug_core_HH3_data <= HH3_B1[debug_core_addr[0]];
            debug_core_HL3_data <= HL3_B1[debug_core_addr[0]];
            debug_core_LH3_data <= LH3_B1[debug_core_addr[0]];
            debug_core_LL3_data <= LL3_B1[debug_core_addr[0]];
        end
    endcase
end
end
*/
// User logic ends

endmodule
