`timescale 1 ns / 1 ps
/*
===================================================================================
color_3dlut.v

Applies a 17x17x17 3DLUT to the RGB values using trilinear interpolation, with
pre-computed interpolation coefficients for each subcubed stored in URAMs.

Inputs are 14b-normalized RGB values stored as s16.
Interpolation coefficients are 14b-normalized values stored as s16.
Outputs are 8b-normalized RGB values stored as u8. This module handles output
saturation during the final scaling operation.

Latency of one HDMI two px_clk:
1. URAM read.
2. Multiplies.

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

module color_3dlut
(
  input wire clk,

  input wire signed [15:0] R_14b,
  input wire signed [15:0] G_14b,
  input wire signed [15:0] B_14b,

  input wire [63:0] lut3d_c30_r_rdata,
  input wire [63:0] lut3d_c74_r_rdata,
  input wire [63:0] lut3d_c30_g_rdata,
  input wire [63:0] lut3d_c74_g_rdata,
  input wire [63:0] lut3d_c30_b_rdata,
  input wire [63:0] lut3d_c74_b_rdata,
  output wire [11:0] lut3d_c30_r_raddr,
  output wire [11:0] lut3d_c74_r_raddr,
  output wire [11:0] lut3d_c30_g_raddr,
  output wire [11:0] lut3d_c74_g_raddr,
  output wire [11:0] lut3d_c30_b_raddr,
  output wire [11:0] lut3d_c74_b_raddr,
  
  output wire [15:0] R_8b,
  output wire [15:0] G_8b,
  output wire [15:0] B_8b
);

endmodule
