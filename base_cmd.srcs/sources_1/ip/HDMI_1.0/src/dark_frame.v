`timescale 1 ns / 1 ps
/*
===================================================================================
dark_frame.v

Subtracts row and column biases from 10b-normalized color field outputs after
bilinear interpolation. The row and column addresses are driven by vxNorm and
vyNorm, which are 16b-normalized X and Y coordinates. (The full image width is
65536 and the height is defined by the aspect ratio.)

Latency of one HDMI px_clk:
1. URAM read.

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

module dark_frame
(
  input wire clk,
  
  input wire [15:0] vxNorm,
  input wire [15:0] vyNorm,
  
  input wire signed [15:0] G1_10b,
  input wire signed [15:0] R1_10b,
  input wire signed [15:0] B1_10b,
  input wire signed [15:0] G2_10b,
  
  input wire [63:0] dark_row_rdata,
  input wire [63:0] dark_col_rdata,
  output reg [11:0] dark_row_raddr,
  output reg [11:0] dark_col_raddr,
  
  output reg signed [15:0] G1_dark_10b,
  output reg signed [15:0] R1_dark_10b,
  output reg signed [15:0] B1_dark_10b,
  output reg signed [15:0] G2_dark_10b
);

// Address generation based on 4096px-wide dark frame.
always @(posedge clk)
begin
  dark_col_raddr <= vxNorm[15:4];
  dark_row_raddr <= vyNorm[15:4];
end

// Split up the dark frame row and column data into color components.
wire signed [15:0] dark_row_G1_10b = dark_row_rdata[0+:16];
wire signed [15:0] dark_row_R1_10b = dark_row_rdata[16+:16];
wire signed [15:0] dark_row_B1_10b = dark_row_rdata[32+:16];
wire signed [15:0] dark_row_G2_10b = dark_row_rdata[48+:16];
wire signed [15:0] dark_col_G1_10b = dark_col_rdata[0+:16];
wire signed [15:0] dark_col_R1_10b = dark_col_rdata[16+:16];
wire signed [15:0] dark_col_B1_10b = dark_col_rdata[32+:16];
wire signed [15:0] dark_col_G2_10b = dark_col_rdata[48+:16];

// Do the subtractions and register the results.
// Don't worry about over/underflow since the 1DLUT stage includes clipping range.
always @(posedge clk)
begin
  G1_dark_10b <= G1_10b - dark_row_G1_10b - dark_col_G1_10b;
  R1_dark_10b <= R1_10b - dark_row_R1_10b - dark_col_R1_10b;
  B1_dark_10b <= B1_10b - dark_row_B1_10b - dark_col_B1_10b;
  G2_dark_10b <= G2_10b - dark_row_G2_10b - dark_col_G2_10b;
end

endmodule
