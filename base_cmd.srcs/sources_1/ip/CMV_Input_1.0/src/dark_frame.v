`timescale 1 ns / 1 ps
/*
===================================================================================
dark_frame.v

Subtract a pseudo dark frame from the input pixels by way of row and column 
offsets. (Assumes the dark frame is separable into dark rows and dark columns.)
The dark row and dark columns are stored in URAM LUTs as 16-bit signed values.

lut_dark_col_0   {CH03, CH02, CH01, CH00} and {CH35, CH34, CH33, CH32}
lut_dark_col_1   {CH07, CH06, CH05, CH04} and {CH39, CH38, CH37, CH36}
lut_dark_col_2   {CH11, CH10, CH09, CH08} and {CH43, CH42, CH41, CH40}
lut_dark_col_3   {CH15, CH14, CH13, CH12} and {CH47, CH46, CH45, CH44}
lut_dark_col_4   {CH19, CH18, CH17, CH16} and {CH51, CH50, CH49, CH48}
lut_dark_col_5   {CH23, CH22, CH21, CH20} and {CH55, CH54, CH53, CH52}
lut_dark_col_6   {CH27, CH26, CH25, CH24} and {CH59, CH58, CH57, CH56}
lut_dark_col_7   {CH31, CH30, CH29, CH28} and {CH63, CH62, CH61, CH60}

Each channel has 128 entries corresponding to the 128 pixels per row group.
In 4K mode, these map to columns direclty. In 2K mode, columns are repeated
in pairs so that the same lut_dark_col_X_raddr generation can be used:
4K: 0, 1, 2, 3, 4, 5, 6, 7, ... , 120, 121, 122, 123, 124, 125, 126, 127
2K: 0, 1, 0, 1, 2, 3, 2, 3, ... ,  60,  61,  60,  61,  62,  63,  62,  63

lut_dark_row    {Row N+3, Row N+2, Row N+1, Row N+0}

      4K    2K   Channel Mapping
Row  N+0   N+0   CH00 to CH31 when px_count[1] == 1'b0
Row  N+1   N+1   CH32 to CH63 when px_count[1] == 1'b0
Row  N+0   N+2   CH00 to CH31 when px_count[1] == 1'b1
Row  N+1   N+3   CH32 to CH63 when px_count[1] == 1'b1

In both 4K and 2K mode, lut_dark_row_raddr updates every 128 px_clk.
4K: Two rows are consumed per 128 px_clk. Up to 1536 total entries.
2K: Four rows are consumed per 128 px_clk. Up to 768 total entries.
In 4K mode, Row N+0 and N+1 are repeated in the upper two words of the entry 
to allow the px_count[2] switch to be identical in both modes.

All operations are combinational. The LUTs operate in the AXI clock domain at
250MHz, so they can return rdata for an raddr in a fraction of a px_clk.

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


module dark_frame
#(
  parameter integer PX_MATH_WIDTH = 16
)
(
  input wire signed [23:0] px_count,
  input wire [639:0] px_chXX_raw_concat,
  
  input wire [63:0] lut_dark_col_0_rdata,
  input wire [63:0] lut_dark_col_1_rdata,
  input wire [63:0] lut_dark_col_2_rdata,
  input wire [63:0] lut_dark_col_3_rdata,
  input wire [63:0] lut_dark_col_4_rdata,
  input wire [63:0] lut_dark_col_5_rdata,
  input wire [63:0] lut_dark_col_6_rdata,
  input wire [63:0] lut_dark_col_7_rdata,
  input wire [63:0] lut_dark_row_rdata,
  
  output wire [11:0] lut_dark_col_0_raddr,
  output wire [11:0] lut_dark_col_1_raddr,
  output wire [11:0] lut_dark_col_2_raddr,
  output wire [11:0] lut_dark_col_3_raddr,
  output wire [11:0] lut_dark_col_4_raddr,
  output wire [11:0] lut_dark_col_5_raddr,
  output wire [11:0] lut_dark_col_6_raddr,
  output wire [11:0] lut_dark_col_7_raddr,
  output wire [11:0] lut_dark_row_raddr,
  
  output wire [639:0] px_chXX_out_concat
);

genvar i;

// Address generation.
assign lut_dark_col_0_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_1_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_2_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_3_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_4_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_5_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_6_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_col_7_raddr = {5'b00000, px_count[6:0]};
assign lut_dark_row_raddr = px_count[18:7];

// Array the concatenated input and output for convenience.
wire signed [(PX_MATH_WIDTH-1):0] px_chXX_raw [63:0];
wire signed [(PX_MATH_WIDTH-1):0] px_chXX_out [63:0];
for(i = 0; i < 64; i = i + 1)
begin
  assign px_chXX_raw[i] = px_chXX_raw_concat[10*i+:10];
  assign px_chXX_out_concat[10*i+:10] = px_chXX_out[i][9:0];
end

// Array the column and row bias data for convenience.
wire signed [(PX_MATH_WIDTH-1):0] dark_col [31:0];
wire signed [(PX_MATH_WIDTH-1):0] dark_row [3:0];
for(i = 0; i < 4; i = i + 1)
begin
  assign dark_col[0+i] = lut_dark_col_0_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[4+i] = lut_dark_col_1_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[8+i] = lut_dark_col_2_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[12+i] = lut_dark_col_3_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[16+i] = lut_dark_col_4_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[20+i] = lut_dark_col_5_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[24+i] = lut_dark_col_6_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_col[28+i] = lut_dark_col_7_rdata[16*i+:PX_MATH_WIDTH];
  assign dark_row[i] = lut_dark_row_rdata[16*i+:PX_MATH_WIDTH];
end

// Map the column and row biases to each channel.
for(i = 0; i < 64; i = i + 1)
begin
  assign px_chXX_out[i] = px_chXX_raw[i] - dark_col[i[4:0]] - (px_count[1] ? dark_row[2+i[5]] : dark_row[0+i[5]]);
end

endmodule
