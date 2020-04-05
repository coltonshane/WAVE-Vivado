`timescale 1 ns / 1 ps
/*
===================================================================================
idwt26_v2.v

Inverse Discrete Wavelet Transfrom 2/6 Core, Vertical Second Stage

Operates on a 16-row buffer of data from a single color field:

            |<--- 1024px --->|
            [    HL2/LL2     ] --> [I]
            [    HL2/LL2     ] --> [D]
            [    HL2/LL2     ] --> [W] --> [ H2/L2 Row 0] --> Data Out
Data In --> [ HL2/LL2 Input  ]     [T] --> [ H2/L2 Row 1] --> Data Out
                    ...            [2]
            [    HH2/LH2     ]     [/]
            [    HH2/LH2     ] --> [6] 
            [    HH2/LH2     ]
Data In --> [ HH2/LH2 Input  ]

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

module idwt26_v2
#(
  parameter PX_MATH_WIDTH = 16
)
(
  input wire SS,

  input wire opx_clk,
  input wire signed [23:0] opx_count_iv2_out,
  input wire wr_en,
  input wire [11:0] wr_addr,
  input wire [63:0] wr_data,
  
  output reg [63:0] out_4px_row0,
  output reg [63:0] out_4px_row1
);

// Memory to be inferred as a single URAM (256K = 16 x 1024 x 16b).
reg [63:0] mem [4095:0];

// Driving state from opx_count LSBs.
wire [1:0] state = opx_count_iv2_out[1:0];

// Global enable generation.
// -------------------------------------------------------------------------------------------------
// All operations enabled whenever opx_count increments.
reg opx_count_iv2_out_prev_LSB;
always @(posedge opx_clk)
begin
    opx_count_iv2_out_prev_LSB <= opx_count_iv2_out[0];
end
wire en = (opx_count_iv2_out[0] ^ opx_count_iv2_out_prev_LSB);
// -------------------------------------------------------------------------------------------------

// Read address generation (combinational).
// -------------------------------------------------------------------------------------------------
wire [11:0] rd_addr_4K;
wire [11:0] rd_addr_2K;
wire [3:0] rd_row_offset[3:0];
assign rd_row_offset[0] = 0;   // State 0: Request Row N+0 (HL2/LL2, S_above) for V2.
assign rd_row_offset[1] = 1;   // State 1: Request Row N+1 (HL2/LL2, S) for V2.
assign rd_row_offset[2] = 2;   // State 2: Request Row N+2 (HL2/LL2, S_below) for V2.
assign rd_row_offset[3] = 9;   // State 3: Request Row N+9 (HH2/LH2, D) for V2.

assign rd_addr_4K[11:8] = opx_count_iv2_out[14:11] + rd_row_offset[state];   // [14:11] scans each row twice.
assign rd_addr_4K[7:0] = opx_count_iv2_out[9:2];

assign rd_addr_2K[11:7] = opx_count_iv2_out[14:10] + rd_row_offset[state];   // [14:10] scans each row twice.
assign rd_addr_2K[6:0] = opx_count_iv2_out[8:2];

wire [11:0] rd_addr = SS ? rd_addr_2K : rd_addr_4K;
// -------------------------------------------------------------------------------------------------

// Read operation. (One clock cycle latency between updating rd_addr and latching rd_data.)
// -------------------------------------------------------------------------------------------------
reg [63:0] rd_data ;

always @(posedge opx_clk)
begin
if(en)
begin
    rd_data <= mem[rd_addr];
end
end
// -------------------------------------------------------------------------------------------------

// Read data state machine.
// -------------------------------------------------------------------------------------------------
// Read targets.
reg signed [(PX_MATH_WIDTH-1):0] S_above[3:0];
reg signed [(PX_MATH_WIDTH-1):0] S[3:0];
reg signed [(PX_MATH_WIDTH-1):0] S_below[3:0];
reg signed [15:0] D[3:0];

always @(posedge opx_clk)
begin
if(en)
begin

  case (state)
  
  2'b00: // Receive Row N+9 (HH2/LH2, D) for V2.
  begin
    D[0] <= rd_data[0+:16];
    D[1] <= rd_data[16+:16];
    D[2] <= rd_data[32+:16];
    D[3] <= rd_data[48+:16];
  end
    
  2'b01: // Receive Row N+0 (HL2/LL2, S_above) for V2.
  begin
    S_above[0] <= rd_data[0+:PX_MATH_WIDTH];
    S_above[1] <= rd_data[16+:PX_MATH_WIDTH];
    S_above[2] <= rd_data[32+:PX_MATH_WIDTH];
    S_above[3] <= rd_data[48+:PX_MATH_WIDTH];
  end
    
  2'b10: // Receive Row N+1 (HL2/LL2, S) for V2.
  begin
    S[0] <= rd_data[0+:PX_MATH_WIDTH];
    S[1] <= rd_data[16+:PX_MATH_WIDTH];
    S[2] <= rd_data[32+:PX_MATH_WIDTH];
    S[3] <= rd_data[48+:PX_MATH_WIDTH];
  end
    
  2'b11: // Receive Row N+2 (HL2/LL2, S_below) for V2.
  begin
    S_below[0] <= rd_data[0+:PX_MATH_WIDTH];
    S_below[1] <= rd_data[16+:PX_MATH_WIDTH];
    S_below[2] <= rd_data[32+:PX_MATH_WIDTH];
    S_below[3] <= rd_data[48+:PX_MATH_WIDTH];
  end
    
  endcase
      
end
end

// -------------------------------------------------------------------------------------------------

/* -------------------------------------------------------------------------------------------------
Lifting core for 2/6 IDWT in the vertical dimension (down a column) on the second stage.
For a pair of output pixels Xeven(n), Xodd(n), the 2/6 inverse DWT lifting steps are:
    1)                     D(n) = Dout(n) - ((S(n-1) - S(n+1) + 2) >>> 2)
    2)                     Xeven(n) = Sout(n) - (D(n) >>> 1)
    3)                     Xodd(n) = Xeven(n) + D(n)

Note that the register array notation may differ between modules, but in all cases the data is
processed form left to right across a row, such that:
    S(n-1) is the sum above, which arrives earlier (oldest).
    S(n+1) is the sum below, which arrives later (newest).
------------------------------------------------------------------------------------------------- */
wire signed [15:0] D2[3:0];
wire signed [15:0] Xeven[3:0];
wire signed [15:0] Xodd[3:0];

genvar i;
for (i = 0; i < 4; i = i + 1)
begin
  assign D2[i] = D[i] - ((S_above[i] - S_below[i] + 16'sh0002) >>> 2);
  assign Xeven[i] = S[i] - (D2[i] >>> 1);
  assign Xodd[i] = Xeven[i] + D2[i];
end

always @(posedge opx_clk)
begin
if(en & (state == 2'b01))
begin
  out_4px_row0 <= {Xeven[3], Xeven[2], Xeven[1], Xeven[0]};
  out_4px_row1 <= {Xodd[3], Xodd[2], Xodd[1], Xodd[0]};
end
end
// -------------------------------------------------------------------------------------------------

// Write operation, driven externally by Decompressor output distributor.
// -------------------------------------------------------------------------------------------------
always @(posedge opx_clk)
begin
if(wr_en)
  begin
    mem[wr_addr] <= wr_data;
  end
end
// -------------------------------------------------------------------------------------------------

endmodule
