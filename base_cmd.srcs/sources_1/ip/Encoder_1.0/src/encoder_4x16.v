`timescale 1ns / 1ps
/*
=================================================================================
encoder_4x16.v

Encodes four 16-bit signed values using a variable-length code based on the
number of bits required to represent the values. First, the number of bits
required is calculated based on the four values themselves. Some examples:

Values            bit_req   all_zeros   Comment
{0, 0, 0, 0}    0 (1 bit)           1   Special case. Treated as zero bits.
{0, 0, -1, 0}   0 (1 bit)           0   Sign bit only. (All 0x0000 or 0xFFFF.)
{1, 0, 0, 0}    1 (2 bit)           0   signed[1:0] range is -2 to 1.
{5, 0, -2, 2}   3 (4 bit)           0   signed[3:0] range is -7 to 8.

Then, a variable-length code of up to 64 bits is constructed, consisting of an
LSB-aligned prefix indicating the number of bits used to code each value followed
by the values themselves, coded with that number of bits.

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
=================================================================================
*/

module encoder_4x16
(
    input wire px_clk,
    input wire [63:0] q_4px_concat,
    output reg[63:0] e_4px,
    output reg[6:0] e_len
);

genvar i;

// Signed views of each (already quantized) pixel in the concatenated input.
wire signed [15:0] q0;
wire signed [15:0] q1;
wire signed [15:0] q2;
wire signed [15:0] q3;
assign q0 = q_4px_concat[15:0];
assign q1 = q_4px_concat[31:16];
assign q2 = q_4px_concat[47:32];
assign q3 = q_4px_concat[63:48];


// 16x4b vertical slices of the 4x16b quantized pixel inputs.
wire [3:0] q_slice [15:0];
for(i = 0; i < 16; i = i + 1)
begin
    assign q_slice[i] = {q3[i], q2[i], q1[i], q0[i]};
end

// Mark 4b slices that are not equal to the one above, i.e. toward the MSB.
wire [14:0] q_slice_neq_above;
for(i = 0; i < 15; i = i + 1)
begin
    assign q_slice_neq_above[i] = (q_slice[i] != q_slice[i+1]);
end

// The number of bits required is determined by the position of the first
// slice not equal to the one above it. Using casez with don't-cares:
reg [3:0] bit_req;
always @(*)
begin
    casez (q_slice_neq_above)
    15'b000000000000000: bit_req <= 4'h0;
    15'b000000000000001: bit_req <= 4'h1;
    15'b00000000000001?: bit_req <= 4'h2;
    15'b0000000000001??: bit_req <= 4'h3;
    15'b000000000001???: bit_req <= 4'h4;
    15'b00000000001????: bit_req <= 4'h5;
    15'b0000000001?????: bit_req <= 4'h6;
    15'b000000001??????: bit_req <= 4'h7;
    15'b00000001???????: bit_req <= 4'h8;
    15'b0000001????????: bit_req <= 4'h9;
    15'b000001?????????: bit_req <= 4'hA;
    15'b00001??????????: bit_req <= 4'hB;
    15'b0001???????????: bit_req <= 4'hC;
    15'b001????????????: bit_req <= 4'hD;
    15'b01?????????????: bit_req <= 4'hE;
    15'b1??????????????: bit_req <= 4'hF;
    endcase
end

// All zeros is a special case: one bit req'd but the top slice is 4'h0.
wire all_zeros;
assign all_zeros = (bit_req == 4'h0) & (q_slice[15] == 4'h0);

// Create variable-bit-length views of the data.
wire code0b;
assign code0b = 1'b0;
wire [9:0] code2b;
assign code2b = {q3[1:0], q2[1:0], q1[1:0], q0[1:0], 2'b01};
wire [14:0] code3b;
assign code3b = {q3[2:0], q2[2:0], q1[2:0], q0[2:0], 3'b011};
wire [19:0] code4b;
assign code4b = {q3[3:0], q2[3:0], q1[3:0], q0[3:0], 4'b0111};
wire [24:0] code5b;
assign code5b = {q3[4:0], q2[4:0], q1[4:0], q0[4:0], 5'b01111};
wire [29:0] code6b;
assign code6b = {q3[5:0], q2[5:0], q1[5:0], q0[5:0], 6'b011111};
wire [39:0] code8b;
assign code8b = {q3[7:0], q2[7:0], q1[7:0], q0[7:0], 8'b00111111};
wire [47:0] code10b;
assign code10b = {q3[9:0], q2[9:0], q1[9:0], q0[9:0], 8'b01111111};
wire [63:0] code14b;
assign code14b = {q3[13:0], q2[13:0], q1[13:0], q0[13:0], 8'b11111111};

// Register a variable-bit-length code based on the number of bits required.
always @(posedge px_clk)
begin
    if (all_zeros)
    begin
        e_4px <= code0b;
    end
    else
    begin
        case (bit_req)
        4'h0, 4'h1: e_4px <= code2b;
        4'h2: e_4px <= code3b;
        4'h3: e_4px <= code4b;
        4'h4: e_4px <= code5b;
        4'h5: e_4px <= code6b;
        4'h6, 4'h7: e_4px <= code8b;
        4'h8, 4'h9: e_4px <= code10b;
        default: e_4px <= code14b;
        endcase
    end
end

// Register the length of the code.
always @(posedge px_clk)
begin
    if (all_zeros)
    begin
        e_len <= 7'd1;
    end
    else
    begin
        case (bit_req)
        4'h0, 4'h1: e_len <= 7'd10;
        4'h2: e_len <= 7'd15;
        4'h3: e_len <= 7'd20;
        4'h4: e_len <= 7'd25;
        4'h5: e_len <= 7'd30;
        4'h6, 4'h7: e_len <= 7'd40;
        4'h8, 4'h9: e_len <= 7'd48;
        default: e_len <= 7'd64;
        endcase
    end
end

endmodule
