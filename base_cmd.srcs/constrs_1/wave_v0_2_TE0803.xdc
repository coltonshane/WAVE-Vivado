# Constraints for WAVE v0.2 w/ TE0803 Module

# Quad 224 GT Clock Input from clock generator (100MHz).
set_property PACKAGE_PIN V6 [get_ports gt_clk_in_p]
set_property PACKAGE_PIN V5 [get_ports gt_clk_in_n]
create_clock -name gt_clk_in -period 10.000 [get_ports gt_clk_in_p]

# SSD PCI Express reset B25_L4_N (perst)
set_property PACKAGE_PIN H12 [get_ports {perst[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {perst[0]}]

# MGT locations
# SSD (PCIe lanes 0-3) are connected to MGT bank 224 (X0Y4-X0Y7)
set_property LOC GTHE4_CHANNEL_X0Y4 [get_cells {*_i/xdma_0/inst/pcie4_ip_i/inst/gt_top_i/diablo_gt.diablo_gt_phy_wrapper/gt_wizard.gtwizard_top_i/*_xdma_0_0_pcie4_ip_gt_i/inst/gen_gtwizard_gthe4_top.*_xdma_0_0_pcie4_ip_gt_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[3].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X0Y5 [get_cells {*_i/xdma_0/inst/pcie4_ip_i/inst/gt_top_i/diablo_gt.diablo_gt_phy_wrapper/gt_wizard.gtwizard_top_i/*_xdma_0_0_pcie4_ip_gt_i/inst/gen_gtwizard_gthe4_top.*_xdma_0_0_pcie4_ip_gt_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[3].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[1].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X0Y6 [get_cells {*_i/xdma_0/inst/pcie4_ip_i/inst/gt_top_i/diablo_gt.diablo_gt_phy_wrapper/gt_wizard.gtwizard_top_i/*_xdma_0_0_pcie4_ip_gt_i/inst/gen_gtwizard_gthe4_top.*_xdma_0_0_pcie4_ip_gt_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[3].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[2].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X0Y7 [get_cells {*_i/xdma_0/inst/pcie4_ip_i/inst/gt_top_i/diablo_gt.diablo_gt_phy_wrapper/gt_wizard.gtwizard_top_i/*_xdma_0_0_pcie4_ip_gt_i/inst/gen_gtwizard_gthe4_top.*_xdma_0_0_pcie4_ip_gt_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[3].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[3].GTHE4_CHANNEL_PRIM_INST}]

# Transceivers for SSD are best aligned with PCIE_X0Y1
set_property LOC PCIE40E4_X0Y1 [get_cells *_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_e4_inst] 

# LVDS Clock Output to CMV12000 (600MHz).
set_property PACKAGE_PIN AD5 [get_ports lvds_clk_out_p]
set_property IOSTANDARD LVDS [get_ports lvds_clk_out_p]
set_property PACKAGE_PIN AD4 [get_ports lvds_clk_out_n]
set_property IOSTANDARD LVDS [get_ports lvds_clk_out_n]

# Temperature Sensor Clock Output to CMV12000 (60MHz).
set_property PACKAGE_PIN E10 [get_ports ts_clk]
set_property IOSTANDARD LVCMOS33 [get_ports ts_clk]

# LVDS Clock Input from CMV12000 (300MHz).
set_property PACKAGE_PIN L7 [get_ports lvds_clk_in_p]
set_property IOSTANDARD LVDS [get_ports lvds_clk_in_p]
set_property PACKAGE_PIN L6 [get_ports lvds_clk_in_n]
set_property IOSTANDARD LVDS [get_ports lvds_clk_in_n]
create_clock -name lvds_clk_in -period 3.333 [get_ports lvds_clk_in_p] 

# Separate LVDS and pixel clock domain from AXI clock domain in timing analysis.
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks clk_pl_0] -group [get_clocks -include_generated_clocks lvds_clk_in]

# GPIO incl. UART0 to terminal (3.3V).
set_property PACKAGE_PIN J10 [get_ports {gpo[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpo[0]}]
set_property PACKAGE_PIN J11 [get_ports {gpo[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpo[1]}]
set_property PACKAGE_PIN F10 [get_ports {gpi[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpi[0]}]
set_property PACKAGE_PIN G11 [get_ports {gpi[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpi[1]}]

# UART1 EMIO to supervisor (3.3V).
set_property PACKAGE_PIN K12 [get_ports uart1_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart1_txd]
set_property PACKAGE_PIN K13 [get_ports uart1_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart1_rxd]

# HDMI Red Channel
set_property PACKAGE_PIN E14 [get_ports hdmi_r[7]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[7]]
set_property PACKAGE_PIN E13 [get_ports hdmi_r[6]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[6]]
set_property PACKAGE_PIN K14 [get_ports hdmi_r[5]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[5]]
set_property PACKAGE_PIN J14 [get_ports hdmi_r[4]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[4]]
set_property PACKAGE_PIN B15 [get_ports hdmi_r[3]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[3]]
set_property PACKAGE_PIN A15 [get_ports hdmi_r[2]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[2]]
set_property PACKAGE_PIN G13 [get_ports hdmi_r[1]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[1]]
set_property PACKAGE_PIN F13 [get_ports hdmi_r[0]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_r[0]]

# HDMI Green Channel
set_property PACKAGE_PIN B14 [get_ports hdmi_g[7]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[7]]
set_property PACKAGE_PIN A14 [get_ports hdmi_g[6]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[6]]
set_property PACKAGE_PIN B13 [get_ports hdmi_g[5]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[5]]
set_property PACKAGE_PIN A13 [get_ports hdmi_g[4]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[4]]
set_property PACKAGE_PIN C14 [get_ports hdmi_g[3]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[3]]
set_property PACKAGE_PIN D14 [get_ports hdmi_g[2]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[2]]
set_property PACKAGE_PIN D15 [get_ports hdmi_g[1]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[1]]
set_property PACKAGE_PIN C13 [get_ports hdmi_g[0]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_g[0]]

# HDMI Blue Channel
set_property PACKAGE_PIN G15 [get_ports hdmi_b[7]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[7]]
set_property PACKAGE_PIN G14 [get_ports hdmi_b[6]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[6]]
set_property PACKAGE_PIN H13 [get_ports hdmi_b[5]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[5]]
set_property PACKAGE_PIN H14 [get_ports hdmi_b[4]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[4]]
set_property PACKAGE_PIN L13 [get_ports hdmi_b[3]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[3]]
set_property PACKAGE_PIN L14 [get_ports hdmi_b[2]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[2]]
set_property PACKAGE_PIN E15 [get_ports hdmi_b[1]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[1]]
set_property PACKAGE_PIN F15 [get_ports hdmi_b[0]]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_b[0]]

# HDMI Clock, HSYNC, VSYNC, DE
set_property PACKAGE_PIN F11 [get_ports hdmi_clk]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_clk]
set_property PACKAGE_PIN A10 [get_ports hdmi_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_hsync]
set_property PACKAGE_PIN B11 [get_ports hdmi_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_vsync]
set_property PACKAGE_PIN F12 [get_ports hdmi_de]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_de]

# Separate HDMI clock domain from AXI clock domain in timing analysis.
set_clock_groups -asynchronous -group [get_clocks clk_pl_0] -group [get_clocks clk_out1_BoardSetupTest_clk_wiz_0_1_1]

# Additionally, set false (TO-DO: multi-cycle) paths between the 1DLUT URAMs and all other URAMs.
# The 1DLUT data do drive the 3DLUT address, but with an assumed latency of one hdmi_clk, which is 4x slower than the AXI clock.
set_false_path -from [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* && NAME =~ "*uram00*" }] -to [get_cells -hierarchical -filter { NAME !~ "*uram00*" && PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* }]
set_false_path -from [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* && NAME =~ "*uram01*" }] -to [get_cells -hierarchical -filter { NAME !~ "*uram01*" && PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* }]
set_false_path -from [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* && NAME =~ "*uram02*" }] -to [get_cells -hierarchical -filter { NAME !~ "*uram02*" && PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* }]
set_false_path -from [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* && NAME =~ "*uram03*" }] -to [get_cells -hierarchical -filter { NAME !~ "*uram03*" && PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* }]

# SPI0 EMIO to CMV12000 (3.3V).
set_property PACKAGE_PIN D10 [get_ports spi0_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi0_sclk]
set_property PACKAGE_PIN E12 [get_ports spi0_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi0_miso]
set_property PACKAGE_PIN D11 [get_ports spi0_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi0_mosi]
set_property PACKAGE_PIN G10 [get_ports spi0_en[0]]
set_property IOSTANDARD LVCMOS33 [get_ports spi0_en[0]]

# CMV control outputs (3.3V).
set_property PACKAGE_PIN C11 [get_ports {cmv_nrst[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cmv_nrst[0]}]
set_property PACKAGE_PIN D12 [get_ports {T_EXP1}]
set_property IOSTANDARD LVCMOS33 [get_ports {T_EXP1}]
set_property PACKAGE_PIN C12 [get_ports {T_EXP2}]
set_property IOSTANDARD LVCMOS33 [get_ports {T_EXP2}]
set_property PACKAGE_PIN B10 [get_ports {FRAME_REQ}]
set_property IOSTANDARD LVCMOS33 [get_ports {FRAME_REQ}]

# REC LED (3.3V)
set_property PACKAGE_PIN J12 [get_ports {rec_led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rec_led[0]}]

# Control channel from CMV12000. LVDS inverted.
set_property PACKAGE_PIN G1 [get_ports cmv_ctr_p]
set_property IOSTANDARD LVDS [get_ports cmv_ctr_p]
set_property DIFF_TERM TRUE [get_ports cmv_ctr_p]
set_property PACKAGE_PIN F1 [get_ports cmv_ctr_n]
set_property IOSTANDARD LVDS [get_ports cmv_ctr_n]
set_property DIFF_TERM TRUE [get_ports cmv_ctr_n]

# Channel 01 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN E1 [get_ports cmv_ch_p[0]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[0]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[0]]
set_property PACKAGE_PIN D1 [get_ports cmv_ch_n[0]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[0]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[0]]

# Channel 02 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN C1 [get_ports cmv_ch_p[1]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[1]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[1]]
set_property PACKAGE_PIN B1 [get_ports cmv_ch_n[1]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[1]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[1]]

# Channel 03 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN P7 [get_ports cmv_ch_p[2]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[2]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[2]]
set_property PACKAGE_PIN P6 [get_ports cmv_ch_n[2]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[2]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[2]]

# Channel 04 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN C3 [get_ports cmv_ch_p[3]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[3]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[3]]
set_property PACKAGE_PIN C2 [get_ports cmv_ch_n[3]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[3]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[3]]

# Channel 05 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN B3 [get_ports cmv_ch_p[4]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[4]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[4]]
set_property PACKAGE_PIN A3 [get_ports cmv_ch_n[4]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[4]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[4]]

# Channel 06 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN N7 [get_ports cmv_ch_p[5]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[5]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[5]]
set_property PACKAGE_PIN N6 [get_ports cmv_ch_n[5]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[5]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[5]]

# Channel 07 from CMV12000.
set_property PACKAGE_PIN AB6 [get_ports cmv_ch_p[6]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[6]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[6]]
set_property PACKAGE_PIN AC6 [get_ports cmv_ch_n[6]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[6]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[6]]

# Channel 08 from CMV12000.
set_property PACKAGE_PIN D4 [get_ports cmv_ch_p[7]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[7]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[7]]
set_property PACKAGE_PIN C4 [get_ports cmv_ch_n[7]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[7]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[7]]

# Channel 09 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN B4 [get_ports cmv_ch_p[8]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[8]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[8]]
set_property PACKAGE_PIN A4 [get_ports cmv_ch_n[8]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[8]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[8]]

# Channel 10 from CMV12000.
set_property PACKAGE_PIN J5 [get_ports cmv_ch_p[9]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[9]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[9]]
set_property PACKAGE_PIN J4 [get_ports cmv_ch_n[9]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[9]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[9]]

# Channel 11 from CMV12000.
set_property PACKAGE_PIN AB1 [get_ports cmv_ch_p[10]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[10]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[10]]
set_property PACKAGE_PIN AC1 [get_ports cmv_ch_n[10]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[10]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[10]]

# Channel 12 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN A2 [get_ports cmv_ch_p[11]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[11]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[11]]
set_property PACKAGE_PIN A1 [get_ports cmv_ch_n[11]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[11]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[11]]

# Channel 13 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN A7 [get_ports cmv_ch_p[12]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[12]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[12]]
set_property PACKAGE_PIN A6 [get_ports cmv_ch_n[12]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[12]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[12]]

# Channel 14 from CMV12000.
set_property PACKAGE_PIN B5 [get_ports cmv_ch_p[13]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[13]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[13]]
set_property PACKAGE_PIN A5 [get_ports cmv_ch_n[13]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[13]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[13]]

# Channel 15 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN L1 [get_ports cmv_ch_p[14]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[14]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[14]]
set_property PACKAGE_PIN K1 [get_ports cmv_ch_n[14]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[14]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[14]]

# Channel 16 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN A9 [get_ports cmv_ch_p[15]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[15]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[15]]
set_property PACKAGE_PIN A8 [get_ports cmv_ch_n[15]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[15]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[15]]

# Channel 17 from CMV12000.
set_property PACKAGE_PIN AB2 [get_ports cmv_ch_p[16]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[16]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[16]]
set_property PACKAGE_PIN AC2 [get_ports cmv_ch_n[16]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[16]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[16]]

# Channel 18 from CMV12000.
set_property PACKAGE_PIN F2 [get_ports cmv_ch_p[17]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[17]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[17]]
set_property PACKAGE_PIN E2 [get_ports cmv_ch_n[17]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[17]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[17]]

# Channel 19 from CMV12000.
set_property PACKAGE_PIN C8 [get_ports cmv_ch_p[18]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[18]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[18]]
set_property PACKAGE_PIN B8 [get_ports cmv_ch_n[18]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[18]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[18]]

# Channel 20 from CMV12000.
set_property PACKAGE_PIN J6 [get_ports cmv_ch_p[19]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[19]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[19]]
set_property PACKAGE_PIN H6 [get_ports cmv_ch_n[19]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[19]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[19]]

# Channel 21 from CMV12000.
set_property PACKAGE_PIN AB4 [get_ports cmv_ch_p[20]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[20]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[20]]
set_property PACKAGE_PIN AB3 [get_ports cmv_ch_n[20]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[20]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[20]]

# Channel 22 from CMV12000.
set_property PACKAGE_PIN D7 [get_ports cmv_ch_p[21]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[21]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[21]]
set_property PACKAGE_PIN D6 [get_ports cmv_ch_n[21]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[21]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[21]]

# Channel 23 from CMV12000.
set_property PACKAGE_PIN C6 [get_ports cmv_ch_p[22]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[22]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[22]]
set_property PACKAGE_PIN B6 [get_ports cmv_ch_n[22]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[22]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[22]]

# Channel 24 from CMV12000.
set_property PACKAGE_PIN J1 [get_ports cmv_ch_p[23]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[23]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[23]]
set_property PACKAGE_PIN H1 [get_ports cmv_ch_n[23]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[23]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[23]]

# Channel 25 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN E5 [get_ports cmv_ch_p[24]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[24]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[24]]
set_property PACKAGE_PIN D5 [get_ports cmv_ch_n[24]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[24]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[24]]

# Channel 26 from CMV12000.
set_property PACKAGE_PIN F8 [get_ports cmv_ch_p[25]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[25]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[25]]
set_property PACKAGE_PIN E8 [get_ports cmv_ch_n[25]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[25]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[25]]

# Channel 27 from CMV12000.
set_property PACKAGE_PIN E4 [get_ports cmv_ch_p[26]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[26]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[26]]
set_property PACKAGE_PIN E3 [get_ports cmv_ch_n[26]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[26]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[26]]

# Channel 28 from CMV12000.
set_property PACKAGE_PIN E9 [get_ports cmv_ch_p[27]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[27]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[27]]
set_property PACKAGE_PIN D9 [get_ports cmv_ch_n[27]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[27]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[27]]

# Channel 29 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN G8 [get_ports cmv_ch_p[28]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[28]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[28]]
set_property PACKAGE_PIN F7 [get_ports cmv_ch_n[28]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[28]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[28]]

# Channel 30 from CMV12000.
set_property PACKAGE_PIN G3 [get_ports cmv_ch_p[29]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[29]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[29]]
set_property PACKAGE_PIN F3 [get_ports cmv_ch_n[29]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[29]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[29]]

# Channel 31 from CMV12000.
set_property PACKAGE_PIN G6 [get_ports cmv_ch_p[30]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[30]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[30]]
set_property PACKAGE_PIN F6 [get_ports cmv_ch_n[30]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[30]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[30]]

# Channel 32 from CMV12000.
set_property PACKAGE_PIN G5 [get_ports cmv_ch_p[31]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[31]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[31]]
set_property PACKAGE_PIN F5 [get_ports cmv_ch_n[31]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[31]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[31]]

# Channel 33 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AE2 [get_ports cmv_ch_p[32]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[32]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[32]]
set_property PACKAGE_PIN AF2 [get_ports cmv_ch_n[32]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[32]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[32]]

# Channel 34 from CMV12000.
set_property PACKAGE_PIN N9 [get_ports cmv_ch_p[33]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[33]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[33]]
set_property PACKAGE_PIN N8 [get_ports cmv_ch_n[33]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[33]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[33]]

# Channel 35 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN R6 [get_ports cmv_ch_p[34]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[34]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[34]]
set_property PACKAGE_PIN T6 [get_ports cmv_ch_n[34]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[34]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[34]]

# Channel 36 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AC9 [get_ports cmv_ch_p[35]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[35]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[35]]
set_property PACKAGE_PIN AD9 [get_ports cmv_ch_n[35]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[35]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[35]]

# Channel 37 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN J7 [get_ports cmv_ch_p[36]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[36]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[36]]
set_property PACKAGE_PIN H7 [get_ports cmv_ch_n[36]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[36]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[36]]

# Channel 38 from CMV12000.
set_property PACKAGE_PIN K2 [get_ports cmv_ch_p[37]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[37]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[37]]
set_property PACKAGE_PIN J2 [get_ports cmv_ch_n[37]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[37]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[37]]

# Channel 39 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AD7 [get_ports cmv_ch_p[38]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[38]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[38]]
set_property PACKAGE_PIN AE7 [get_ports cmv_ch_n[38]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[38]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[38]]

# Channel 40 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AF1 [get_ports cmv_ch_p[39]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[39]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[39]]
set_property PACKAGE_PIN AG1 [get_ports cmv_ch_n[39]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[39]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[39]]

# Channel 41 from CMV12000.
set_property PACKAGE_PIN K9 [get_ports cmv_ch_p[40]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[40]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[40]]
set_property PACKAGE_PIN J9 [get_ports cmv_ch_n[40]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[40]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[40]]

# Channel 42 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN R8 [get_ports cmv_ch_p[41]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[41]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[41]]
set_property PACKAGE_PIN T8 [get_ports cmv_ch_n[41]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[41]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[41]]

# Channel 43 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AE9 [get_ports cmv_ch_p[42]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[42]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[42]]
set_property PACKAGE_PIN AE8 [get_ports cmv_ch_n[42]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[42]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[42]]

# Channel 44 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AE3 [get_ports cmv_ch_p[43]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[43]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[43]]
set_property PACKAGE_PIN AF3 [get_ports cmv_ch_n[43]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[43]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[43]]

# Channel 45 from CMV12000.
set_property PACKAGE_PIN H4 [get_ports cmv_ch_p[44]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[44]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[44]]
set_property PACKAGE_PIN H3 [get_ports cmv_ch_n[44]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[44]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[44]]

# Channel 46 from CMV12000.
set_property PACKAGE_PIN L3 [get_ports cmv_ch_p[45]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[45]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[45]]
set_property PACKAGE_PIN L2 [get_ports cmv_ch_n[45]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[45]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[45]]

# Channel 47 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AF7 [get_ports cmv_ch_p[46]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[46]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[46]]
set_property PACKAGE_PIN AF6 [get_ports cmv_ch_n[46]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[46]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[46]]

# Channel 48 from CMV12000.
set_property PACKAGE_PIN AH2 [get_ports cmv_ch_p[47]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[47]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[47]]
set_property PACKAGE_PIN AH1 [get_ports cmv_ch_n[47]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[47]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[47]]

# Channel 49 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN H9 [get_ports cmv_ch_p[48]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[48]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[48]]
set_property PACKAGE_PIN H8 [get_ports cmv_ch_n[48]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[48]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[48]]

# Channel 50 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AG9 [get_ports cmv_ch_p[49]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[49]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[49]]
set_property PACKAGE_PIN AH9 [get_ports cmv_ch_n[49]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[49]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[49]]

# Channel 51 from CMV12000.
set_property PACKAGE_PIN W8 [get_ports cmv_ch_p[50]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[50]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[50]]
set_property PACKAGE_PIN Y8 [get_ports cmv_ch_n[50]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[50]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[50]]

# Channel 52 from CMV12000.
set_property PACKAGE_PIN K8 [get_ports cmv_ch_p[51]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[51]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[51]]
set_property PACKAGE_PIN K7 [get_ports cmv_ch_n[51]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[51]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[51]]

# Channel 53 from CMV12000.
set_property PACKAGE_PIN AC4 [get_ports cmv_ch_p[52]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[52]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[52]]
set_property PACKAGE_PIN AC3 [get_ports cmv_ch_n[52]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[52]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[52]]

# Channel 54 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AF8 [get_ports cmv_ch_p[53]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[53]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[53]]
set_property PACKAGE_PIN AG8 [get_ports cmv_ch_n[53]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[53]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[53]]

# Channel 55 from CMV12000.
set_property PACKAGE_PIN K4 [get_ports cmv_ch_p[54]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[54]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[54]]
set_property PACKAGE_PIN K3 [get_ports cmv_ch_n[54]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[54]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[54]]

# Channel 56 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN M6 [get_ports cmv_ch_p[55]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[55]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[55]]
set_property PACKAGE_PIN L5 [get_ports cmv_ch_n[55]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[55]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[55]]

# Channel 57 from CMV12000.
set_property PACKAGE_PIN M8 [get_ports cmv_ch_p[56]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[56]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[56]]
set_property PACKAGE_PIN L8 [get_ports cmv_ch_n[56]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[56]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[56]]

# Channel 58 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AH8 [get_ports cmv_ch_p[57]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[57]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[57]]
set_property PACKAGE_PIN AH7 [get_ports cmv_ch_n[57]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[57]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[57]]

# Channel 59 from CMV12000.
set_property PACKAGE_PIN U9 [get_ports cmv_ch_p[58]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[58]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[58]]
set_property PACKAGE_PIN V9 [get_ports cmv_ch_n[58]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[58]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[58]]

# Channel 60 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN AE5 [get_ports cmv_ch_p[59]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[59]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[59]]
set_property PACKAGE_PIN AF5 [get_ports cmv_ch_n[59]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[59]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[59]]

# Channel 61 from CMV12000.
set_property PACKAGE_PIN AB7 [get_ports cmv_ch_p[60]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[60]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[60]]
set_property PACKAGE_PIN AC7 [get_ports cmv_ch_n[60]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[60]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[60]]

# Channel 62 from CMV12000.
set_property PACKAGE_PIN AG3 [get_ports cmv_ch_p[61]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[61]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[61]]
set_property PACKAGE_PIN AH3 [get_ports cmv_ch_n[61]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[61]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[61]]

# Channel 63 from CMV12000. LVDS inverted.
set_property PACKAGE_PIN R7 [get_ports cmv_ch_p[62]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[62]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[62]]
set_property PACKAGE_PIN T7 [get_ports cmv_ch_n[62]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[62]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[62]]

# Channel 64 from CMV12000.
set_property PACKAGE_PIN U8 [get_ports cmv_ch_p[63]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_p[63]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_p[63]]
set_property PACKAGE_PIN V8 [get_ports cmv_ch_n[63]]
set_property IOSTANDARD LVDS [get_ports cmv_ch_n[63]]
set_property DIFF_TERM TRUE [get_ports cmv_ch_n[63]]

# Floorplanning
create_pblock pblock_Encoder_0
add_cells_to_pblock [get_pblocks pblock_Encoder_0] [get_cells -quiet [list BoardSetupTest_i/Encoder_0]]
resize_pblock [get_pblocks pblock_Encoder_0] -add {RAMB36_X0Y0:RAMB36_X1Y23}

# Explicit BRAM and URAM Placements
set_property LOC RAMB36_X0Y14 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_B1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y20 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_B1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y15 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_G1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y10 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_G1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y5 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_G2/FIFO36E2_H ]
set_property LOC RAMB36_X0Y18 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_G2/FIFO36E2_L ]
set_property LOC RAMB36_X0Y7 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_R1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y9 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH1_R1/FIFO36E2_L ]
set_property LOC RAMB36_X1Y14 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH2/FIFO36E2_H ]
set_property LOC RAMB36_X1Y17 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HH2/FIFO36E2_L ]
set_property LOC RAMB36_X1Y12 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_B1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y11 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_B1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y16 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_G1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y8 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_G1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y13 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_G2/FIFO36E2_H ]
set_property LOC RAMB36_X0Y2 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_G2/FIFO36E2_L ]
set_property LOC RAMB36_X0Y3 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_R1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y1 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL1_R1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y21 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL2/FIFO36E2_H ]
set_property LOC RAMB36_X0Y23 [get_cells BoardSetupTest_i/Encoder_0/inst/c_HL2/FIFO36E2_L ]
set_property LOC RAMB36_X1Y15 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_B1/FIFO36E2_H ]
set_property LOC RAMB36_X1Y16 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_B1/FIFO36E2_L ]
set_property LOC RAMB36_X1Y11 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_G1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y0 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_G1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y6 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_G2/FIFO36E2_H ]
set_property LOC RAMB36_X1Y13 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_G2/FIFO36E2_L ]
set_property LOC RAMB36_X0Y19 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_R1/FIFO36E2_H ]
set_property LOC RAMB36_X0Y12 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH1_R1/FIFO36E2_L ]
set_property LOC RAMB36_X0Y17 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH2/FIFO36E2_H ]
set_property LOC RAMB36_X1Y10 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LH2/FIFO36E2_L ]
set_property LOC RAMB36_X0Y22 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LL2/FIFO36E2_H ]
set_property LOC RAMB36_X0Y4 [get_cells BoardSetupTest_i/Encoder_0/inst/c_LL2/FIFO36E2_L ]
set_property LOC RAMB36_X1Y37 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/dc_HH2/FIFO36E2_inst ]
set_property LOC RAMB36_X1Y36 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/dc_HL2/FIFO36E2_inst ]
set_property LOC RAMB36_X0Y36 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/dc_LH2/FIFO36E2_inst ]
set_property LOC RAMB36_X1Y35 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/dc_LL2/FIFO36E2_inst ]
set_property LOC RAMB36_X1Y2 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[0].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y33 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[0].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y7 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[0].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y38 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[0].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y0 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[1].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y4 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[1].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y23 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[1].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y41 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[1].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y3 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[2].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y3 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[2].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y9 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[2].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y38 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[2].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y2 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[3].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y7 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[3].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y18 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[3].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y37 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[3].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y24 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[4].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y20 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[4].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y8 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[4].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y35 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[4].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y1 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[5].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y6 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[5].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y14 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[5].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y39 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[5].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y4 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[6].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y30 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[6].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y25 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[6].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y34 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[6].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y34 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[7].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y31 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[7].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y19 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[7].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y40 [get_cells BoardSetupTest_i/Wavelet_S1/inst/dwt26_v1_array[7].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y28 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[0].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y32 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[0].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y26 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[0].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y33 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[0].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y27 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[1].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y12 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[1].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y17 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[1].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y30 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[1].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y31 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[2].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y27 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[2].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y25 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[2].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y32 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[2].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X0Y26 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[3].B1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y16 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[3].G1/mem_reg_bram_0 ]
set_property LOC RAMB36_X1Y5 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[3].G2/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y29 [get_cells BoardSetupTest_i/Wavelet_S2/inst/dwt26_v2_array[3].R1/mem_reg_bram_0 ]
set_property LOC RAMB36_X2Y10 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[0].ramb36e2_inst ]
set_property LOC RAMB36_X2Y5 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[1].ramb36e2_inst ]
set_property LOC RAMB36_X2Y1 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[2].ramb36e2_inst ]
set_property LOC RAMB36_X2Y19 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[3].ramb36e2_inst ]
set_property LOC RAMB36_X2Y22 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[4].ramb36e2_inst ]
set_property LOC RAMB36_X2Y23 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_0_int/ECC_RAM.RAMB36E2[5].ramb36e2_inst ]
set_property LOC RAMB36_X2Y11 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[0].ramb36e2_inst ]
set_property LOC RAMB36_X2Y6 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[1].ramb36e2_inst ]
set_property LOC RAMB36_X2Y0 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[2].ramb36e2_inst ]
set_property LOC RAMB36_X2Y18 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[3].ramb36e2_inst ]
set_property LOC RAMB36_X1Y22 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[4].ramb36e2_inst ]
set_property LOC RAMB36_X2Y20 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/RAM32K.bram_comp_inst/bram_16k_1_int/ECC_RAM.RAMB36E2[5].ramb36e2_inst ]
set_property LOC RAMB36_X1Y21 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[0].ramb36e2_inst ]
set_property LOC RAMB36_X2Y21 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[1].ramb36e2_inst ]
set_property LOC RAMB36_X2Y25 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[2].ramb36e2_inst ]
set_property LOC RAMB36_X1Y24 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[3].ramb36e2_inst ]
set_property LOC RAMB36_X2Y24 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[4].ramb36e2_inst ]
set_property LOC RAMB36_X2Y26 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_post_inst/bram_16k_int/ECC_RAM.RAMB36E2[5].ramb36e2_inst ]
set_property LOC RAMB36_X2Y8 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_repl_inst/bram_rep_int_0/ECC_RAM.RAMB36E2[0].ramb36e2_inst ]
set_property LOC RAMB36_X2Y9 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_repl_inst/bram_rep_int_0/ECC_RAM.RAMB36E2[1].ramb36e2_inst ]
set_property LOC RAMB36_X2Y15 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_repl_inst/bram_rep_int_0/ECC_RAM.RAMB36E2[2].ramb36e2_inst ]
set_property LOC RAMB36_X2Y13 [get_cells BoardSetupTest_i/xdma_0/inst/pcie4_ip_i/inst/pcie_4_0_pipe_inst/pcie_4_0_bram_inst/bram_repl_inst/bram_rep_int_0/ECC_RAM.RAMB36E2[3].ramb36e2_inst ]
set_property LOC RAMB36_X1Y27 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/MASTER_READ_BRAM/genblk1[0].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X1Y28 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/MASTER_READ_BRAM/genblk1[1].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X0Y30 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/MASTER_WRITE_FIFO/genblk1[0].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X0Y29 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/MASTER_WRITE_FIFO/genblk1[1].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X2Y39 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/bridge_ram.SLAVE_WRITE_FIFO/genblk1[0].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X2Y38 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/bridge_ram.SLAVE_WRITE_FIFO/genblk1[1].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X1Y33 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/bridge_ram.bridge_ram_read_512.SLAVE_READ_BRAM/genblk1[0].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X1Y34 [get_cells BoardSetupTest_i/xdma_0/inst/ram_top/bridge_ram.bridge_ram_read_512.SLAVE_READ_BRAM/genblk1[1].u_buffermem/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_8SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram ]
set_property LOC RAMB36_X1Y29 [get_cells BoardSetupTest_i/xdma_0/inst/udma_wrapper/dma_top/base/IRQ_INST/msix_req.pf0_msix_table/msix_ram_gen[1].msix_ram_reg ]
set_property LOC RAMB36_X2Y32 [get_cells BoardSetupTest_i/xdma_0/inst/udma_wrapper/dma_top/dma_pcie_req/dma_pcie_rc/u_mem_rc/the_bram_reg_0 ]
set_property LOC RAMB36_X1Y31 [get_cells BoardSetupTest_i/xdma_0/inst/udma_wrapper/dma_top/dma_pcie_req/dma_pcie_rc/u_mem_rc/the_bram_reg_1 ]
set_property LOC RAMB36_X2Y28 [get_cells BoardSetupTest_i/xdma_0/inst/udma_wrapper/dma_top/dma_pcie_req/dma_pcie_rc/u_mem_rc/the_bram_reg_2 ]

set_property LOC URAM288_X0Y40 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram00/uram_mem ]
set_property LOC URAM288_X0Y41 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram01/uram_mem ]
set_property LOC URAM288_X0Y36 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram02/uram_mem ]
set_property LOC URAM288_X0Y44 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram03/uram_mem ]
set_property LOC URAM288_X0Y45 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram04/uram_mem ]
set_property LOC URAM288_X0Y46 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram05/uram_mem ]
set_property LOC URAM288_X0Y42 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram06/uram_mem ]
set_property LOC URAM288_X0Y43 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram07/uram_mem ]
set_property LOC URAM288_X0Y47 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram08/uram_mem ]
set_property LOC URAM288_X0Y48 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram09/uram_mem ]
set_property LOC URAM288_X0Y37 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram10/uram_mem ]
set_property LOC URAM288_X0Y38 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram11/uram_mem ]
set_property LOC URAM288_X0Y39 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/HDMI_v1_0_S00_AXI_inst/uram12/uram_mem ]
set_property LOC URAM288_X0Y62 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/ih2_B1/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y52 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/ih2_G1/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y60 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/ih2_G2/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y57 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/ih2_R1/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y56 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/iv2_B1/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y53 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/iv2_G1/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y58 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/iv2_G2/mem_reg_uram_0 ]
set_property LOC URAM288_X0Y59 [get_cells BoardSetupTest_i/HDMI_3DLUT/inst/iv2_R1/mem_reg_uram_0 ]
