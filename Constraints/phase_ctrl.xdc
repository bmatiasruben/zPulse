# TX phase control: the CERN tx_phase_aligner runs on the PS pl_clk0 (clk_pl_0, also used as DRP
# clock) and samples txbufstatus in the TXUSRCLK2 domain. All crossings are synchronized in HDL.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk_pl_0] \
    -group [get_clocks -of_objects [get_pins BUFG_GT_to_TXUSR_CLK_2/O]]
