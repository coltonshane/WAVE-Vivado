`timescale 1 ns / 1 ps
/*
===================================================================================
color_1dlut.v

Applies R, G, and B color mixing curves to the bilinear interpolation outputs using 
1D LUTs. Outputs are 14b-normalized, stored as s16.

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

  input wire [63:0] lut_g1_rdata,
  input wire [63:0] lut_r1_rdata,
  input wire [63:0] lut_b1_rdata,
  input wire [63:0] lut_g2_rdata,
  output wire [11:0] lut_g1_raddr,
  output wire [11:0] lut_r1_raddr,
  output wire [11:0] lut_b1_raddr,
  output wire [11:0] lut_g2_raddr,
  
  output reg signed [15:0] R_14b,
  output reg signed [15:0] G_14b,
  output reg signed [15:0] B_14b
);

// LUT index is the 12 LSB of each color field (includes range for clipping).
assign lut_g1_raddr = out_G1[11:0];
assign lut_r1_raddr = out_R1[11:0];
assign lut_b1_raddr = out_B1[11:0];
assign lut_g2_raddr = out_G2[11:0];

// Separate out mixer channels.
wire signed [15:0] G1toR_14b = lut_g1_rdata[0+:16];
wire signed [15:0] G1toG_14b = lut_g1_rdata[16+:16];
wire signed [15:0] G1toB_14b = lut_g1_rdata[32+:16];
wire signed [15:0] R1toR_14b = lut_r1_rdata[0+:16];
wire signed [15:0] R1toG_14b = lut_r1_rdata[16+:16];
wire signed [15:0] R1toB_14b = lut_r1_rdata[32+:16];
wire signed [15:0] B1toR_14b = lut_b1_rdata[0+:16];
wire signed [15:0] B1toG_14b = lut_b1_rdata[16+:16];
wire signed [15:0] B1toB_14b = lut_b1_rdata[32+:16];
wire signed [15:0] G2toR_14b = lut_g2_rdata[0+:16];
wire signed [15:0] G2toG_14b = lut_g2_rdata[16+:16];
wire signed [15:0] G2toB_14b = lut_g2_rdata[32+:16];

// Sum the mixer channels into R, G, and B components and register these as the outputs.
// Don't worry about saturation here, since it is handled downstream.
always @(posedge clk)
begin
  R_14b <= G1toR_14b + R1toR_14b + B1toR_14b + G2toR_14b;
  G_14b <= G1toG_14b + R1toG_14b + B1toG_14b + G2toG_14b;
  B_14b <= G1toB_14b + R1toB_14b + B1toB_14b + G2toB_14b;
end

endmodule
