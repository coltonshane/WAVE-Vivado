`timescale 1ns / 1ps
/*
=================================================================================
lvds_clk_out.v

Output buffer for LVDS clock.

Copyright (C) 2019 by Shane W. Colton

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
=================================================================================
*/

module lvds_clk_out(
  input lvds_clk_en,
  input lvds_pll_locked,
  input pll2lvds_clk,
  output lvds_clk_out_p,
  output lvds_clk_out_n
  );
  
  wire clk_out;
  wire oddr_en;

  assign oddr_en = lvds_clk_en & lvds_pll_locked;
  
  ODDRE1 ODDRE1_inst (
    .Q(clk_out),        // 1-bit output: Data output to IOB
    .C(pll2lvds_clk),   // 1-bit input: High-speed clock input
    .D1(1'b0),          // 1-bit input: Parallel data input 1
    .D2(oddr_en),       // 1-bit input: Parallel data input 2
    .SR(1'b0)           // 1-bit input: Active High Async Reset
  );
  
  OBUFDS OBUFDS_inst (
      .O(lvds_clk_out_p),   // 1-bit output: Diff_p output (connect directly to top-level port)
      .OB(lvds_clk_out_n),  // 1-bit output: Diff_n output (connect directly to top-level port)
      .I(clk_out)           // 1-bit input: Buffer input
   );
    
endmodule
