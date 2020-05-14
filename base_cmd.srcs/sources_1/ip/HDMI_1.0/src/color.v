`timescale 1 ns / 1 ps
/*
===================================================================================
color.v

Applies color correction to the bilinear interpolation outputs and scales them
to 8-bit RGB to pass to the UI mixer. Latency of one HDMI px_clk.

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

module color
(
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
  
  output wire [7:0] R_8b,
  output wire [7:0] G_8b,
  output wire [7:0] B_8b
);

wire [11:0] R_12b = out_R1;
wire [11:0] G_12b = (out_G1 + out_G2) >> 1;
wire [11:0] B_12b = out_B1;

// Address generation.
assign lut_r_raddr = {3'b000, R_12b[11:3]};
assign lut_g_raddr = {3'b000, G_12b[11:3]};
assign lut_b_raddr = {3'b000, B_12b[11:3]};

// Data byte selection.
assign R_8b = lut_r_rdata[8*R_12b[2:0]+:8];
assign G_8b = lut_g_rdata[8*G_12b[2:0]+:8]; 
assign B_8b = lut_b_rdata[8*B_12b[2:0]+:8]; 

endmodule
