`timescale 1ns / 1ps
/* =================================================================================================
Discrete Wavelet Transform 2/6 Core, Vertical First Stage (dwt26_v1.v)

Operates on a circular 8-row buffer of data from four adjacent channels of the same color field:

            |<--------------------- 256px -------------------->|
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [2]
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [/]
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [6] --> Data Out
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [D] --> Data Out
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [W]
            [Channel N+0][Channel N+1][Channel N+2][Channel N+3] --> [T]
Data In --> [Channel N+0][Channel N+1][Channel N+2][Channel N+3]
Data In --> [Channel N+0][Channel N+1][Channel N+2][Channel N+3]

Data In is a 32-bit concatenated sum/difference from one of the four adjacent channels.
At each px_clk, the data is written to one of two input rows at the head of the buffer.

Simultaneoulsy, six output rows at the tail of the buffer are scanned with 64b-wide reads
from left to right to perform the vertical 2/6 DWT.

In 4096px mode, it takes 256 px_clk intervals to fill two rows and 64 DWT scans are required. 
In 2048px mode, it takes 128 px_clk intervals to fill two rows and 32 DWT scans are required.
In either mode, a DWT scan gets 4 px_clk:
    
All operations and operands are signed 16-bit unless otherwise noted.
================================================================================================= */

module dwt26_v1
(
    input wire px_clk,
    input wire signed [23:0] px_count_v1,
    input wire signed [15:0] S_in_0,
    input wire signed [15:0] D_in_0,
    input wire signed [15:0] S_in_1,
    input wire signed [15:0] D_in_1,
    input wire signed [15:0] S_in_2,
    input wire signed [15:0] D_in_2,
    input wire signed [15:0] S_in_3,
    input wire signed [15:0] D_in_3,

    input wire [8:0] rd_addr,
    output reg [63:0] rd_data
);

// Memory to be inferred as a single BRAM (32K = 8 x 256 x 16b).
reg [31:0] mem [1023:0];

// Write enable generation.
// -------------------------------------------------------------------------------------------------
wire wr_en;

// Writes are enabled whenever px_count_v1 changes to a value greater than or equal to zero.
reg px_count_v1_prev_LSB;
always @(posedge px_clk)
begin
    px_count_v1_prev_LSB <= px_count_v1[0];
end
assign wr_en = (px_count_v1[0] ^ px_count_v1_prev_LSB) & (px_count_v1 >= 24'sh000000);
// -------------------------------------------------------------------------------------------------

// Write address generation.
// -------------------------------------------------------------------------------------------------
wire [9:0] wr_addr;

// The write address is driven by px_count_v1, which is offset from px_count by the known latency
// of the first-stage horizontal wavelet cores feeding this vertical wavelet core. It distributes
// the four channels' data into the correct position in the two input rows.
// TO-DO: 2048px mode is a little more complicated, alternating between the two input rows.
assign wr_addr = {px_count_v1[9:7], px_count_v1[1:0], px_count_v1[6:2]};    // 4096px mode
// -------------------------------------------------------------------------------------------------

// Write data switch.
// -------------------------------------------------------------------------------------------------
reg [31:0] wr_data;     // Should infer as combinational logic, not registers.
always @(*)
begin
    case (px_count_v1[1:0])
    2'b00: wr_data = {D_in_0, S_in_0};
    2'b01: wr_data = {D_in_1, S_in_1};
    2'b10: wr_data = {D_in_2, S_in_2};
    2'b11: wr_data = {D_in_3, S_in_3};
    endcase
end

always @(posedge px_clk)
begin
    if (wr_en)
    begin
        mem[wr_addr] <= wr_data;
    end
end
// -------------------------------------------------------------------------------------------------

// Read operation (test).
// -------------------------------------------------------------------------------------------------
always @(posedge px_clk)
begin
    rd_data <= {mem[{rd_addr, 1'b1}], mem[{rd_addr, 1'b0}]};
end
// -------------------------------------------------------------------------------------------------

endmodule
