`timescale 1 ns / 1 ps
/*
===================================================================================
axi_slave_uram.v
Wraps a single URAM for R/W access through an AXI-Lite slave peripheral, with
independent R access on a separate port for the PL module.

Port A: AXI Read/Write (one Read or one Write per clock)
Port B: PL Module Read (one Read per clock)

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

module axi_slave_uram
(
  input wire s_axi_aclk,
  
  input wire axi_wen,
  input wire [14:0] axi_waddr,
  input wire [31:0] axi_wdata,
  input wire [14:0] axi_raddr,
  output wire [31:0] axi_rdata,
  
  input wire [11:0] mod_raddr,
  output wire [63:0] mod_rdata
);

// Port A read/write switch.
wire uram_rdb_wr_a = axi_wen;
wire [11:0] uram_addr_a = axi_wen ? axi_waddr[14:3] : axi_raddr[14:3];

// Port A 32-bit to 64-bit write conversion.
wire [63:0] uram_din_a = axi_waddr[2] ? {axi_wdata, 32'h0} : {32'h0, axi_wdata};
wire [8:0] uram_bwe_a = axi_waddr[2] ? 9'b111110000 : 9'b100001111;

// Port A 64-bit to 32-bit read conversion.
wire [63:0] uram_dout_a;
assign axi_rdata = axi_raddr[2] ? uram_dout_a[63:32] : uram_dout_a[31:0];

// URAM Instanciation (from template).
URAM288_BASE 
#(
  .AUTO_SLEEP_LATENCY(8),            // Latency requirement to enter sleep mode
  .AVG_CONS_INACTIVE_CYCLES(10),     // Average concecutive inactive cycles when is SLEEP mode for power estimation
  .BWE_MODE_A("PARITY_INTERLEAVED"), // Port A Byte write control
  .BWE_MODE_B("PARITY_INTERLEAVED"), // Port B Byte write control
  .EN_AUTO_SLEEP_MODE("FALSE"),      // Enable to automatically enter sleep mode
  .EN_ECC_RD_A("FALSE"),             // Port A ECC encoder
  .EN_ECC_RD_B("FALSE"),             // Port B ECC encoder
  .EN_ECC_WR_A("FALSE"),             // Port A ECC decoder
  .EN_ECC_WR_B("FALSE"),             // Port B ECC decoder
  .IREG_PRE_A("FALSE"),              // Optional Port A input pipeline registers
  .IREG_PRE_B("FALSE"),              // Optional Port B input pipeline registers
  .IS_CLK_INVERTED(1'b0),            // Optional inverter for CLK
  .IS_EN_A_INVERTED(1'b0),           // Optional inverter for Port A enable
  .IS_EN_B_INVERTED(1'b0),           // Optional inverter for Port B enable
  .IS_RDB_WR_A_INVERTED(1'b0),       // Optional inverter for Port A read/write select
  .IS_RDB_WR_B_INVERTED(1'b0),       // Optional inverter for Port B read/write select
  .IS_RST_A_INVERTED(1'b0),          // Optional inverter for Port A reset
  .IS_RST_B_INVERTED(1'b0),          // Optional inverter for Port B reset
  .OREG_A("FALSE"),                   // Optional Port A output pipeline registers
  .OREG_B("FALSE"),                   // Optional Port B output pipeline registers
  .OREG_ECC_A("FALSE"),              // Port A ECC decoder output
  .OREG_ECC_B("FALSE"),              // Port B output ECC decoder
  .RST_MODE_A("SYNC"),               // Port A reset mode
  .RST_MODE_B("SYNC"),               // Port B reset mode
  .USE_EXT_CE_A("FALSE"),            // Enable Port A external CE inputs for output registers
  .USE_EXT_CE_B("FALSE")             // Enable Port B external CE inputs for output registers
)
uram_mem 
(
  .CLK(s_axi_aclk),                    // 1-bit input: Clock source
  
  // Port A: AXI Read/Write
  .EN_A(1'b1),                         // 1-bit input: Port A enable
  .RDB_WR_A(uram_rdb_wr_a),            // 1-bit input: Port A read/write select
  .ADDR_A(uram_addr_a),                // 23-bit input: Port A address
  .BWE_A(uram_bwe_a),                  // 9-bit input: Port A Byte-write enable
  .DIN_A(uram_din_a),                  // 72-bit input: Port A write data input
  .DOUT_A(uram_dout_a),                // 72-bit output: Port A read data output

  // Port B: PL Module Read
  .EN_B(1'b1),                         // 1-bit input: Port B enable
  .RDB_WR_B(1'b0),                     // 1-bit input: Port B read/write select
  .ADDR_B(mod_raddr),                  // 23-bit input: Port B address
  .BWE_B(),                            // 9-bit input: Port B Byte-write enable
  .DIN_B(),                            // 72-bit input: Port B write data input
  .DOUT_B(mod_rdata)                   // 72-bit output: Port B read data output
);

endmodule
