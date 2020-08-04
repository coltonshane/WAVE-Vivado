`timescale 1 ns / 1 ps
/*
===================================================================================
color_1dlut.v

Applies R, G, and B color mixing curves to the bilinear interpolation outputs using 
1D LUTs. Outputs are 14b-normalized, stored as s16.

Latency of two HDMI px_clk:
1. URAM read for RGB Mixer 1DLUTs.
2. URAM read for RGB Curve 1DLUTs.

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

  input wire signed [15:0] G1_10b,
  input wire signed [15:0] R1_10b,
  input wire signed [15:0] B1_10b,
  input wire signed [15:0] G2_10b,

  input wire [63:0] lut_g1_rdata,
  input wire [63:0] lut_r1_rdata,
  input wire [63:0] lut_b1_rdata,
  input wire [63:0] lut_g2_rdata,
  input wire [63:0] lut_r_rdata,
  input wire [63:0] lut_g_rdata,
  input wire [63:0] lut_b_rdata,
  output reg [11:0] lut_g1_raddr,
  output reg [11:0] lut_r1_raddr,
  output reg [11:0] lut_b1_raddr,
  output reg [11:0] lut_g2_raddr,
  output reg [11:0] lut_r_raddr,
  output reg [11:0] lut_g_raddr,
  output reg [11:0] lut_b_raddr,
  
  output reg signed [15:0] R_14b,
  output reg signed [15:0] G_14b,
  output reg signed [15:0] B_14b
);

// RGB Mixer LUT address is the 12 LSB of each color field (includes range for clipping).
always @(posedge clk)
begin
  lut_g1_raddr <= G1_10b[11:0];
  lut_r1_raddr <= R1_10b[11:0];
  lut_b1_raddr <= B1_10b[11:0];
  lut_g2_raddr <= G2_10b[11:0];
end

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

// Sum the mixer channels into R, G, and B components and register these (first clock).
reg signed [15:0] R_linear_14b;
reg signed [15:0] G_linear_14b;
reg signed [15:0] B_linear_14b;
always @(posedge clk)
begin
  R_linear_14b <= G1toR_14b + R1toR_14b + B1toR_14b + G2toR_14b;
  G_linear_14b <= G1toG_14b + R1toG_14b + B1toG_14b + G2toG_14b;
  B_linear_14b <= G1toB_14b + R1toB_14b + B1toB_14b + G2toB_14b;
end

// Saturate at 14b (combinational).
wire signed [15:0] R_linear_sat_14b = R_linear_14b[15] ? 16'sh0000 : (R_linear_14b[14] ? 16'sh3FFF : R_linear_14b[13:0]);
wire signed [15:0] G_linear_sat_14b = G_linear_14b[15] ? 16'sh0000 : (G_linear_14b[14] ? 16'sh3FFF : G_linear_14b[13:0]);
wire signed [15:0] B_linear_sat_14b = B_linear_14b[15] ? 16'sh0000 : (B_linear_14b[14] ? 16'sh3FFF : B_linear_14b[13:0]);

// RGB Curve LUT address is the 12 MSB of the saturated 14b-normalized color.
always @(posedge clk)
begin
  lut_r_raddr <= R_linear_sat_14b[13:2];
  lut_g_raddr <= G_linear_sat_14b[13:2];
  lut_b_raddr <= B_linear_sat_14b[13:2];
end

// The bottom two LSB of the saturated 14b-normalized color are the word-select within the RGB Curve LUT data.
// Select the 14b output from the RGB Curve LUT and register it as the output (second clock).
always @(posedge clk)
begin
  R_14b <= lut_r_rdata[16*R_linear_sat_14b[1:0]+:16];
  G_14b <= lut_g_rdata[16*G_linear_sat_14b[1:0]+:16];
  B_14b <= lut_b_rdata[16*B_linear_sat_14b[1:0]+:16];
end

endmodule
