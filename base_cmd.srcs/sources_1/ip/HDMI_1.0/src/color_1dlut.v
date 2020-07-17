`timescale 1 ns / 1 ps
/*
===================================================================================
color_1dlut.v

Applies independent R, G, and B color curves to the bilinear interpolation outputs
using 1D LUTs. Outputs are 14b-normalized, stored as s16. 

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

module color_1dlut
(
  input wire clk,

  input wire signed [15:0] out_G1,
  input wire signed [15:0] out_R1,
  input wire signed [15:0] out_B1,
  input wire signed [15:0] out_G2,

  input wire [63:0] lut_r_rdata,
  input wire [63:0] lut_g_rdata,
  input wire [63:0] lut_b_rdata,
  output wire [11:0] lut_r_raddr,
  output wire [11:0] lut_g_raddr,
  output wire [11:0] lut_b_raddr,
  
  output wire signed [15:0] R_14b,
  output wire signed [15:0] G_14b,
  output wire signed [15:0] B_14b
);

// Average the two green values prior to look-up.
wire signed [15:0] out_G = (out_G1 + out_G2) >>> 1;

// LUT index is the 12 LSB of each color: 10 for address and 2 for 16-bit word select.
assign lut_r_raddr = {2'b00, out_R1[11:2]};
assign lut_g_raddr = {2'b00, out_G[11:2]};
assign lut_b_raddr = {2'b00, out_B1[11:2]};
assign R_14b = lut_r_rdata[16*out_R1[1:0]+:16];
assign G_14b = lut_g_rdata[16*out_G[1:0]+:16];
assign B_14b = lut_b_rdata[16*out_B1[1:0]+:16];

endmodule
