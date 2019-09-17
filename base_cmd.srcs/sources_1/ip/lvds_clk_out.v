`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/16/2019 03:58:47 PM
// Design Name: 
// Module Name: lvds_clk_out
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lvds_clk_out(
  input lvds_clk_en,
  input lvds_pll_locked,
  input gt_clk_in_p,
  input gt_clk_in_n,
  input pll2lvds_clk,
  output gt2pll_clk,
  output lvds_clk_out_p,
  output lvds_clk_out_n
  );
  
  wire clk_out;
  wire gt_refclk;
  wire clk_in;
  wire oddr_en;
  
  IBUFDS_GTE4 #(
    .REFCLK_EN_TX_PATH(1'b0),   // Refer to Transceiver User Guide
    .REFCLK_HROW_CK_SEL(2'b00), // Refer to Transceiver User Guide
    .REFCLK_ICNTL_RX(2'b00)     // Refer to Transceiver User Guide
  )
  IBUFDS_GTE4_inst (
    .O(gt_refclk),      // 1-bit output: Refer to Transceiver User Guide
    .ODIV2(clk_in),     // 1-bit output: Refer to Transceiver User Guide
    .CEB(1'b0),         // 1-bit input: Refer to Transceiver User Guide
    .I(gt_clk_in_p),    // 1-bit input: Refer to Transceiver User Guide
    .IB(gt_clk_in_n)    // 1-bit input: Refer to Transceiver User Guide
  );
  
  BUFG_GT BUFG_GT_inst (
    .O(gt2pll_clk),    // 1-bit output: Buffer
    .CE(1'b1),         // 1-bit input: Buffer enable
    .CEMASK(1'b0),     // 1-bit input: CE Mask
    .CLR(1'b0),        // 1-bit input: Asynchronous clear
    .CLRMASK(1'b0),    // 1-bit input: CLR Mask
    .DIV(3'b000),      // 3-bit input: Dynamic divide Value
    .I(clk_in)         // 1-bit input: Buffer
   ); 

  assign oddr_en = lvds_clk_en & lvds_pll_locked;
  
  ODDRE1 ODDRE1_inst (
    .Q(clk_out),        // 1-bit output: Data output to IOB
    .C(pll2lvds_clk),   // 1-bit input: High-speed clock input
    .D1(1'b0),          // 1-bit input: Parallel data input 1
    .D2(oddr_en),       // 1-bit input: Parallel data input 2
    .SR(1'b0)           // 1-bit input: Active High Async Reset
  );
  
  OBUFDS OBUFDS_inst (
      .O(lvds_clk_out_p),   // 1-bit output: Diff_p output (connect directly to top-level port)
      .OB(lvds_clk_out_n),  // 1-bit output: Diff_n output (connect directly to top-level port)
      .I(clk_out)           // 1-bit input: Buffer input
   );
    
endmodule
