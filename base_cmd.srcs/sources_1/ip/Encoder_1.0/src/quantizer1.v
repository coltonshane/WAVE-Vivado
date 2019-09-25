`timescale 1ns / 1ps
/*
=================================================================================
quantizer1.v
Quantization and row buffer for first-stage wavelet data encoding. Receives data 
from one subband (HH1, HL1, LH1) of one color field (R1, G1, G2, B1) as two 16-
bit signed integers. These are quantized by right shifting, then written into
a 32K BRAM row buffer covering two full-width (1024px) rows:

            |<----------------------- 1024px --------------------->|
            [HH1.0][HH1.1][HH1.2][HH1.3][HH1.4][HH1.5][HH1.6][HH1.7] --> Out
     In --> [HH1.0][HH1.1][HH1.2][HH1.3][HH1.4][HH1.5][HH1.6][HH1.7]
            
32-bit writes to one row occur on px_clk_2x (120MHz), cycling through 8 first-
stage wavelet outputs in the 4 px_clk interval between their updates. The write
address is used to arrange the data sequentially in the row, as show above.

64-bit reads from the other row occur on px_clk (60MHz) and feeds 4-pixel data
units to the encoder.

After this buffer, pixel data is available in true left-to-right, top-to-bottom
sequence for the encoder and RAM writer.
=================================================================================
*/

module quantizer1
(
    input wire px_clk,
    input wire px_clk_2x,
    input wire signed [23:0] px_count_q1,
    
    input wire signed [2:0] q_level,
    
    input wire [255:0] in_2px_concat,
    input wire [8:0] rd_addr,
    output reg [63:0] out_4px
);

// Memory to be inferred as a single BRAM (32K = 2 x 1024 x 16b).
reg [31:0] mem [1023:0];

genvar i;

// Quantization (combinational).
// -------------------------------------------------------------------------------------------------
wire signed [15:0] in_px_0 [7:0];
wire signed [15:0] in_px_1 [7:0];
wire signed [15:0] q_px_0 [7:0];
wire signed [15:0] q_px_1 [7:0];
for(i = 0; i < 8; i = i + 1)
begin
    assign in_px_0[i] = in_2px_concat[32*i+:16];
    assign in_px_1[i] = in_2px_concat[(32*i+16)+:16];
    
    assign q_px_0[i] = (in_px_0[i] >>> q_level) + in_px_0[15];
    assign q_px_1[i] = (in_px_1[i] >>> q_level) + in_px_0[15];
end
// -------------------------------------------------------------------------------------------------

// Write enable generation.
// -------------------------------------------------------------------------------------------------
wire wr_en;

// Writes are enabled whenever px_count_v1 changes to a value greater than or equal to zero.
reg px_count_q1_prev_LSB;
always @(posedge px_clk)
begin
    px_count_q1_prev_LSB <= px_count_q1[0];
end
assign wr_en = (px_count_q1[0] ^ px_count_q1_prev_LSB) & (px_count_q1 >= 24'sh000000);
// -------------------------------------------------------------------------------------------------

// Write state. Cycles through 8 states on px_clk_2x.
// wr_state[2:0] transitions from 7 to 0 when px_count_q1[1:0] increments from 3 to 0.
// -------------------------------------------------------------------------------------------------
wire [2:0] wr_state ;

reg px_count_q1_prev_LSB_2x;
always @(posedge px_clk_2x)
begin
    px_count_q1_prev_LSB_2x <= px_count_q1[0];
end

assign wr_state = {px_count_q1[1:0], (px_count_q1[0] == px_count_q1_prev_LSB_2x)};
// -------------------------------------------------------------------------------------------------

// Write address generation.
// -------------------------------------------------------------------------------------------------
wire [9:0] wr_addr;

// The write address is driven by px_count_q1, which is offset from px_count by the known latency
// of the first-stage wavelet stages feeding this quantizer. It distributes the eight channels'
// data into the correct position in the row.
assign wr_addr[9:3] = px_count_q1[8:2];
assign wr_addr[2:0] = wr_state;
// -------------------------------------------------------------------------------------------------

// Write data.
// -------------------------------------------------------------------------------------------------
wire [31:0] wr_data;
assign wr_data = {q_px_1[wr_state], q_px_0[wr_state]};

always @(posedge px_clk_2x)
begin
    if (wr_en)
    begin
        mem[wr_addr] <= wr_data;
    end
end
// -------------------------------------------------------------------------------------------------

// Read operation. (One clock cycle latency between updating rd_addr and latching out_4px.)
//  ------------------------------------------------------------------------------------------------
always @(posedge px_clk)
begin
    out_4px <= {mem[{rd_addr, 1'b1}], mem[{rd_addr, 1'b0}]};
end
//  ------------------------------------------------------------------------------------------------

endmodule
