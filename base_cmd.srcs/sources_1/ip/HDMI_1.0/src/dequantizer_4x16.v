`timescale 1ns / 1ps
/*
=================================================================================
dequantizer_4x16.v

Recovers the full range of four quantized 16-bit signed values by multiplying by 
a value in the range 256-65536, inclusive, then dividing by 256 and rounding 
toward zero. This is done using a DSP48E2 primative for each 16-bit value (4 
total).

The DSP48E2s include registered outputs that update on px_clk if q_en is high.
The four results are presented as a concatenated 64-bit output.

This module should infer as 4 DSP48E2s only, with no FF or LUT.
=================================================================================
*/

module dequantizer_4x16
(
    input wire opx_clk,
    input wire en,
    input wire signed [17:0] q_mult_inv,
    input wire [63:0] q_4px,
    output reg[63:0] out_4px
);

genvar i;

// Signed views of each pixel of the concatenated input / output.
wire signed [15:0] q_px[3:0];
wire signed [15:0] out_px[3:0];

// Signed views of intermediate values for DSP48E2 operation.
wire signed [8:0] offset[3:0];
wire signed [35:0] product[3:0];  // Minimum width: 16 (q_px) + 18 (q_mult_inv) = 34.

// Parallel (A*B + C) DSP operation for each pixel. Note: All operands must be signed!
// The C value (offset[i]) is used to round negative numbers toward zero.
for(i = 0; i < 4; i = i + 1)
begin
    assign q_px[i] = q_4px[16*i+:16];
    assign offset[i] = {1'b0, {8{q_px[i][15]}}};
    assign product[i] = (q_px[i] * q_mult_inv + offset[i]);
    assign out_px[i] = product[i][23:8];
end

// Sequential logic to register the results.
always @(posedge opx_clk)
begin
if (en)
begin
    out_4px <= {out_px[3], out_px[2], out_px[1], out_px[0]};
end
end

endmodule
