`timescale 1ns / 1ps
/* =================================================================================================
Discrete Wavelet Transform 2/6 Core, Horizontal Third Stage (dwt26_h3.v)

Lifting core for 2/6 DWT in the horizontal dimension (across a row) on the third stage.
For a pair of pixels Xeven(n), Xodd(n), the 2/6 DWT lifting steps are:
    Local Difference:                 D(n) = Xodd(n) - Xeven(n)
    Local and Output Sum:   Sout(n) = S(n) = Xeven(n) + (D(n) >>> 1)
    Output Difference:      Dout(n) = D(n) + ((S(n-1) - S(n+1) + 2) >>> 2)

Because of the S(n+1) term in Dout(n), the causal implementation has a one pixel pair delay.

All operations and operands are signed 16-bit unless otherwise noted.
================================================================================================= */


module dwt26_h3
(
    input wire px_clk,                 // Pixel clock.
    input wire [5:0] px_idx,           // 64 pixel pairs per column per row for w = 4096px.
    input wire px_idx_updated,         // Flag indicating the px_idx has been updated.
    input wire signed [15:0] X_even,   // 16b even pixel data.
    input wire signed [15:0] X_odd,    // 16b odd pixel data.
    
    // Local sum and difference of pixel pairs 0 and 1 from the core "to the right".
    input wire signed [15:0] S_pp0_fromR,
    input wire signed [15:0] D_pp0_fromR,
    input wire signed [15:0] S_pp1_fromR,
    
    // Local sum and difference of pixel pairs 0 and 1 to the core "to the left".
    output reg signed [15:0] S_pp0_toL,
    output reg signed [15:0] D_pp0_toL,
    output reg signed [15:0] S_pp1_toL,
    
    // Output sum and difference for the immediate pixel pair.
    output reg signed [15:0] S_out,
    output reg signed [15:0] D_out
);

// Additional internal storage elements.
reg signed [15:0] S_0;      // Local sum of pixel pair N.
reg signed [15:0] D_0;      // Local difference of pixel pair N.
reg signed [15:0] S_1;      // Local sum of pixel pair N-1.
reg signed [15:0] D_1;      // Local difference of pixel pair N-1.
reg signed [15:0] S_2;      // Local sum of pixel pair N-2.

// Total Storage: 10 x 16b = 160b.

// Create signals for whether the next pixel pair out is the first/last of a row.
// TO-DO: These are offset for latency through the shift stages. Any way to make it easier to follow?
wire last_out;
assign last_out = (px_idx == 5'b00001);
wire first_out;
assign first_out = (px_idx == 5'b00010);

// Combinational logic for local sum/difference.
wire signed [15:0] D_0_next;
assign D_0_next = X_odd - X_even;
wire signed [15:0] S_0_next;
assign S_0_next = X_even + (D_0_next >>> 1);

// Combinational logic for output sum/difference.
wire signed [15:0] S_0_temp;
assign S_0_temp = first_out ? S_pp1_fromR : (last_out ? S_pp0_fromR : S_0);
wire signed [15:0] D_1_temp;
assign D_1_temp = first_out ? D_pp0_fromR : D_1;
wire signed [15:0] S_out_next;
assign S_out_next = first_out ? S_pp0_fromR : S_1;
wire signed [15:0] D_out_next;
assign D_out_next = D_1_temp + ((S_2 - S_0_temp + 16'sh0002) >>> 2);

// Sequential logic.
always @(posedge px_clk)
begin
    if (px_idx_updated)
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
end

endmodule

