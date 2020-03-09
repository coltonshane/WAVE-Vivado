`timescale 1ns / 1ps
/*
=================================================================================
decompressor.v

Decompresses raw wavelet input data for read from RAM. Data is read in through a
64-bit wide FIFO, which in turn triggers RAM reads based on its fill level. The
data is decoded and dequantized into four 16-bit signed pixel values to be
distributed to inverse DWT core input buffers by downstream logic.

The decompressor must reset to a valid initial state for each frame (no
frame pipeline, since frames may be skipped in preview/playback). To do this,
a state machine driven externally by the HDMI vertical scan progress manages
the decompressor reset:

STATE           DESCRIPTION
---------------------------------------------------------------------------------
0 FIFO_RST      BRAM FIFOs are held in reset.
                Externally, the RAM read address is updated.
                Externally, the bit discard count is updated.
                e_len is forced to zero (no bits consumed from e_buffer).
                Decoder and dequantizer are DISABLED.
                
1 FIFO_FILL     BRAM FIFOs are allowed to fill up to their threshold.
                Bit discard counts are latched.
                e_len is forced to zero (no bits consumed from e_buffer).
                Decoder and dequantizer are DISABLED.
                
2 BIT_DISCARD   Bits are discarded based on the bit discard count.
                e_len is used to consume bits from e_buffer.
                Decoder and dequantizer are DISABLED.

3 PX_CONSUME    Pixels are processed from e_buffer.
                e_len is driven by the decoder.
                Decoder and dequantizer are ENABLED.

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

// Decompressor state enumeration.
`define DC_STATE_FIFO_RST 2'b00
`define DC_STATE_FIFO_FILL 2'b01
`define DC_STATE_BIT_DISCARD 2'b10
`define DC_STATE_PX_CONSUME 2'b11

module decompressor
(
  input wire m00_axi_aclk,
  input wire fifo_wr_next,
  input wire [63:0] fifo_wr_data,
  output wire [9:0] fifo_wr_count,
  
  input wire opx_clk,
  input wire fifo_rst,
  input wire [1:0] dc_state,
  input wire px_en_div4,
  input wire [23:0] bit_discard_update,
  input wire signed [17:0] q_mult_inv,
  output wire [63:0] out_4px
);

// BRAM FIFO. Read and write interface are both 64b.
// -------------------------------------------------------------------------------------------------
wire fifo_rd_en;
wire [63:0] fifo_rd_data;

// Instantiate two FIFO36 primatives.
FIFO36E2 
#(
   .FIRST_WORD_FALL_THROUGH("TRUE"),
   .RDCOUNT_TYPE("EXTENDED_DATACOUNT"),
   .WRCOUNT_TYPE("EXTENDED_DATACOUNT"),
   .READ_WIDTH(72),
   .REGISTER_MODE("REGISTERED"),
   .WRITE_WIDTH(72)
)
FIFO36E2_inst
(
   .RDCLK(opx_clk),
   .RDEN(fifo_rd_en),
   .DOUT(fifo_rd_data),
   
   .RST(fifo_rst),
   .WRCLK(m00_axi_aclk),
   .WREN(fifo_wr_next),
   .DIN(fifo_wr_data),
   .WRCOUNT(fifo_wr_count)
);
// -------------------------------------------------------------------------------------------------

// Set the number of bits to consume from e_buffer based on the state (combinational).
// -------------------------------------------------------------------------------------------------
reg [23:0] bit_discard;
reg [6:0] e_len;
wire [6:0] e_len_decoded;
always @(*)
begin
  if (dc_state == `DC_STATE_BIT_DISCARD)
  begin
    if (bit_discard >= 24'h00040)
    begin
      e_len <= 7'h40;
    end
    else
    begin
      e_len <= bit_discard;
    end
  end
  else if (dc_state == `DC_STATE_PX_CONSUME)
  begin
    e_len <= e_len_decoded;
  end
  else
  begin
    e_len <= 16'h0000;
  end
end
// -------------------------------------------------------------------------------------------------

// Latch the updated number of bits to discard during the FIFO_FILL state.
// -------------------------------------------------------------------------------------------------
always @(posedge opx_clk)
begin
  if (dc_state == `DC_STATE_FIFO_FILL)
  begin
    bit_discard <= bit_discard_update + 24'h000040;  // Add 64b to always discard e_buffer_L.
  end
  else if (dc_state == `DC_STATE_BIT_DISCARD)
  begin
    bit_discard <= bit_discard - e_len;
  end
  else
  begin
    bit_discard <= 24'h000000;
  end
end
// -------------------------------------------------------------------------------------------------

// Encoder buffer for aligning codestream data for the decoder. This is a logic-heavy section!!!
// -------------------------------------------------------------------------------------------------
reg [63:0] e_buffer_L;
wire [127:0] e_buffer = {fifo_rd_data, e_buffer_L};
reg [5:0] e_buffer_idx;

// Select data to present to the decoder (logic-heavy barrel shifter).
wire [63:0] e_4px = e_buffer[e_buffer_idx+:64];

wire [6:0] e_buffer_idx_next = {1'b0, e_buffer_idx} + e_len;

// Threshold for 64-bit shift.
wire shift_trigger = e_buffer_idx_next[6];

// Enable dequantizer and decoder if in PX_CONSUME state and opx_count has been updated.
wire dd_en = (dc_state == `DC_STATE_PX_CONSUME) & px_en_div4;

// Enable FIFO read if discarding bits or if decoder/dequantizer are enabled.
assign fifo_rd_en = shift_trigger & ((dc_state == `DC_STATE_BIT_DISCARD) | dd_en);

always @(posedge opx_clk)
begin
if (dc_state == `DC_STATE_FIFO_RST)
  begin
    e_buffer_L <= 64'h0;    // Not strictly neccessary since it will be bit-discarded.
    e_buffer_idx <= 6'h0;   // This is necessary.
  end
  else if ((dc_state == `DC_STATE_BIT_DISCARD) | dd_en)
  begin
    if(shift_trigger)
    begin
      e_buffer_L <= fifo_rd_data;
    end
    e_buffer_idx <= e_buffer_idx_next[5:0];
  end
end
// -------------------------------------------------------------------------------------------------

// Decode and dequantize.
wire [63:0] q_4px;
decoder_4x16(opx_clk, dd_en, e_4px, q_4px, e_len_decoded);
dequantizer_4x16(opx_clk, dd_en, q_mult_inv, q_4px, out_4px);

endmodule
