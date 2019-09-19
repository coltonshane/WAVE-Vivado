`timescale 1ns / 1ps
/*
=================================================================================
bit_req_4x16.v
Combinational logic to determind the number of bits required to encode four
16-bit signed values, based on the values themselves.

Some examples:

x0  0b 0000 0000 0000 0000  (0)     bit_req = 0 (1 bit)
x1  0b 0000 0000 0000 0000  (0)     all_zeros = 1
x2  0b 0000 0000 0000 0000  (0)     This is a special case. It gets treated
x3  0b 0000 0000 0000 0000  (0)     as requiring zero bits by the encoder.

x0  0b 0000 0000 0000 0000  (0)     bit_req = 0 (1 bit)
x1  0b 0000 0000 0000 0000  (0)     all_zeros = 0
x2  0b 1111 1111 1111 1111  (-1)
x3  0b 0000 0000 0000 0000  (0)

x0  0b 0000 0000 0000 0001  (1)     bit_req = 1 (2 bit)
x1  0b 0000 0000 0000 0000  (0)     all_zeros = 0
x2  0b 0000 0000 0000 0000  (0)     This requires two bits since it exceeds
x3  0b 0000 0000 0000 0000  (0)     the range of signed [0:0], i.e. -1 to 0.

x0  0b 0000 0000 0000 0101  (5)     bit_req = 3 (4 bit)
x1  0b 0000 0000 0000 0000  (0)     all_zeros = 0
x2  0b 1111 1111 1111 1101  (-2)    signed [3:0] range is -7 to 8.
x3  0b 0000 0000 0000 0010  (2)     
=================================================================================
*/

module bit_req_4x16
(
    input wire signed [15:0] x0,
    input wire signed [15:0] x1,
    input wire signed [15:0] x2,
    input wire signed [15:0] x3,
    
    output reg [3:0] bit_req,
    output wire all_zeros
);

genvar i;

// Create a 16x4b vertical slices of the 4x16b inputs.
wire [3:0] x_slice [15:0];
for(i = 0; i < 16; i = i + 1)
begin
    assign x_slice[i] = {x3[i], x2[i], x1[i], x0[i]};
end

// Mark 4b slices that are not equal to the one above, i.e. toward the MSB.
wire [14:0] x_slice_neq_above;
for(i = 0; i < 15; i = i + 1)
begin
    assign x_slice_neq_above[i] = (x_slice[i] != x_slice[i+1]);
end

// The number of bits required is determined by the position of the first
// slice not equal to the one above it. Using casez with don't-cares:
always @(*)
begin
    casez (x_slice_neq_above)
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
assign all_zeros = (bit_req == 4'h0) & (x_slice[15] == 4'h0);

endmodule
