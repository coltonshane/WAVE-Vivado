`timescale 1ns / 1ps
// =================================================================================
// px_in.v
// CMV12000 LVDS pixel data input for one channel.
// =================================================================================

module px_in 
#(
    parameter LVDS_INVERTED = 0
)
(
    input wire px_in_rst,

    input wire lvds_in_p,
    input wire lvds_in_n,
    input wire lvds_clk,
    input wire lvds_clk_div4,
    input wire px_clk,
    input wire [8:0] delay_target,
    input wire [3:0] bitslip,           // Valid: 0 to 9
    input wire [1:0] px_phase,          // Valid: 0 to 3
    
    output reg [9:0] px_out,
    output wire [8:0] idelay_actual,
    output wire [8:0] odelay_actual
);

// Input buffer, optionally inverted.
// ---------------------------------------------------------------------------------
wire lvds_in_buf_p;
wire lvds_in_buf_n;
wire lvds_in_buf;
assign lvds_in_buf = (LVDS_INVERTED == 0) ? lvds_in_buf_p : lvds_in_buf_n;

IBUFDS_DIFF_OUT IBUFDS_DIFF_OUT_lvds_in
(
    .O(lvds_in_buf_p),
    .OB(lvds_in_buf_n),
    .I(lvds_in_p),
    .IB(lvds_in_n)
);
// ---------------------------------------------------------------------------------

// Cascaded input delay (IDELAYE3 + ODELAYE3).
// ---------------------------------------------------------------------------------
wire lvds_in_casc;
wire lvds_in_casc_return;
wire lvds_in_delayed;

reg idelay_ce;
reg odelay_ce;
reg[3:0] delay_update_wait;

IDELAYE3 
#(
    .CASCADE("MASTER"),
    .DELAY_FORMAT("COUNT"),
    .DELAY_SRC("IDATAIN"),
    .DELAY_TYPE("VARIABLE"),
    .DELAY_VALUE(0),
    .IS_CLK_INVERTED(1'b0),
    .IS_RST_INVERTED(1'b0),
    .REFCLK_FREQUENCY(300.0),
    .SIM_DEVICE("ULTRASCALE_PLUS"),
    .UPDATE_MODE("ASYNC")
)
IDELAYE3_lvds_in
(
    .CASC_OUT(lvds_in_casc),
    .CNTVALUEOUT(idelay_actual),
    .DATAOUT(lvds_in_delayed),
    .CASC_IN(1'b0),
    .CASC_RETURN(lvds_in_casc_return),
    .CE(idelay_ce),
    .CLK(lvds_clk_div4),
    .CNTVALUEIN(9'b000000000),
    .DATAIN(1'b0),
    .EN_VTC(1'b0),
    .IDATAIN(lvds_in_buf),
    .INC(1'b1),                     // Always seeks in the positive direction.
    .LOAD(1'b0),
    .RST(px_in_rst)
);
ODELAYE3 
#(
    .CASCADE("SLAVE_END"),
    .DELAY_FORMAT("COUNT"),
    .DELAY_TYPE("VARIABLE"),
    .DELAY_VALUE(0),
    .IS_CLK_INVERTED(1'b0),
    .IS_RST_INVERTED(1'b0),
    .REFCLK_FREQUENCY(300.0),
    .SIM_DEVICE("ULTRASCALE_PLUS"),
    .UPDATE_MODE("ASYNC")
)
ODELAYE3_lvds_in
(
    .CASC_OUT(),
    .CNTVALUEOUT(odelay_actual),
    .DATAOUT(lvds_in_casc_return),
    .CASC_IN(lvds_in_casc),
    .CASC_RETURN(1'b0),
    .CE(odelay_ce),
    .CLK(lvds_clk_div4),
    .CNTVALUEIN(9'b000000000),
    .EN_VTC(1'b0),
    .INC(1'b1),                     // Always seeks in the positive direction.
    .LOAD(1'b0),
    .ODATAIN(1'b0),
    .RST(px_in_rst)
);

// Update delay CE signals on negedge since the delays themselves update on posedge.
always @(negedge lvds_clk_div4)
begin
    if(delay_update_wait > 4'h0)
    begin
        // Waiting to allow tap count outputs to update.
        idelay_ce <= 1'b0;
        odelay_ce <= 1'b0;
        delay_update_wait <= delay_update_wait - 1;
    end
    else
    begin
        if(idelay_actual != delay_target)
        begin
           idelay_ce <= 1'b1; 
           delay_update_wait <= 4'hF;
        end
        else if(odelay_actual != delay_target)
        begin
            odelay_ce <= 1'b1; 
            delay_update_wait <= 4'hF;
        end
    end
 end
// ---------------------------------------------------------------------------------

// 1:8 deserializer, bit slip, and 8:10 gearbox.
// ---------------------------------------------------------------------------------

wire [7:0] deser_0;             // Deserialized byte at t.
reg [7:0] deser_1;              // Deserialized byte at t-1.
reg [7:0] deser_2;              // Deserialized byte at t-2.
    
// Make a 24-bit view of the deserialized bytes from t to t-2.
wire [23:0] deser_012;
assign deser_012[23:16] = deser_0;
assign deser_012[15:8] = deser_1;
assign deser_012[7:0] = deser_2;
    
reg [7:0] slipped_0;            // Bitslipped byte at t.
reg [7:0] slipped_1;            // Bitslipped byte at t-1.
    
// Make a 16-bit view of the slipped bytes from t to t-1.
wire [15:0] slipped_01;
assign slipped_01[15:8] = slipped_0;
assign slipped_01[7:0] = slipped_1;

ISERDESE3 
#(
    .DATA_WIDTH(8),
    .FIFO_ENABLE("FALSE"),
    .FIFO_SYNC_MODE("FALSE"),
    .IS_CLK_B_INVERTED(1'b1),           // Set to 1'b1 to use the same global clock on CLK and CLK_B.
    .IS_CLK_INVERTED(1'b0),
    .IS_RST_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE_PLUS")
)
ISERDESE3_deser
(
    .FIFO_EMPTY(),
    .INTERNAL_DIVCLK(),

    .Q(deser_0),
    .CLK(lvds_clk),
    .CLKDIV(lvds_clk_div4),
    .CLK_B(lvds_clk),
    .D(lvds_in_delayed),
    .FIFO_RD_CLK(1'b0),
    .FIFO_RD_EN(1'b0),
    .RST(px_in_rst)
);
    
// Shift and bitslip.
always @(posedge lvds_clk_div4)
begin
    deser_2 <= deser_1;
    deser_1 <= deser_0;
    
    slipped_1 <= slipped_0;
    slipped_0 <= deser_012[bitslip +: 8];    
end

// 10-bit conversion gearbox.
reg [1:0] px_state;
wire [1:0] px_state_phased;
assign px_state_phased = px_state + px_phase;
always @(posedge px_clk)
begin
    case (px_state_phased)
        2'b00: px_out <= slipped_01[9:0];
        2'b01: px_out <= slipped_01[11:2];
        2'b10: px_out <= slipped_01[13:4];
        2'b11: px_out <= slipped_01[15:6];
    endcase
    px_state <= (px_state + 2'b01);
end

// ---------------------------------------------------------------------------------
    
endmodule
