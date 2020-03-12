`timescale 1 ns / 1 ps
/*
===================================================================================
viewport_normalize.v

Converts input coordinate (vx, vy) in HDMI output screen space (w x 1125) to 
output coordinate (vxNorm, vyNorm) in 2^16-wide normalized image space.

Input coordinate (vx0, vy0) is the viewport origin in HDMI output screen space
(w x 1125). By the standard, the 1920x1080 visible region begins at (192,41).

vxDiv scales the viewport width to a 2^24-wide normalized intermediate image
space. vyDiv = vxDiv preserves the aspect ratio.

The module should instantiate as two DSP48E2s, one for each axis, and a single
LUT to combine the inViewport pattern detect signals.

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

module viewport_normalize
(
  input wire clk,
  
  input wire [10:0] hImage2048,

  input wire [15:0] vx0,
  input wire [15:0] vy0,
  input wire [15:0] vxDiv,
  input wire [15:0] vyDiv,
  
  input wire [15:0] vx,
  input wire [15:0] vy,
 
  output wire [15:0] vxNorm,
  output wire signed [16:0] vyNorm,
  
  output wire inViewport
);

// Explicit signed types for DSP signals.
wire signed [29:0] xA = vx0;
wire signed [17:0] xB = vxDiv;
wire signed [47:0] xC = vxDiv >> 1;
wire signed [26:0] xD = vx;
wire signed [47:0] xP;
wire xPATDET;

wire signed [29:0] yA = vy0;
wire signed [17:0] yB = vyDiv;
wire signed [47:0] yC = vyDiv >> 1;
wire signed [26:0] yD = vy;
wire signed [47:0] yP;
wire yPATDET;

// Outputs.
assign vxNorm = xPATDET ? xP[23:8] : 16'hFFFF;
assign vyNorm = yP[24:8];
assign inViewport = xPATDET & yPATDET & (vyNorm[15:5] < hImage2048);

// X DSP
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
  .MASK(48'h000000ffffff),           // 48-bit mask value for pattern detect (1=ignore)
  .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
  .SEL_MASK("MASK"),                 // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
  .SEL_PATTERN("PATTERN"),           // Select pattern value (C, PATTERN)
  .USE_PATTERN_DETECT("PATDET"),     // Enable pattern detect (NO_PATDET, PATDET)
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
  .PREG(1)                           // Number of pipeline stages for P (0-1)
)
DSP48E2_X
(
  // Control outputs: Control Inputs/Status Bits
  .PATTERNDETECT(xPATDET),          // 1-bit output: Pattern detect
  // Data outputs: Data Ports
  .P(xP),                          // 48-bit output: Primary data
  // Control inputs: Control Inputs/Status Bits
  .ALUMODE(4'b0000),               // 4-bit input: ALU control
  .CLK(clk),                       // 1-bit input: Clock
  .INMODE(5'b01100),               // 5-bit input: INMODE control
  .OPMODE(9'b000110101),           // 9-bit input: Operation mode
  // Data inputs: Data Ports
  .A(xA),                          // 30-bit input: A data
  .B(xB),                          // 18-bit input: B data
  .C(xC),                          // 48-bit input: C data
  .D(xD),                          // 27-bit input: D data
  // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
  .CEP(1'b1)                       // Output enable.
);

// Y DSP
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
  .MASK(48'h000000ffffff),           // 48-bit mask value for pattern detect (1=ignore)
  .PATTERN(48'h000000000000),        // 48-bit pattern match for pattern detect
  .SEL_MASK("MASK"),                 // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
  .SEL_PATTERN("PATTERN"),           // Select pattern value (C, PATTERN)
  .USE_PATTERN_DETECT("PATDET"),     // Enable pattern detect (NO_PATDET, PATDET)
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
  .PREG(1)                           // Number of pipeline stages for P (0-1)
)
DSP48E2_Y
(
  // Control outputs: Control Inputs/Status Bits
  .PATTERNDETECT(yPATDET),          // 1-bit output: Pattern detect
  // Data outputs: Data Ports
  .P(yP),                          // 48-bit output: Primary data
  // Control inputs: Control Inputs/Status Bits
  .ALUMODE(4'b0000),               // 4-bit input: ALU control
  .CLK(clk),                       // 1-bit input: Clock
  .INMODE(5'b01100),               // 5-bit input: INMODE control
  .OPMODE(9'b000110101),           // 9-bit input: Operation mode
  // Data inputs: Data Ports
  .A(yA),                          // 30-bit input: A data
  .B(yB),                          // 18-bit input: B data
  .C(yC),                          // 48-bit input: C data
  .D(yD),                          // 27-bit input: D data
  // Reset/Clock Enable inputs: Reset/Clock Enable Inputs
  .CEP(1'b1)                       // Output enable.
);

endmodule
