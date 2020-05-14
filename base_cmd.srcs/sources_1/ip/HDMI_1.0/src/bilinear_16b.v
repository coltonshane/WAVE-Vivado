`timescale 1 ns / 1 ps
/*
===================================================================================
bilinear_16b.v

Performs 16b bilinear interpolation in 16b space with a 2^GRID_EXP input grid:

      x0    xOut x1
      |       |  |
  y0- o(in00) |  o(in10)      x1 = x0 + 2^GRID_EXP
              |               y1 = y0 + 2^GRID_EXP
yOut--------- o(out)
  y1- o(in01)    o(in11)

x0 and y0 are 16b unsigned coordinates of the top left input value (in00). These 
need not be on the 2^GRID_EXP grid. (For example, for mid-pixel sampling.)

xOut and yOut are 16b unsigned coordinates of the output value to be interpolated.
These need not be contained within the grid square, but interpolation outside of 
the square imposes additional limits on the range of inputs.

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

module bilinear_16b
#(
  parameter integer GRID_EXP = 6
)
(
  input wire clk,
  
  input wire [15:0] x0,
  input wire [15:0] y0,
  input wire [15:0] xOut,
  input wire [15:0] yOut,
  
  input wire signed [15:0] in00,
  input wire signed [15:0] in10,
  input wire signed [15:0] in01,
  input wire signed [15:0] in11,
  
  output reg signed [15:0] out
);

// X and Y offsets within a grid square.
// (Instantiates as two 16b adders, 32 LUTS.)
wire signed [15:0] xOffset;
assign xOffset = xOut - x0;
wire signed [15:0] yOffset;
assign yOffset = yOut - y0;

// Left-shifted input values to feed to DSP post-adder.
wire signed [(15+GRID_EXP):0] in00_add;
wire signed [(15+GRID_EXP):0] in10_add;
wire signed [(15+GRID_EXP):0] in01_add;
wire signed [(15+GRID_EXP):0] in11_add;
assign in00_add = in00 <<< GRID_EXP;
assign in10_add = in10 <<< GRID_EXP;
assign in01_add = in01 <<< GRID_EXP;
assign in11_add = in11 <<< GRID_EXP;

// Top X interpolation (combinational).
// (Instantiates as a single DSP48E2.)
wire signed [15+GRID_EXP:0] p0;
assign p0 = in00_add + (in10 - in00) * xOffset;
wire signed [15:0] t0;
assign t0 = p0 >>> GRID_EXP;

// Bottom X interpolation (combinational).
// (Instantiates as a single DSP48E2.)
wire signed [15+GRID_EXP:0] p1;
assign p1 = in01_add + (in11 - in01) * xOffset;
wire signed [15:0] t1;
assign t1 = p1 >>> GRID_EXP;

// Y interpolation (sequetial).
// (Instantiates as a single DSP48E2.)
wire signed [15+GRID_EXP:0] pOut;
assign pOut = p0 + (t1 - t0) * yOffset;
always @(posedge clk)
begin
 // out <= in00;
 out <= pOut >>> GRID_EXP;
end

endmodule