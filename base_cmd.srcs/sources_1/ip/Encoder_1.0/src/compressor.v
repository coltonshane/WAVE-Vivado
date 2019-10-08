`timescale 1ns / 1ps
/*
=================================================================================
compressor.v

Compresses raw wavelet output data for writing to RAM. Each compressor block
receives 32-bit wavelet output data from eight vertical wavelet cores, quantizes 
the individual pixel values, and encodes groups of four pixels using  a variable-
length code (VLC). The VLCs are written into a 128-bit wide FIFO. The RAM writer
reads from this FIFO as needed based on the fill level.
=================================================================================
*/

module compressor
(
    input wire px_clk,
    input wire px_clk_2x,
    input wire signed [23:0] px_count_c,
    input wire signed [23:0] px_count_e,
    input wire signed [9:0] q_mult,
    
    input wire [255:0] in_2px_concat,
    
    input wire m00_axi_aclk,
    input wire fifo_rd_next,
    output wire [9:0] fifo_rd_count,
    output wire [127:0] fifo_rd_data,
    
    output wire [127:0] debug_e_buffer
);

genvar i;

// Array views of input data for convenience.
wire [31:0] in_2px_H[3:0];
wire [31:0] in_2px_L[3:0];
for(i = 0; i < 4; i = i + 1)
begin
    assign in_2px_H[i] = in_2px_concat[(64*i+32)+:32];
    assign in_2px_L[i] = in_2px_concat[(64*i)+:32];
end

// Registers for storing previous two-pixel inputs.
reg [31:0] in_2px_H_prev[3:0];
reg [31:0] in_2px_L_prev[3:0];

// The compressor cycles through eight states based on px_count_c.
wire [2:0] c_state;
assign c_state = px_count_c[2:0];

// Update previous values on state zero, which must correspond with new data
// being ready at the inputs. (Set px_count_c offset accordingly.)
always @(posedge px_clk)
begin
    if (c_state == 3'd0)
    begin
        in_2px_H_prev[3] <= in_2px_H[3];
        in_2px_H_prev[2] <= in_2px_H[2];
        in_2px_H_prev[1] <= in_2px_H[1];
        in_2px_H_prev[0] <= in_2px_H[0];
        in_2px_L_prev[3] <= in_2px_L[3];
        in_2px_L_prev[2] <= in_2px_L[2];
        in_2px_L_prev[1] <= in_2px_L[1];
        in_2px_L_prev[0] <= in_2px_L[0];
    end
end

// Quantizer data 4:1 muxes. Only c_state 4-7 are needed, but it's easier to
// always round-robin based on c_state[1:0] and gate at the FIFO.
wire [63:0] in_4px_concat_H;
wire [63:0] in_4px_concat_L;
assign in_4px_concat_H = {in_2px_H[c_state[1:0]], in_2px_H_prev[c_state[1:0]]}; 
assign in_4px_concat_L = {in_2px_L[c_state[1:0]], in_2px_L_prev[c_state[1:0]]};

// Quantizer output views.
wire [63:0] q_4px_concat_H;
wire [63:0] q_4px_concat_L;

// Instantiate two 4x16b quantizers for the high and low data.
quantizer_4x16 q4x16_H (px_clk, q_mult, in_4px_concat_H, q_4px_concat_H);
quantizer_4x16 q4x16_L (px_clk, q_mult, in_4px_concat_L, q_4px_concat_L);

// Encoder output views.
wire [63:0] e_4px_H;
wire [63:0] e_4px_L;
wire [6:0] e_len_H;
wire [6:0] e_len_L;

// Instantiate two 4x16 encoders for the high and low data.
encoder_4x16 e4x16_H (px_clk, q_4px_concat_H, e_4px_H, e_len_H);
encoder_4x16 e4x16_L (px_clk, q_4px_concat_L, e_4px_L, e_len_L);

// Encoder buffer for staging 64-bit writes to the FIFO. This is a logic-heavy section!!!
// -------------------------------------------------------------------------------------------------
// Memory (FF) for the encoder buffer and bit index for writes to it.
reg [63:0] e_buffer_0;
reg [63:0] e_buffer_1;
reg [6:0] e_buffer_idx;
reg e_buffer_state;
wire e_buffer_state_next;
assign e_buffer_state_next = e_buffer_idx[6] ? ~e_buffer_state : e_buffer_state;

wire [63:0] e_buffer_rd_interface;
assign e_buffer_rd_interface = e_buffer_state ? e_buffer_1 : e_buffer_0;

// Keep track of the LSB of this pixel counter to know if new data is being presented.
reg px_count_e_prev_LSB;
reg px_count_e_updated;
always @(posedge px_clk)
begin
    px_count_e_prev_LSB <= px_count_e[0];
    px_count_e_updated <= (px_count_e[0] ^ px_count_e_prev_LSB);
end

// Conditions must be met for e_buffer writing:
// 1. New data is being presented, i.e. px_count_e[0] has toggled.
// 2. The data is from a valid input pair. This happens on px_count_e = {0,1,2,3,8,9,10,11,...},
//    i.e. px_count_e[2] == 0. This masks out encoder data from the previous value storage phase.
wire e_buffer_wr_en;
assign e_buffer_wr_en = (px_count_e_updated) & (~px_count_e[2]);

// Split each px_clk period into two write phases.
wire e_buffer_wr_phase;
reg px_count_e_prev_LSB_2x;
always @(posedge px_clk_2x)
begin
    px_count_e_prev_LSB_2x <= px_count_e[0];
end
assign e_buffer_wr_phase = (px_count_e[0] == px_count_e_prev_LSB_2x);

// Select data from either the high or low encoder based on the write phase.
wire [63:0] e_buffer_wr_data;
wire [6:0] e_buffer_wr_len;
assign e_buffer_wr_data = e_buffer_wr_phase ? e_4px_H : e_4px_L;
assign e_buffer_wr_len = e_buffer_wr_phase ? e_len_H : e_len_L;

wire [127:0] e_buffer_wr_data_shifted;
assign e_buffer_wr_data_shifted = e_buffer_wr_data << e_buffer_idx[5:0];

// Write operation.
always @(posedge px_clk_2x)
begin
    if (e_buffer_wr_en)
    begin
        
        if (e_buffer_state_next)
        begin
            e_buffer_0 <= e_buffer_wr_data_shifted[127:64];
            e_buffer_1 <= e_buffer_1 | e_buffer_wr_data_shifted[63:0];
        end
        else
        begin
            e_buffer_1 <= e_buffer_wr_data_shifted[127:64];
            e_buffer_0 <= e_buffer_0 | e_buffer_wr_data_shifted[63:0];
        end
        
        e_buffer_idx <= e_buffer_idx + e_buffer_wr_len - {e_buffer_idx[6], 6'b000000};
        
        e_buffer_state <= e_buffer_state_next;

    end
end
// -------------------------------------------------------------------------------------------------

// BRAM FIFO. Write interface is 64b. Read interface is 128b.
// -------------------------------------------------------------------------------------------------
// Enable FIFO writes when px_count_e is positive and the e_buffer has enough data.
wire fifo_wren;
assign fifo_wren = e_buffer_wr_en & e_buffer_idx[6];

// Instantiate two FIFO36 primatives.
FIFO36E2 
#(
   .FIRST_WORD_FALL_THROUGH("TRUE"),
   .RDCOUNT_TYPE("EXTENDED_DATACOUNT"),
   .READ_WIDTH(72),
   .REGISTER_MODE("REGISTERED"),
   .WRITE_WIDTH(36)
)
FIFO36E2_H 
(
   .DOUT({fifo_rd_data[127:96], fifo_rd_data[63:32]}),  // Reorder to match input.
   .RDCOUNT(fifo_rd_count),                             // Driver.
   .RDCLK(m00_axi_aclk),
   .RDEN(fifo_rd_next),

   .WRCLK(px_clk_2x),
   .WREN(fifo_wren), 
   .DIN(e_buffer_rd_interface[63:32])
);

FIFO36E2 
#(
   .FIRST_WORD_FALL_THROUGH("TRUE"),
   .RDCOUNT_TYPE("EXTENDED_DATACOUNT"),
   .READ_WIDTH(72),
   .REGISTER_MODE("REGISTERED"),
   .WRITE_WIDTH(36)
)
FIFO36E2_L 
(
   .DOUT({fifo_rd_data[95:64], fifo_rd_data[31:0]}),    // Reorder to match input.
   .RDCOUNT(),                                          // Follower.
   .RDCLK(m00_axi_aclk),
   .RDEN(fifo_rd_next),
   
   .WRCLK(px_clk_2x),
   .WREN(fifo_wren), 
   .DIN(e_buffer_rd_interface[31:0])
);
// -------------------------------------------------------------------------------------------------

assign debug_e_buffer = {e_buffer_1, e_buffer_0};

endmodule
