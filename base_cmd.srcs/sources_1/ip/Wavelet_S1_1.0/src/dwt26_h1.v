`timescale 1ns / 1ps
/* =================================================================================================
Discrete Wavelet Transform 2/6 Core, Horizontal First Stage (dwt26_h1.v)

Lifting core for 2/6 DWT in the horizontal dimension (across a row) on the first stage.
For a pair of pixels Xeven(n), Xodd(n), the 2/6 DWT lifting steps are:
    Local Difference:                 D(n) = Xodd(n) - Xeven(n)
    Local and Output Sum:   Sout(n) = S(n) = Xeven(n) + (D(n) >>> 1)
    Output Difference:      Dout(n) = D(n) + ((S(n-1) - S(n+1) + 2) >>> 2)

Because of the S(n+1) term in Dout(n), the causal implementation has a one pixel pair delay.

All operations and operands are signed 16-bit unless otherwise noted.
================================================================================================= */

// Color field enumeration.
`define COLOR_G1 2'b00
`define COLOR_R1 2'b01
`define COLOR_B1 2'b10
`define COLOR_G2 2'b11

module dwt26_h1
#(
    parameter integer PX_MATH_WIDTH = 16,
    parameter [1:0] COLOR = `COLOR_G1,
    parameter SS_ODD_ROW = 0
)
(
    input wire SS,              // 2K Mode switch.
    
    input wire px_clk,          // Pixel clock.
    input wire px_dval,         // Pixel data valid flag.
    input wire [6:0] px_idx,    // 128 pixels per column per row for w = 4096px.
    input wire [15:0] px_data,  // 16b pixel data.
    
    // Local sum and difference of pixel pairs 0 and 1 from the core "to the right".
    input wire signed [(PX_MATH_WIDTH-1):0] S_pp0_fromR,
    input wire signed [(PX_MATH_WIDTH-1):0] D_pp0_fromR,
    input wire signed [(PX_MATH_WIDTH-1):0] S_pp1_fromR,
    
    // Local sum and difference of pixel pairs 0 and 1 to the core "to the left".
    output reg signed [(PX_MATH_WIDTH-1):0] S_pp0_toL,
    output reg signed [(PX_MATH_WIDTH-1):0] D_pp0_toL,
    output reg signed [(PX_MATH_WIDTH-1):0] S_pp1_toL,
    
    // Output sum and difference for the immediate pixel pair.
    output reg signed [(PX_MATH_WIDTH-1):0] S_out,
    output reg signed [(PX_MATH_WIDTH-1):0] D_out
);

// Additional internal storage elements.
reg signed [(PX_MATH_WIDTH-1):0] X_even;   // Latest even input pixel.
reg signed [(PX_MATH_WIDTH-1):0] S_0;      // Local sum of pixel pair N.
reg signed [(PX_MATH_WIDTH-1):0] D_0;      // Local difference of pixel pair N.
reg signed [(PX_MATH_WIDTH-1):0] S_1;      // Local sum of pixel pair N-1.
reg signed [(PX_MATH_WIDTH-1):0] D_1;      // Local difference of pixel pair N-1.
reg signed [(PX_MATH_WIDTH-1):0] S_2;      // Local sum of pixel pair N-2.

// Total Storage: 11 x 16b = 176b.

wire signed [(PX_MATH_WIDTH-1):0] X_odd;    // Latest odd input pixel.
assign X_odd = px_data;

// Create an enable signal based on this core's color and the current pixel index.
//   G1 and B1 are enabled on globally even pixels.
//   R1 and G2 are enabled on globally odd pixels.
wire color_en;
assign color_en = (px_idx[0] == COLOR[0]);

// Create an enable signal based on this core's subsampled row assignement, if in 2K Mode.
wire ss_row_en;
assign ss_row_en = SS ? (px_idx[1] ^ SS_ODD_ROW) : 1'b1;
    
// Create a signal for whether a pixel is even or odd within a given color field.
// 4K Mode:
//   Global pixels {0, 1, 4, 5, ...} are locally even.
//   Global pixels {2, 3, 6, 7, ...} are locally odd.
// 2K Mode:  
//   Global pixels {0, 1, 2, 3, 8, 9, 10, 11, ...} are locally even.
//   Global pixels {4, 5, 6, 7, 12, 13, 14, 15...} are locally odd.
wire locally_odd;
assign locally_odd = SS ? px_idx[2] : px_idx[1];

// Create signals for whether the next pixel pair out is the first/last of a row.
// TO-DO: These are offset for latency through the shift stages. Any way to make it easier to follow?
wire last_out;
assign last_out = SS ? (px_idx[6:3] == 4'b0001) : (px_idx[6:2] == 5'b00001);
wire first_out;
assign first_out = SS ? (px_idx[6:3] == 4'b0010) : (px_idx[6:2] == 5'b00010);

// Combinational logic for local sum/difference.
wire signed [(PX_MATH_WIDTH-1):0] D_0_next;
assign D_0_next = X_odd - X_even;
wire signed [(PX_MATH_WIDTH-1):0] S_0_next;
assign S_0_next = X_even + (D_0_next >>> 1);

// Combinational logic for output sum/difference.
wire signed [(PX_MATH_WIDTH-1):0] S_0_temp;
assign S_0_temp = first_out ? S_pp1_fromR : (last_out ? S_pp0_fromR : S_0);
wire signed [(PX_MATH_WIDTH-1):0] D_1_temp;
assign D_1_temp = first_out ? D_pp0_fromR : D_1;
wire signed [(PX_MATH_WIDTH-1):0] S_out_next;
assign S_out_next = first_out ? S_pp0_fromR : S_1;
wire signed [(PX_MATH_WIDTH-1):0] D_out_next;
assign D_out_next = D_1_temp + ((S_2 - S_0_temp + 16'sh0002) >>> 2);

// Sequential logic.
always @(posedge px_clk)
begin
    if (px_dval & color_en & ss_row_en)
    begin
        if (locally_odd)
        begin
            if (first_out)
            begin
                // Latches new data for the core "to the left" to use next time around.
                S_pp0_toL <= S_1;
                D_pp0_toL <= D_1;
                S_pp1_toL <= S_0;
            end
            
            // Always-on normal shifts.
            S_out <= S_out_next;
            D_out <= D_out_next;
            S_2 <= S_1;
            S_1 <= S_0;
            D_1 <= D_0;
            S_0 <= S_0_next;
            D_0 <= D_0_next;
        end
        else
        begin
            X_even <= px_data;
        end
    end
end

endmodule
