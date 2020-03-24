`timescale 1 ns / 1 ps
/*
===================================================================================
ui_mixer.v

Mixes the preview image with UI overlays to create the final HMDI RGB outputs.

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

module ui_mixer
#(
  // Background color.
  parameter [7:0] BGR_8b = 8'h00,
  parameter [7:0] BGG_8b = 8'h00,
  parameter [7:0] BGB_8b = 8'h40,
  
  // Top UI geometery.
  parameter [15:0] TOP_UI_X0 = 16'd128,
  parameter [15:0] TOP_UI_Y0 = 16'd41,
  parameter [15:0] TOP_UI_W = 16'd2048,
  parameter [15:0] TOP_UI_H = 16'd64,
  
  // Bottom UI geometery.
  parameter [15:0] BOT_UI_X0 = 16'd128,
  parameter [15:0] BOT_UI_Y0 = 16'd1057,
  parameter [15:0] BOT_UI_W = 16'd2048,
  parameter [15:0] BOT_UI_H = 16'd64,
  
  // Pop-up UI geometry (X0 and Y0 are dynamic).
  parameter [15:0] POP_UI_W = 16'd256,
  parameter [15:0] POP_UI_H = 16'd512
)
(
  input wire hdmi_clk,
  input wire s00_axi_aclk,
  
  input wire [7:0] R_8b,
  input wire [7:0] G_8b,
  input wire [7:0] B_8b,
  
  input wire [15:0] h_count,
  input wire [15:0] v_count,
  input wire inViewport,
  
  input wire top_ui_enabled,
  input wire bot_ui_enabled,
  input wire pop_ui_enabled,
  input wire [15:0] pop_ui_x0,
  input wire [15:0] pop_ui_y0,
  
  input wire [63:0] top_ui_rdata,
  input wire [63:0] bot_ui_rdata,
  input wire [63:0] pop_ui_rdata,
  output wire [11:0] top_ui_raddr,
  output wire [11:0] bot_ui_raddr,
  output wire [11:0] pop_ui_raddr,
  
  output reg [7:0] R_out,
  output reg [7:0] G_out,
  output reg [7:0] B_out
);

// inViewport switch selects preview image or background color (combinational).
wire [7:0] R_mix_8b = inViewport ? R_8b : BGR_8b;
wire [7:0] G_mix_8b = inViewport ? G_8b : BGG_8b;
wire [7:0] B_mix_8b = inViewport ? B_8b : BGB_8b;

// UI masks (combinational).
wire in_top_ui = ((h_count >= TOP_UI_X0) && (h_count < (TOP_UI_X0 + TOP_UI_W))
               && (v_count >= TOP_UI_Y0) && (v_count < (TOP_UI_Y0 + TOP_UI_H)));
wire in_bot_ui = ((h_count >= BOT_UI_X0) && (h_count < (BOT_UI_X0 + BOT_UI_W))
               && (v_count >= BOT_UI_Y0) && (v_count < (BOT_UI_Y0 + BOT_UI_H)));
wire in_pop_ui = ((h_count >= pop_ui_x0) && (h_count < (pop_ui_x0 + POP_UI_W))
               && (v_count >= pop_ui_y0) && (v_count < (pop_ui_y0 + POP_UI_H)));
               
// UI data latched into HDMI clock domain.
reg [63:0] top_ui_rdata_hdmi;
reg [63:0] bot_ui_rdata_hdmi;
reg [63:0] pop_ui_rdata_hdmi;

// UI pixel select (combinational).
wire [7:0] top_ui_8b = top_ui_rdata_hdmi[(h_count[3:1]*8)+:8];
wire [7:0] bot_ui_8b = bot_ui_rdata_hdmi[(h_count[3:1]*8)+:8];
wire [7:0] pop_ui_8b = pop_ui_rdata_hdmi[(h_count[3:1]*8)+:8];

// Global UI signals (combinational).
wire ui_rst = (h_count == 16'd0) && (v_count == 16'd0);
wire ui_rdata_init = (h_count == 16'd0) && (v_count == 16'd1);
wire ui_x_incr = (h_count[3:0] == 4'hD);
wire ui_x_rdata_latch = (h_count[3:0] == 4'hF);
               
// Top UI address generation w/ clock domain crossing.
// -------------------------------------------------------------------------------------------------
// HDMI Clock Domain
reg top_ui_rst;
reg top_ui_x_incr;
reg top_ui_y_incr;
always @(posedge hdmi_clk)
begin
  
  if (ui_rdata_init || ui_x_rdata_latch)
  begin
    top_ui_rdata_hdmi <= top_ui_rdata;
  end
  
  top_ui_rst <= ui_rst;
  top_ui_x_incr <= in_top_ui && ui_x_incr;
  top_ui_y_incr <= in_top_ui && (h_count == (TOP_UI_X0 + TOP_UI_W - 16'd3)) && (~v_count[0]);
end

// AXI Clock Domain
reg top_ui_rst_axi;
reg top_ui_x_incr_axi;
reg top_ui_y_incr_axi;
reg top_ui_rst_axi_prev;
reg top_ui_x_incr_axi_prev;
reg top_ui_y_incr_axi_prev;
reg [6:0] top_ui_x_axi;     // 128 * 8px = 1024px
reg [4:0] top_ui_y_axi;
always @(posedge s00_axi_aclk)
begin

  if (top_ui_rst_axi & ~top_ui_rst_axi_prev)
  begin
    top_ui_x_axi <= 7'h0;
    top_ui_y_axi <= 5'h0;
  end
  else 
  begin
    if (top_ui_x_incr_axi & ~top_ui_x_incr_axi_prev)
    begin
      top_ui_x_axi <= top_ui_x_axi + 7'h1;
    end
    if (top_ui_y_incr_axi & ~top_ui_y_incr_axi_prev)
    begin
      top_ui_y_axi <= top_ui_y_axi + 5'h1;
    end
  end
  
  top_ui_rst_axi <= top_ui_rst;
  top_ui_x_incr_axi <= top_ui_x_incr;
  top_ui_y_incr_axi <= top_ui_y_incr;
  
  top_ui_rst_axi_prev <= top_ui_rst_axi;
  top_ui_x_incr_axi_prev <= top_ui_x_incr_axi;
  top_ui_y_incr_axi_prev <= top_ui_y_incr_axi;
end

assign top_ui_raddr = {top_ui_y_axi, top_ui_x_axi};
// -------------------------------------------------------------------------------------------------

// Bottom UI address generation w/ clock domain crossing.
// -------------------------------------------------------------------------------------------------
// HDMI Clock Domain
reg bot_ui_rst;
reg bot_ui_x_incr;
reg bot_ui_y_incr;
always @(posedge hdmi_clk)
begin
  
  if (ui_rdata_init || ui_x_rdata_latch)
  begin
    bot_ui_rdata_hdmi <= bot_ui_rdata;
  end
  
  bot_ui_rst <= ui_rst;
  bot_ui_x_incr <= in_bot_ui && ui_x_incr;
  bot_ui_y_incr <= in_bot_ui && (h_count == (BOT_UI_X0 + BOT_UI_W - 16'd3)) && (~v_count[0]);
end

// AXI Clock Domain
reg bot_ui_rst_axi;
reg bot_ui_x_incr_axi;
reg bot_ui_y_incr_axi;
reg bot_ui_rst_axi_prev;
reg bot_ui_x_incr_axi_prev;
reg bot_ui_y_incr_axi_prev;
reg [6:0] bot_ui_x_axi;     // 128 * 8px = 1024px
reg [4:0] bot_ui_y_axi;
always @(posedge s00_axi_aclk)
begin

  if (bot_ui_rst_axi & ~bot_ui_rst_axi_prev)
  begin
    bot_ui_x_axi <= 7'h0;
    bot_ui_y_axi <= 5'h0;
  end
  else 
  begin
    if (bot_ui_x_incr_axi & ~bot_ui_x_incr_axi_prev)
    begin
      bot_ui_x_axi <= bot_ui_x_axi + 7'h1;
    end
    if (bot_ui_y_incr_axi & ~bot_ui_y_incr_axi_prev)
    begin
      bot_ui_y_axi <= bot_ui_y_axi + 5'h1;
    end
  end
  
  bot_ui_rst_axi <= bot_ui_rst;
  bot_ui_x_incr_axi <= bot_ui_x_incr;
  bot_ui_y_incr_axi <= bot_ui_y_incr;
  
  bot_ui_rst_axi_prev <= bot_ui_rst_axi;
  bot_ui_x_incr_axi_prev <= bot_ui_x_incr_axi;
  bot_ui_y_incr_axi_prev <= bot_ui_y_incr_axi;
end

assign bot_ui_raddr = {bot_ui_y_axi, bot_ui_x_axi};
// -------------------------------------------------------------------------------------------------

// Pop-up UI address generation w/ clock domain crossing.
// -------------------------------------------------------------------------------------------------
// HDMI Clock Domain
reg pop_ui_rst;
reg pop_ui_x_incr;
reg pop_ui_y_incr;
always @(posedge hdmi_clk)
begin
  
  if (ui_rdata_init || ui_x_rdata_latch)
  begin
    pop_ui_rdata_hdmi <= pop_ui_rdata;
  end
  
  pop_ui_rst <= ui_rst;
  pop_ui_x_incr <= in_pop_ui && ui_x_incr;
  pop_ui_y_incr <= in_pop_ui && (h_count == (pop_ui_x0 + POP_UI_W - 16'd3)) && (~v_count[0]);
end

// AXI Clock Domain
reg pop_ui_rst_axi;
reg pop_ui_x_incr_axi;
reg pop_ui_y_incr_axi;
reg pop_ui_rst_axi_prev;
reg pop_ui_x_incr_axi_prev;
reg pop_ui_y_incr_axi_prev;
reg [3:0] pop_ui_x_axi;     // 16 * 8px = 128px
reg [7:0] pop_ui_y_axi;
always @(posedge s00_axi_aclk)
begin

  if (pop_ui_rst_axi & ~pop_ui_rst_axi_prev)
  begin
    pop_ui_x_axi <= 7'h0;
    pop_ui_y_axi <= 5'h0;
  end
  else 
  begin
    if (pop_ui_x_incr_axi & ~pop_ui_x_incr_axi_prev)
    begin
      pop_ui_x_axi <= pop_ui_x_axi + 7'h1;
    end
    if (pop_ui_y_incr_axi & ~pop_ui_y_incr_axi_prev)
    begin
      pop_ui_y_axi <= pop_ui_y_axi + 5'h1;
    end
  end
  
  pop_ui_rst_axi <= pop_ui_rst;
  pop_ui_x_incr_axi <= pop_ui_x_incr;
  pop_ui_y_incr_axi <= pop_ui_y_incr;
  
  pop_ui_rst_axi_prev <= pop_ui_rst_axi;
  pop_ui_x_incr_axi_prev <= pop_ui_x_incr_axi;
  pop_ui_y_incr_axi_prev <= pop_ui_y_incr_axi;
end

assign pop_ui_raddr = {pop_ui_y_axi, pop_ui_x_axi};
// -------------------------------------------------------------------------------------------------

// Mix UI (75%) with preview (25%) (sequential).
// -------------------------------------------------------------------------------------------------
reg [9:0] R_mix_10b;
reg [9:0] G_mix_10b;
reg [9:0] B_mix_10b;
reg [9:0] UI_mix_10b;
always @(*)
begin
  if (in_top_ui && top_ui_enabled)
  begin
    R_mix_10b <= {2'b00, R_mix_8b};
    G_mix_10b <= {2'b00, G_mix_8b};
    B_mix_10b <= {2'b00, B_mix_8b};
    UI_mix_10b <= {1'b0, top_ui_8b, 1'b0} + {2'b00, top_ui_8b};
  end
 else if(in_bot_ui && bot_ui_enabled)
 begin
    R_mix_10b <= {2'b00, R_mix_8b};
    G_mix_10b <= {2'b00, G_mix_8b};
    B_mix_10b <= {2'b00, B_mix_8b};
    UI_mix_10b <= {1'b0, bot_ui_8b, 1'b0} + {2'b00, bot_ui_8b};
  end
  else if(in_pop_ui && pop_ui_enabled)
  begin
    R_mix_10b <= {2'b00, R_mix_8b};
    G_mix_10b <= {2'b00, G_mix_8b};
    B_mix_10b <= {2'b00, B_mix_8b};
    UI_mix_10b <= {1'b0, pop_ui_8b, 1'b0} + {2'b00, pop_ui_8b};
  end
  else
  begin
    R_mix_10b <= {R_mix_8b, 2'b00};
    G_mix_10b <= {G_mix_8b, 2'b00};
    B_mix_10b <= {B_mix_8b, 2'b00};
    UI_mix_10b <= 10'b0000000000;
  end
end

always @(posedge hdmi_clk)
begin
  R_out <= (R_mix_10b + UI_mix_10b) >> 2;
  G_out <= (G_mix_10b + UI_mix_10b) >> 2;
  B_out <= (B_mix_10b + UI_mix_10b) >> 2;
end
// -------------------------------------------------------------------------------------------------

endmodule
