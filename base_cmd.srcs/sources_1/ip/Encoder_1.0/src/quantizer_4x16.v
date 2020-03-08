`timescale 1ns / 1ps
/*
=================================================================================
quantizer_4x16.v

Increases quantization of four 16-bit signed values by multiplying by a value
in the range 0-256, inclusive, then dividing by 256 and rounding toward zero. 
This is done using a DSP48E2 primative for each 16-bit value (4 total).

The DSP48E2s include registered outputs that update on px_clk if q_en is high.
The four results are presented as a concatenated 64-bit output.

This module should infer as 4 DSP48E2s only, with no FF or LUT.
=================================================================================
*/

module quantizer_4x16
(
    input wire px_clk,
    input wire signed [9:0] q_mult,
    input wire [63:0] in_4px_concat,
    output reg[63:0] q_4px_concat
);

genvar i;

// Signed views of each pixel of the concatenated input / output.
wire signed [15:0] in_px[3:0];
wire signed [15:0] q_px[3:0];

// Signed views of intermediate values for DSP48E2 operation.
wire signed [8:0] offset[3:0];
wire signed [31:0] product[3:0];

// Parallel (A*B + C) DSP operation for each pixel. Note: All operands must be signed!
// The C value (offset[i]) is used to round negative numbers toward zero.
for(i = 0; i < 4; i = i + 1)
begin
    assign in_px[i] = in_4px_concat[16*i+:16];
    assign offset[i] = {1'b0, {8{in_px[i][15]}}};
    assign product[i] = (in_px[i] * q_mult + offset[i]);
    assign q_px[i] = product[i][23:8];
end

// Sequential logic to register the results.
always @(posedge px_clk)
begin
    q_4px_concat <= {q_px[3], q_px[2], q_px[1], q_px[0]};
end

endmodule
