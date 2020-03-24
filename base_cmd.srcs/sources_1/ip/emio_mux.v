`timescale 1ns / 1ps
/*
=================================================================================
emio_mux.v

Multiplexer for EMIO signals to the four user-accessible isolated GPIOs.

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

module emio_mux
(
  // EMIO Side
  input wire emio_uart0_txd,
  input wire [15:0] emio_gpio_o,
  output wire emio_uart0_rxd,
  output wire [15:0] emio_gpio_i,
  
  // GPIO Side
  input wire [1:0] gpi,
  output wire [1:0] gpo
);

// Drive unused EMIO inputs to zero.
assign emio_gpio_i[15:4] = 12'h000;
assign emio_gpio_i[1:0] = 2'b00;

// Input splitter.
assign emio_gpio_i[3:2] = gpi[1:0];
assign emio_uart0_rxd = gpi[0];

// Output 0 switch based on EMIO 6.
wire gpio_sel_uart0 = emio_gpio_o[6];
assign gpo[0] = gpio_sel_uart0 ? emio_uart0_txd : emio_gpio_o[0];

// Output 1 always GPO.
assign gpo[1] = emio_gpio_o[1];

endmodule
