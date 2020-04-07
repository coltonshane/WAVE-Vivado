`timescale 1 ns / 1 ps
/*
===================================================================================
idwt26_h2.v

Inverse Discrete Wavelet Transfrom 2/6 Core, Horizontal Second Stage

Operates on a 16-row buffer of data from a single color field:

            |<--- 1024px --->|
            [ Recovered LL1  ] --> Data Out
            [ Recovered LL1  ] --> Data Out
            [ LL1 from IDWT  ] <-- [IDWT]
            [ H2/L2 to IDWT  ] --> [2/6 ]
            [ H2/L2 Input    ]
            [ H2/L2 Input    ]         
Data In --> [ H2/L2 Input    ]
Data In --> [ H2/L2 Input    ]

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
===================================================================================
*/

module idwt26_h2
(
  input wire SS,

  input wire opx_clk,
  input wire signed [23:0] opx_count,
  input wire [63:0] in_4px_row0,
  input wire [63:0] in_4px_row1,
  
  output wire [31:0] out_2px_row0,
  output wire [31:0] out_2px_row1
);

// Memory to be inferred as a single URAM (256K = 16 x 1024 x 16b).
reg [63:0] mem [4095:0];

// Driving state from opx_count LSBs.
wire [1:0] state = opx_count[1:0];

// Offset pixel counter to accommodate for output shift latency from the time a read address is set
// (via the pixel counter) to the time that pixel pair is available at the output.
wire signed [23:0] opx_count_ih2_rd;
assign opx_count_ih2_rd = opx_count + 24'sh4;

wire signed [23:0] opx_count_ih2_wr;
assign opx_count_ih2_wr = opx_count - 24'sh4;

// Global enable generation.
// -------------------------------------------------------------------------------------------------
// All operations enabled whenever opx_count increments.
reg opx_count_prev_LSB;
always @(posedge opx_clk)
begin
    opx_count_prev_LSB <= opx_count[0];
end
wire en = (opx_count[0] ^ opx_count_prev_LSB);
// -------------------------------------------------------------------------------------------------

// Read address generation (combinational).
// -------------------------------------------------------------------------------------------------
wire [11:0] rd_addr_4K;
wire [11:0] rd_addr_2K;
wire [3:0] rd_row_offset[3:0];
assign rd_row_offset[0] = 3;   // State 0: Request Row N+3 for H2.
assign rd_row_offset[1] = 0;   // State 1: Request Row N+0 for Output.
assign rd_row_offset[2] = 1;   // State 2: Request Row N+1 for Output.
assign rd_row_offset[3] = 3;   // State 3: Unused.

assign rd_addr_4K[11:8] = opx_count_ih2_rd[13:10] + rd_row_offset[state];
assign rd_addr_4K[7:0] = opx_count_ih2_rd[9:2];

assign rd_addr_2K[11:7] = opx_count_ih2_rd[13:9] + {1'b0, rd_row_offset[state]};
assign rd_addr_2K[6:0] = opx_count_ih2_rd[8:2];

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
// Read target pipelines.
reg [15:0] out_px_row0 [5:0];   // Output Row 0 Pipeline, 5 -> 0.
reg [15:0] out_px_row1 [4:0];   // Output Row 1 Pipeline, 4 -> 0.
reg signed [15:0] S[3:0];       // H2 Sum Pipeline, 3 -> 0.
reg signed [15:0] D[3:0];       // H2 Diff Pipeline, 3 -> 0.

always @(posedge opx_clk)
begin
if(en)
begin

   // Default shifts for Output pipeline.
  out_px_row0[4] <= out_px_row0[5];
  begin : output_shifts
    integer i;
    for(i = 0; i < 4; i = i + 1)
    begin
      out_px_row0[i] <= out_px_row0[i+1];
      out_px_row1[i] <= out_px_row1[i+1];
    end
  end : output_shifts
  
  // Default shifts for H2 pipeline.
  // H2 runs at half speed, only on odd states.
  if (state[0])
  begin : h2_shifts
    integer i;
    for(i = 0; i < 3; i = i + 1)
    begin
      S[i] <= S[i+1];
      D[i] <= D[i+1];
    end
  end : h2_shifts

  // State-dependent shift overrides.
  case (state)
  
  2'b00: // Unused, no read.
  begin
  end
    
  2'b01: // Receive Row N+3 for H2.
  begin
    S[2] <= rd_data[0+:16];
    D[2] <= rd_data[16+:16];
    S[3] <= rd_data[32+:16];
    D[3] <= rd_data[48+:16];
  end
    
  2'b10: // Receive Row N+0 for Output.
  begin
    out_px_row0[2] <= rd_data[0+:16];
    out_px_row0[3] <= rd_data[16+:16];
    out_px_row0[4] <= rd_data[32+:16];
    out_px_row0[5] <= rd_data[48+:16];
  end
    
  2'b11: // Receive Row N+1 for Output.
  begin
    out_px_row1[1] <= rd_data[0+:16];
    out_px_row1[2] <= rd_data[16+:16];
    out_px_row1[3] <= rd_data[32+:16];
    out_px_row1[4] <= rd_data[48+:16];
  end
    
  endcase
      
end
end

assign out_2px_row0 = {out_px_row0[1], out_px_row0[0]};
assign out_2px_row1 = {out_px_row1[1], out_px_row1[0]};
// -------------------------------------------------------------------------------------------------

/* -------------------------------------------------------------------------------------------------
Lifting core for 2/6 IDWT in the horizontal dimension (across a row) on the second stage.
For a pair of output pixels Xeven(n), Xodd(n), the 2/6 inverse DWT lifting steps are:
    1)                     D(n) = Dout(n) - ((S(n-1) - S(n+1) + 2) >>> 2)
    2)                     Xeven(n) = Sout(n) - (D(n) >>> 1)
    3)                     Xodd(n) = Xeven(n) + D(n)

Note that the register array notation may differ between modules, but in all cases the data is
processed form left to right across a row, such that:
    S(n-1) is the sum to the left, which arrives earlier (oldest).
    S(n+1) is the sum to the right, which arrives later (newest).
------------------------------------------------------------------------------------------------- */
wire signed [15:0] D2 = D[1] - ((S[0] - S[2] + 16'sh0002) >>> 2);
wire signed [15:0] Xeven = S[1] - (D2 >>> 1);
wire signed [15:0] Xodd = Xeven + D2;

reg signed [15:0] XevenP [1:0]; // Even pixel pipeline, 1->0.
reg signed [15:0] XoddP [1:0];  // Odd pixel pipeline, 1->0.

always @(posedge opx_clk)
begin
if(en & state[0]) // Half speed, only runs on odd states.
begin
  XevenP[1] <= Xeven;
  XoddP[1] <= Xodd;
  XevenP[0] <= XevenP[1];
  XoddP[0] <= XoddP[1];
end
end
// -------------------------------------------------------------------------------------------------

// Write address generation (combinational).
// -------------------------------------------------------------------------------------------------
wire [11:0] wr_addr_4K;
wire [11:0] wr_addr_2K;
wire [3:0] wr_row_offset[3:0];
assign wr_row_offset[0] = 2;   // State 0: Write IDWT H2 output to Row N+2.
assign wr_row_offset[1] = 6;   // State 1: Write data from IDWT V2 output to Row N+6.
assign wr_row_offset[2] = 6;   // State 2: Unused, leave unchnaged.
assign wr_row_offset[3] = 6;   // State 3: Unused, leave unchnaged.

assign wr_addr_4K[11:8] = opx_count_ih2_wr[13:10] + wr_row_offset[state];
assign wr_addr_4K[7:0] = opx_count_ih2_wr[9:2];

assign wr_addr_2K[11:7] = opx_count_ih2_wr[13:9] + {1'b0, wr_row_offset[state]};
assign wr_addr_2K[6:0] = opx_count_ih2_wr[8:2];

wire [11:0] wr_addr = SS ? wr_addr_2K : wr_addr_4K;
// -------------------------------------------------------------------------------------------------

// Write operation.
// -------------------------------------------------------------------------------------------------
wire wr_odd_row = SS ? opx_count_ih2_wr[9] : opx_count_ih2_wr[10];
always @(posedge opx_clk)
begin
if(en)
begin

  case (state)
  
  2'b00:
  begin
    mem[wr_addr] <= {XoddP[1], XevenP[1], XoddP[0], XevenP[0]};
  end
  
  2'b01:
  begin
    if(wr_odd_row)
    begin // Write odd row from IDWT V2 output.
      mem[wr_addr] <= in_4px_row1;
    end
    else
    begin // Write even row IDWT V2 OUTPUT.
      mem[wr_addr] <= in_4px_row0;
    end
  end
  
  2'b10:
  begin
  end
  
  2'b11:
  begin
  end
  
  endcase
end
end
// -------------------------------------------------------------------------------------------------

endmodule
