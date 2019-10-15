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
    input wire px_clk_2x,
    input wire signed [23:0] px_count_v1,
    input wire signed [15:0] S_in_0,
    input wire signed [15:0] D_in_0,
    input wire signed [15:0] S_in_1,
    input wire signed [15:0] D_in_1,
    input wire signed [15:0] S_in_2,
    input wire signed [15:0] D_in_2,
    input wire signed [15:0] S_in_3,
    input wire signed [15:0] D_in_3,
    
    output reg [31:0] HH1_out,
    output reg [31:0] HL1_out,
    output reg [31:0] LH1_out,
    output reg [31:0] LL1_out
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
assign wr_en = (px_count_v1[0] ^ px_count_v1_prev_LSB);
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

// Vertical 2/6 DWT Registers and Operations
// -------------------------------------------------------------------------------------------------
// Storage for operands and intermdiate results.
reg [63:0] X_even_concat;
reg [63:0] X_odd_concat;
reg [63:0] S_above_concat;
reg [63:0] S_below_concat;

// Combinational logic for 2/6 DWT Steps.
wire signed [15:0] X_even [3:0];
wire signed [15:0] X_odd [3:0];
wire signed [15:0] S_above [3:0];
wire signed [15:0] S_below [3:0];
wire signed [15:0] S_local [3:0];
wire signed [15:0] D_local [3:0];
wire signed [15:0] S_out [3:0];
wire signed [15:0] D_out [3:0];
wire [63:0] S_local_concat;
wire [63:0] D_local_concat;
genvar i;
for (i = 0; i < 4; i = i + 1)
begin
    assign X_even[i] = X_even_concat[16*i+:16];
    assign X_odd[i] = X_odd_concat[16*i+:16];
    assign S_above[i] = S_above_concat[16*i+:16];
    assign S_below[i] = S_below_concat[16*i+:16];
    
    assign D_local[i] = X_odd[i] - X_even[i];
    assign S_local[i] = X_even[i] + (D_local[i] >>> 1);
    assign S_out[i] = X_even[i];
    assign D_out[i] = X_odd[i] + ((S_above[i] - S_below[i] + 16'sh0002) >>> 2);
    
    assign S_local_concat[16*i+:16] = S_local[i];
    assign D_local_concat[16*i+:16] = D_local[i];
end
// -------------------------------------------------------------------------------------------------

// Read state. Cycles through 8 states on px_clk_2x. 
// rd_state[2:0] transitions from 7 to 0 when px_count_v1[1:0] increments from 3 to 0.
// -------------------------------------------------------------------------------------------------
wire [2:0] rd_state ;

reg px_count_v1_prev_LSB_2x;
always @(posedge px_clk_2x)
begin
    px_count_v1_prev_LSB_2x <= px_count_v1[0];
end

assign rd_state = {px_count_v1[1:0], (px_count_v1[0] == px_count_v1_prev_LSB_2x)};
// -------------------------------------------------------------------------------------------------

// Read address generation (combinational).
// -------------------------------------------------------------------------------------------------
wire [8:0] rd_addr;
wire [2:0] row_offset[7:0];
assign row_offset[0] = 2;   // State 0: Request Row N-6 = Row N+2
assign row_offset[1] = 3;   // State 1: Request Row N-5 = Row N+3
assign row_offset[2] = 6;   // State 2: Request Row N-2 = Row N+6
assign row_offset[3] = 7;   // State 3: Request Row N-1 = Row N+7
assign row_offset[4] = 4;   // State 4: Request Row N-4 = Row N+4
assign row_offset[5] = 5;   // State 5: Request Row N-3 = Row N+5
assign row_offset[6] = 5;   // Don't care, leave unchanged.
assign row_offset[7] = 5;   // Don't care, leave unchanged.

assign rd_addr[8:6] = {px_count_v1[9:8], 1'b0} + row_offset[rd_state];
assign rd_addr[5:0] = px_count_v1[7:2];
// -------------------------------------------------------------------------------------------------

// Read operation. (One clock cycle latency between updating rd_addr and latching rd_data.)
//  ------------------------------------------------------------------------------------------------
reg [63:0] rd_data ;

always @(posedge px_clk_2x)
begin
    rd_data <= {mem[{rd_addr, 1'b1}], mem[{rd_addr, 1'b0}]};
end

//  ------------------------------------------------------------------------------------------------

// Vertical 2/6 DWT state machine on read data.
// -------------------------------------------------------------------------------------------------
always @(posedge px_clk_2x)
begin
// Gate with wr_en to enforce read:write ratio, otherwise states can run more than once during
// line overhead time when LVAL/DVAL are low and px_count_v1 is not incrementing.
if (wr_en)
begin
    case (rd_state)
    
    3'b000: // Nothing to do here. Just waiting for first rd_data.
    begin       
    end
    
    3'b001: // Receive Row N-6. Latch outputs.
    begin
        LL1_out <= {S_out[2], S_out[0]};
        HL1_out <= {S_out[3], S_out[1]};
        LH1_out <= {D_out[2], D_out[0]};
        HH1_out <= {D_out[3], D_out[1]};
        X_even_concat <= rd_data;
    end
    
    3'b010: // Receive Row N-5.
    begin
        X_odd_concat <= rd_data;
    end
    
    3'b011: // Receive Row N-2. Do local sum on Row N-6 and N-5.
    begin
        S_above_concat <= S_local_concat;
        X_even_concat <= rd_data;
    end
    
    3'b100: // Receive Row N-1.
    begin
        X_odd_concat <= rd_data;
    end
    
    3'b101: // Receive Row N-4. Do local sum on Row N-2 and N-1.
    begin
        S_below_concat <= S_local_concat;
        X_even_concat <= rd_data;
    end
    
    3'b110: // Receive Row N-3.
    begin
        X_odd_concat <= rd_data;
    end
    
    3'b111: // Do local sum and difference on Row N-4 and N-3.
    begin
        X_even_concat <= S_local_concat;
        X_odd_concat <= D_local_concat;
    end
    
    endcase
end
end

// -------------------------------------------------------------------------------------------------

endmodule
