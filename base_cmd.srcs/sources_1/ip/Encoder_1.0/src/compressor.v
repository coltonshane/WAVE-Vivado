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
    input wire signed [23:0] px_count_c,
    input wire signed [9:0] q_mult,
    
    input wire [31:0] in_2px_0,
    input wire [31:0] in_2px_1,
    input wire [31:0] in_2px_2,
    input wire [31:0] in_2px_3,
    input wire [31:0] in_2px_4,
    input wire [31:0] in_2px_5,
    input wire [31:0] in_2px_6,
    input wire [31:0] in_2px_7,
    
    output wire [255:0] debug_e_buffer
    
    // input [8:0] rd_addr,
    // output [127:0] rd_data
);

genvar i;

// Array views of input data for convenience.
wire [31:0] in_2px_H[3:0];
wire [31:0] in_2px_L[3:0];
assign in_2px_H[3] = in_2px_7;
assign in_2px_H[2] = in_2px_6;
assign in_2px_H[1] = in_2px_5;
assign in_2px_H[0] = in_2px_4;
assign in_2px_L[3] = in_2px_3;
assign in_2px_L[2] = in_2px_2;
assign in_2px_L[1] = in_2px_1;
assign in_2px_L[0] = in_2px_0;

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
// round-robin based on c_state[1:0] and gate at the FIFO.
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

// Encoder buffer for staging 128-bit writes to the FIFO.
// -------------------------------------------------------------------------------------------------
reg [255:0] e_buffer;
reg [7:0] e_buffer_idx;

// Create a pixel counter at the interface between the encoder and the FIFO, accounting for the
// latency of previous value storing (4), the quantizer (1), and the encoder (1).
wire signed [23:0] px_count_e;
reg px_count_e_prev_LSB;
assign px_count_e = px_count_c - 24'sh000006;
always @(posedge px_clk)
begin
    px_count_e_prev_LSB <= px_count_e[0];
end

// Writes are enabled whenever px_count_e changes to a value greater than or equal to zero.
wire e_buffer_wr_en;
assign e_buffer_wr_en = (px_count_e[0] ^ px_count_e_prev_LSB) & (px_count_e >= 24'sh000000);

// Merge write operation occur at px_count_e = {0, 1, 2, 3, 8, 9, 10, 11, 16, 17, 18, 19, ...}
// i.e. when px_count_e[2] = 1'b0. Write four / skip four while storing previous values.
// At most 128 (8'h80) bits are written into the encoder buffer per clock.
always @(posedge px_clk)
begin
    if (e_buffer_wr_en & ~px_count_e[2])
    begin
    
        if (e_buffer_idx >= 8'h80)
        begin
            // There's enough data to trigger a FIFO write. Shift existing data down.
            // Further non-blocking assigns will override individual bits as-needed.
            e_buffer[127:0] <= e_buffer[255:128];
            
            // Add new data.
            e_buffer[(e_buffer_idx - 8'h80)+:128] <= (e_4px_H << e_len_L) | e_4px_L;
            
            // Update the index.
            e_buffer_idx <= e_buffer_idx - 8'h80 + e_len_L + e_len_H;
        end
        else
        begin
            // Add new data.
            e_buffer[(e_buffer_idx)+:128] <= (e_4px_H << e_len_L) | e_4px_L;
            
            // Update the index.
            e_buffer_idx <= e_buffer_idx + e_len_L + e_len_H;
        end
    end
end
// -------------------------------------------------------------------------------------------------

assign debug_e_buffer = e_buffer;

endmodule
