# PZ-ZU7EV pin constraints. TODO: the LOCs/IOSTANDARDs below are still the ZCU102 ones.

# set_property PACKAGE_PIN G27 [get_ports clk_p]
# set_property PACKAGE_PIN P10 [get_ports clk_out_10]

# set_property IOSTANDARD LVCMOS18 [get_ports clk_out_10]

set_property PACKAGE_PIN A9 [get_ports {o_led[0]}]
set_property PACKAGE_PIN G13 [get_ports {o_led[1]}]
set_property PACKAGE_PIN D7 [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports clk_10mhz_in]
set_property IOSTANDARD LVCMOS12 [get_ports clk_10mhz_out]

set_property IOSTANDARD DIFF_SSTL12 [get_ports user_si570_clk_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports user_si570_clk_n]


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets bd/pz_zu7ev_zpulse_i/clk_wiz_2/inst/clk_out1_pz_zu7ev_zpulse_clk_wiz_2_0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets bd/pz_zu7ev_zpulse_i/clk_wiz_2/inst/clk_out1_pz_zu7ev_zpulse_clk_wiz_0_0]

set_property PACKAGE_PIN F11 [get_ports clk_10mhz_in]
set_property PACKAGE_PIN E10 [get_ports clk_10mhz_out]
set_property PACKAGE_PIN AH12 [get_ports user_si570_clk_p]
set_property PACKAGE_PIN W10 [get_ports clk_gt_internal_p]
