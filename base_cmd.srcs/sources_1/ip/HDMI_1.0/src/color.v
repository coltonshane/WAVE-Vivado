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
  input wire clk,

  input wire signed [15:0] out_G1,
  input wire signed [15:0] out_R1,
  input wire signed [15:0] out_B1,
  input wire signed [15:0] out_G2,

  input wire [63:0] lut_alpha_rdata,
  input wire [63:0] lut_beta_rdata,
  input wire [63:0] lut_gamma_rdata,
  output wire [11:0] lut_alpha_raddr,
  output wire [11:0] lut_beta_raddr,
  output wire [11:0] lut_gamma_raddr,
  
  output wire [7:0] R_8b,
  output wire [7:0] G_8b,
  output wire [7:0] B_8b
);

// {r, g, b} to {alpha, beta, gamma} with 10-bit full range and signed 16-bit storage.
wire signed [15:0] out_G = (out_G1 + out_G2) >>> 1;
wire signed [15:0] alpha;
wire signed [15:0] beta;
wire signed [15:0] gamma;
clarke clarke_inst
(
  .r(out_R1),
  .g(out_G),
  .b(out_B1),
  .alpha(alpha),
  .beta(beta),
  .gamma(gamma)
);

// LUT index is the 12 LSB of gamma: 10 for address and 2 for 16-bit word select.
assign lut_alpha_raddr = {2'b00, gamma[11:2]};
assign lut_beta_raddr = {2'b00, gamma[11:2]};
assign lut_gamma_raddr = {2'b00, gamma[11:2]};
wire signed [15:0] lut_alpha_16b = lut_alpha_rdata[16*gamma[1:0]+:16];
wire signed [15:0] lut_beta_16b = lut_beta_rdata[16*gamma[1:0]+:16];
wire signed [15:0] lut_gamma_16b = lut_gamma_rdata[16*gamma[1:0]+:16];

// One cycle delay for LUT reads.
reg signed [15:0] alpha_1;
reg signed [15:0] beta_1;
always @(posedge clk)
begin
  alpha_1 <= alpha;
  beta_1 <= beta;
end

// Apply LUT corrections.
wire signed [15:0] alphaCC = alpha_1 + lut_alpha_16b;   // White/Black Balance
wire signed [15:0] betaCC = beta_1 + lut_beta_16b;      // White/Black Balance
wire signed [15:0] gammaCC = lut_gamma_16b;             // Gamma, Brightness, Contrast

// {alpha, beta, gamma} to {r, g, b} with 10-bit full range and signed 16-bit storage. 
wire signed [15:0] rCC;
wire signed [15:0] gCC;
wire signed [15:0] bCC;
clarke_inv clarke_inv_inst
(
  .alpha(alphaCC),
  .beta(betaCC),
  .gamma(gammaCC),
  .r(rCC),
  .g(gCC),
  .b(bCC)
);

// Assign 8-bit outputs with saturation.
assign R_8b = rCC[15] ? 8'h00 : ((rCC[14:10] == 5'b00000) ? rCC[9:2] : 8'hFF);
assign G_8b = gCC[15] ? 8'h00 : ((gCC[14:10] == 5'b00000) ? gCC[9:2] : 8'hFF);
assign B_8b = bCC[15] ? 8'h00 : ((bCC[14:10] == 5'b00000) ? bCC[9:2] : 8'hFF);

endmodule
