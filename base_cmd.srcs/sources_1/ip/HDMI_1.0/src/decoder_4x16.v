`timescale 1ns / 1ps
/*
=================================================================================
decoder_4x16.v

Decodes four 16-bit signed values from a variable-length code based on the
number of bits required to represent the values. The number of bits required is 
based on the four decoded values themselves. Some examples:

Values            bit_req   all_zeros   Comment
{0, 0, 0, 0}    0 (1 bit)           1   Special case. Treated as zero bits.
{0, 0, -1, 0}   0 (1 bit)           0   Sign bit only. (All 0x0000 or 0xFFFF.)
{1, 0, 0, 0}    1 (2 bit)           0   signed[1:0] range is -2 to 1.
{5, 0, -2, 2}   3 (4 bit)           0   signed[3:0] range is -7 to 8.

The variable-length code of up to 64 bits consists of an LSB-aligned prefix 
indicating the number of bits used to code each value followed by the values 
themselves, each coded with that number of bits.

  Bits   Code                                              Ratio (w.r.t. 10-bit)
     0   1'b0                                                               40:1  
   1-2   {q3[1:0], q2[1:0], q1[1:0], q0[1:0], 2'b01}                         4:1
     3   {q3[2:0], q2[2:0], q1[2:0], q0[2:0], 3'b011}                    2.667:1
     4   {q3[3:0], q2[3:0], q1[3:0], q0[3:0], 4'b0111}                       2:1
     5   {q3[4:0], q2[4:0], q1[4:0], q0[4:0], 5'b01111}                    1.6:1
     6   {q3[5:0], q2[5:0], q1[5:0], q0[5:0], 6'b011111}                 1.333:1
   7-8   {q3[7:0], q2[7:0], q1[7:0], q0[7:0], 8'b00111111}                   1:1
  9-10   {q3[9:0], q2[9:0], q1[9:0], q0[9:0], 8'b01111111}               0.833:1
 11-14   {q3[13:0], q2[13:0], q1[13:0], q0[13:0], 8'b11111111}           0.625:1
 
 The decoder takes as its input a 64-bit section of the codestream buffer in
 which the prefix is expected to start at bit 0. It parses the prefix to
 determine the bit requirement and expands the four coded values that follow 
 into decoded 16-bit signed values. If the coded size is smaller than 64 bits,
 the MSBs are unused and are expected to be shifted down correctly for the next
 four pixel group by upstream logic.
 
 The four decoded values (q_4px, assumed to still be quantized pixel values) and 
 the total number of bits consumed from the codestream (e_len) are registered as  
 outputs in one clock cycle.
 
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
=================================================================================
*/


module decoder_4x16
(
  input wire opx_clk,
  input wire en,
  input wire [63:0] e_4px,
  output reg[63:0] q_4px,
  output reg[6:0] e_len
);

// The number of bits required is determined by the prefix.
// Combinational, using casez with don't-cares:
reg [3:0] bit_req;
always @(*)
begin
    casez (e_4px[7:0])
    8'b???????0: bit_req <= 4'h0;
    8'b??????01: bit_req <= 4'h2;
    8'b?????011: bit_req <= 4'h3;
    8'b????0111: bit_req <= 4'h4;
    8'b???01111: bit_req <= 4'h5;
    8'b??011111: bit_req <= 4'h6;
    8'b00111111: bit_req <= 4'h8;
    8'b01111111: bit_req <= 4'hA;
    8'b11111111: bit_req <= 4'hE;
    endcase
end

// Unpack the data according to the bit requirement, with sign extension.
always @(posedge opx_clk)
begin
if (en)
begin
  case (bit_req)
  4'h0:    q_4px <= 64'b0;
  4'h2:    q_4px <= {{14{e_4px[9]}},  e_4px[9:8],   {14{e_4px[7]}},  e_4px[7:6],   {14{e_4px[5]}},  e_4px[5:4],   {14{e_4px[3]}},  e_4px[3:2]};
  4'h3:    q_4px <= {{13{e_4px[14]}}, e_4px[14:12], {13{e_4px[11]}}, e_4px[11:9],  {13{e_4px[8]}},  e_4px[8:6],   {13{e_4px[5]}},  e_4px[5:3]};
  4'h4:    q_4px <= {{12{e_4px[19]}}, e_4px[19:16], {12{e_4px[15]}}, e_4px[15:12], {12{e_4px[11]}}, e_4px[11:8],  {12{e_4px[7]}},  e_4px[7:4]};
  4'h5:    q_4px <= {{11{e_4px[24]}}, e_4px[24:20], {11{e_4px[19]}}, e_4px[19:15], {11{e_4px[14]}}, e_4px[14:10], {11{e_4px[9]}},  e_4px[9:5]};
  4'h6:    q_4px <= {{10{e_4px[29]}}, e_4px[29:24], {10{e_4px[23]}}, e_4px[23:18], {10{e_4px[17]}}, e_4px[17:12], {10{e_4px[11]}}, e_4px[11:6]};
  4'h8:    q_4px <= { {8{e_4px[39]}}, e_4px[39:32],  {8{e_4px[31]}}, e_4px[31:24],  {8{e_4px[23]}}, e_4px[23:16],  {8{e_4px[15]}}, e_4px[15:8]};
  4'hA:    q_4px <= { {6{e_4px[47]}}, e_4px[47:38],  {6{e_4px[37]}}, e_4px[37:28],  {6{e_4px[27]}}, e_4px[27:18],  {6{e_4px[17]}}, e_4px[17:8]};
  default: q_4px <= { {2{e_4px[63]}}, e_4px[63:50],  {2{e_4px[49]}}, e_4px[49:36],  {2{e_4px[35]}}, e_4px[35:22],  {2{e_4px[21]}}, e_4px[21:8]};
  endcase
end
end

// Indicate the number of bits to be consumed (combinational).
always @(*)
begin
  case (bit_req)
  4'h0:    e_len <= 7'd1;
  4'h2:    e_len <= 7'd10;
  4'h3:    e_len <= 7'd15;
  4'h4:    e_len <= 7'd20;
  4'h5:    e_len <= 7'd25;
  4'h6:    e_len <= 7'd30;
  4'h8:    e_len <= 7'd40;
  4'hA:    e_len <= 7'd48;
  default: e_len <= 7'd64;
  endcase
end

endmodule
