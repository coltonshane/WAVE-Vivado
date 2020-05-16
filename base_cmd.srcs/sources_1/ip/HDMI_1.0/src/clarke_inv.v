`timescale 1 ns / 1 ps
/*
===================================================================================
clarke_inv.v

Transforms {alpha, beta, gamma} to {r, g, b} using the inverse Clarke transform:

[g]   [       2/2         0/2         2/2] [alpha]
[b] = [      -1/2   sqrt(3)/2         2/2] [ beta]
[r]   [      -1/2  -sqrt(3)/2         2/2] [gamma]

- All operands and results are 16-bit signed.
- Combinational.
- Instantiates as one DSPs and 16 LUTs.

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


module clarke_inv
(
  input wire signed [15:0] alpha,
  input wire signed [15:0] beta,
  input wire signed [15:0] gamma,
  output wire signed [15:0] r,
  output wire signed [15:0] g,
  output wire signed [15:0] b
);

// Beta DSP: P = (D - A) * B
wire signed [29:0] betaA = 29'sd0;
wire signed [17:0] betaB = 17'sd56756;
wire signed [47:0] betaC = 47'sd0;
wire signed [26:0] betaD = beta;
wire signed [47:0] betaP;
DSP48E2 
#(
  // Feature Control Attributes: Data Path Selection
  .AMULTSEL("AD"),                   // Selects A input to multiplier (A, AD)
  .A_INPUT("DIRECT"),                // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
  .BMULTSEL("B"),                    // Selects B input to multiplier (AD, B)
  .B_INPUT("DIRECT"),                // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
  .PREADDINSEL("A"),                 // Selects input to pre-adder (A, B)
  .RND(48'h000000000000),            // Rounding Constant
  .USE_MULT("MULTIPLY"),             // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
  .USE_SIMD("ONE48"),                // SIMD selection (FOUR12, ONE48, TWO24)
  .USE_WIDEXOR("FALSE"),             // Use the Wide XOR function (FALSE, TRUE)
  .XORSIMD("XOR24_48_96"),           // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
  // Pattern Detector Attributes: Pattern Detection Configuration
  .AUTORESET_PATDET("NO_RESET"),     // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
  .AUTORESET_PRIORITY("RESET"),      // Priority of AUTORESET vs. CEP (CEP, RESET).
  .MASK(48'h000000000000),           // 48-bit mask value for pattern detect (1=ignore)
  .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
  .SEL_MASK("MASK"),                 // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
  .SEL_PATTERN("PATTERN"),           // Select pattern value (C, PATTERN)
  .USE_PATTERN_DETECT("NO_PATDET"),  // Enable pattern detect (NO_PATDET, PATDET)
  // Register Control Attributes: Pipeline Register Configuration
  .ACASCREG(0),                      // Number of pipeline stages between A/ACIN and ACOUT (0-2)
  .ADREG(0),                         // Pipeline stages for pre-adder (0-1)
  .ALUMODEREG(0),                    // Pipeline stages for ALUMODE (0-1)
  .AREG(0),                          // Pipeline stages for A (0-2)
  .BCASCREG(0),                      // Number of pipeline stages between B/BCIN and BCOUT (0-2)
  .BREG(0),                          // Pipeline stages for B (0-2)
  .CARRYINREG(0),                    // Pipeline stages for CARRYIN (0-1)
  .CARRYINSELREG(0),                 // Pipeline stages for CARRYINSEL (0-1)
  .CREG(0),                          // Pipeline stages for C (0-1)
  .DREG(0),                          // Pipeline stages for D (0-1)
  .INMODEREG(0),                     // Pipeline stages for INMODE (0-1)
  .MREG(0),                          // Multiplier pipeline stages (0-1)
  .OPMODEREG(0),                     // Pipeline stages for OPMODE (0-1)
  .PREG(0)                           // Number of pipeline stages for P (0-1)
)
DSP48E2_beta
(
  // Control outputs: Control Inputs/Status Bits
  .PATTERNDETECT(),                // 1-bit output: Pattern detect
  // Data outputs: Data Ports
  .P(betaP),                       // 48-bit output: Primary data
  // Control inputs: Control Inputs/Status Bits
  .ALUMODE(4'b0000),               // 4-bit input: ALU control
  .CLK(),                          // 1-bit input: Clock
  .INMODE(5'b01100),               // 5-bit input: INMODE control
  .OPMODE(9'b000110101),           // 9-bit input: Operation mode
  // Data inputs: Data Ports
  .A(betaA),                       // 30-bit input: A data
  .B(betaB),                       // 18-bit input: B data
  .C(betaC),                       // 48-bit input: C data
  .D(betaD),                       // 27-bit input: D data
  // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
  .CEP(1'b1)                       // Output enable.
);

wire signed [15:0] alpha_over_2 = (alpha >>> 1); 

assign g = alpha + gamma;
assign b = -alpha_over_2 + betaP[31:16] + gamma;
assign r = -alpha_over_2 - betaP[31:16] + gamma;

endmodule
