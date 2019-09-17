`timescale 1ns / 1ps
// =================================================================================
// lvds_clk_in.v
// CMV12000 LVDS clock input and distribution.
// =================================================================================

module lvds_clk_in
(
    input lvds_clk_p,
    input lvds_clk_n,
    output lvds_clk,
    output lvds_clk_div4,
    output px_clk
);

// Input Buffer
wire lvds_clk_ibuf;
IBUFDS IBUFDS_lvds_clk_ibuf
(
    .O(lvds_clk_ibuf),
    .I(lvds_clk_p),
    .IB(lvds_clk_n)
);

// LVDS Clock Buffer (300MHz)
BUFGCE_DIV 
#(
    .BUFGCE_DIVIDE(1)
)
BUFGCE_DIV_lvds_rx_clk_in_buf
(
    .O(lvds_clk),
    .CE(1'b1),
    .CLR(1'b0),
    .I(lvds_clk_ibuf)
);

// Deserializer Clock Buffer (75MHz)
BUFGCE_DIV 
#(
    .BUFGCE_DIVIDE(4)
)
BUFGCE_DIV_lvds_clk_div4
(
    .O(lvds_clk_div4),
    .CE(1'b1),
    .CLR(1'b0),
    .I(lvds_clk_ibuf)
);

// 10-bit Pixel Clock Buffer (60MHz)
BUFGCE_DIV 
#(
    .BUFGCE_DIVIDE(5)
)
BUFGCE_DIV_pix_clk_buf(
    .O(px_clk),
    .CE(1'b1),
    .CLR(1'b0),
    .I(lvds_clk_ibuf)
);

endmodule
