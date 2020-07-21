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

Latency of three HDMI px_clk:
1. URAM read.
2. Multiplies.
3. Output sum and saturation.

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
  
  output reg [7:0] R_8b,
  output reg [7:0] G_8b,
  output reg [7:0] B_8b
);

// Generate shared 3DLUT address using input colors w/ saturation logic.
wire [3:0] addrR = (R_14b[15] == 1'b1) ? 4'h0 : ((R_14b[14] == 1'b1) ? 4'hF : R_14b[13:10]);
wire [3:0] addrG = (G_14b[15] == 1'b1) ? 4'h0 : ((G_14b[14] == 1'b1) ? 4'hF : G_14b[13:10]);
wire [3:0] addrB = (B_14b[15] == 1'b1) ? 4'h0 : ((B_14b[14] == 1'b1) ? 4'hF : B_14b[13:10]);
assign lut3d_c30_r_raddr = {addrB, addrG, addrR};
assign lut3d_c74_r_raddr = {addrB, addrG, addrR};
assign lut3d_c30_g_raddr = {addrB, addrG, addrR};
assign lut3d_c74_g_raddr = {addrB, addrG, addrR};
assign lut3d_c30_b_raddr = {addrB, addrG, addrR};
assign lut3d_c74_b_raddr = {addrB, addrG, addrR};

// Register the  LUT3D coefficients and color remainders on the same clock edge.
// TO-DO: This pipeline stage could probably be omitted to save these FFs.
reg signed [15:0] cR_10b [7:0];
reg signed [15:0] cG_10b [7:0];
reg signed [15:0] cB_10b [7:0];
reg signed [15:0] dR_14b;
reg signed [15:0] dG_14b;
reg signed [15:0] dB_14b;
always @(posedge clk)
begin : reg_LUT3D
  integer i;
  
  // Separate out the interpolation coefficients.
  for(i = 0; i < 4; i = i + 1)
  begin
    cR_10b[i] <= lut3d_c30_r_rdata[16*i+:16];
    cR_10b[4+i] <= lut3d_c74_r_rdata[16*i+:16];
    cG_10b[i] <= lut3d_c30_g_rdata[16*i+:16];
    cG_10b[4+i] <= lut3d_c74_g_rdata[16*i+:16];
    cB_10b[i] <= lut3d_c30_b_rdata[16*i+:16];
    cB_10b[4+i] <= lut3d_c74_b_rdata[16*i+:16];
  end
  
  // Calculate the remainder of each color. This is almost the same as X_14b[9:0], but needs
  // to account for potentially saturated inputs.
  dR_14b <= R_14b - $signed({2'b00, addrR, 10'b0000000000});
  dG_14b <= G_14b - $signed({2'b00, addrG, 10'b0000000000});
  dB_14b <= B_14b - $signed({2'b00, addrB, 10'b0000000000});
end : reg_LUT3D

// First-Stage Multiplies (15 DSPs, Combinational)
// Common
wire signed [15:0] dBdR_14b = (dB_14b * dR_14b) >>> 14;
wire signed [15:0] dRdG_14b = (dR_14b * dG_14b) >>> 14;
wire signed [15:0] dGdB_14b = (dG_14b * dB_14b) >>> 14;
// R
wire signed [31:0] cR1dB_24b = cR_10b[1] * dB_14b;
wire signed [31:0] cR2dR_24b = cR_10b[2] * dR_14b;
wire signed [31:0] cR3dG_24b = cR_10b[3] * dG_14b;
wire signed [15:0] cR7dR_14b = (cR_10b[7] * dR_14b) >>> 10;
// G
wire signed [31:0] cG1dB_24b = cG_10b[1] * dB_14b;
wire signed [31:0] cG2dR_24b = cG_10b[2] * dR_14b;
wire signed [31:0] cG3dG_24b = cG_10b[3] * dG_14b;
wire signed [15:0] cG7dR_14b = (cG_10b[7] * dR_14b) >>> 10;
// B
wire signed [31:0] cB1dB_24b = cB_10b[1] * dB_14b;
wire signed [31:0] cB2dR_24b = cB_10b[2] * dR_14b;
wire signed [31:0] cB3dG_24b = cB_10b[3] * dG_14b;
wire signed [15:0] cB7dR_14b = (cB_10b[7] * dR_14b) >>> 10;

// Second-Stage Multiplies (12 DSPs, Sequential)
reg signed [15:0] pR_14b [3:0];
reg signed [15:0] pG_14b [3:0];
reg signed [15:0] pB_14b [3:0];
always @(posedge clk)
begin
  // R
  pR_14b[0] <= (cR_10b[4] * dBdR_14b + cR1dB_24b) >>> 10;
  pR_14b[1] <= (cR_10b[5] * dRdG_14b + cR2dR_24b) >>> 10;
  pR_14b[2] <= (cR_10b[6] * dGdB_14b + cR3dG_24b) >>> 10;
  pR_14b[3] <= (cR7dR_14b * dGdB_14b + $signed({cR_10b[0], 14'b00000000000000})) >>> 14;
  // G
  pG_14b[0] <= (cG_10b[4] * dBdR_14b + cG1dB_24b) >>> 10;
  pG_14b[1] <= (cG_10b[5] * dRdG_14b + cG2dR_24b) >>> 10;
  pG_14b[2] <= (cG_10b[6] * dGdB_14b + cG3dG_24b) >>> 10;
  pG_14b[3] <= (cG7dR_14b * dGdB_14b + $signed({cG_10b[0], 14'b00000000000000})) >>> 14;
  // B
  pB_14b[0] <= (cB_10b[4] * dBdR_14b + cB1dB_24b) >>> 10;
  pB_14b[1] <= (cB_10b[5] * dRdG_14b + cB2dR_24b) >>> 10;
  pB_14b[2] <= (cB_10b[6] * dGdB_14b + cB3dG_24b) >>> 10;
  pB_14b[3] <= (cB7dR_14b * dGdB_14b + $signed({cB_10b[0], 14'b00000000000000})) >>> 14;
end

// Output Summer w/ Saturation (Sequential)
wire signed [15:0] sR_14b = pR_14b[0] + pR_14b[1] + pR_14b[2] + pR_14b[3];
wire signed [15:0] sG_14b = pG_14b[0] + pG_14b[1] + pG_14b[2] + pG_14b[3];
wire signed [15:0] sB_14b = pB_14b[0] + pB_14b[1] + pB_14b[2] + pB_14b[3];
always @(posedge clk)
begin
  R_8b <= (sR_14b[15] == 1'b1) ? 8'h00 : ((sR_14b[14] == 1'b1) ? 8'hFF : sR_14b[13:6]);
  G_8b <= (sG_14b[15] == 1'b1) ? 8'h00 : ((sG_14b[14] == 1'b1) ? 8'hFF : sG_14b[13:6]);
  B_8b <= (sB_14b[15] == 1'b1) ? 8'h00 : ((sB_14b[14] == 1'b1) ? 8'hFF : sB_14b[13:6]);
end

endmodule
