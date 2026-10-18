# -------------------------------------------------------------------------------------------------
#  SPDX-License-Identifier: GPL-3.0-or-later
# -------------------------------------------------------------------------------------------------
#  One-shot update of the zPulse Vivado sources for the TX phase control (issue #19):
#    - GT wizard: TX buffer enabled, TX PI / DRP / txbufstatus ports exposed
#    - Block design: one AXI GPIO (phase_ctrl_0) per tx_channel_1..7 on smartconnect_0, exported
#      as phase_ctrl_<i> / phase_status_<i> ports, plus clk_ctrl (= pl_clk0)
#    - BD wrapper regenerated into BlockDesign/zcu102_zpulse/hdl/
#
#  The .xci, .bd and wrapper files in the repository are modified in place.
#
#  Usage (after ./Hog/Do CREATE zPulse):
#    vivado -mode batch -source Scripts/add_phase_ctrl.tcl Projects/zPulse/zPulse.xpr
# -------------------------------------------------------------------------------------------------

if {[catch {current_project}]} {
    error "Open the Hog project first (pass Projects/zPulse/zPulse.xpr to vivado)"
}
set repo_dir [file normalize [file join [file dirname [info script]] ..]]

# ---- GT wizard -----------------------------------------------------------------------------------
set gt [get_ips gtwizard_ultrascale_0]
if {[get_property IS_LOCKED $gt]} {
    upgrade_ip $gt
}
set gt_ports [get_property CONFIG.ENABLE_OPTIONAL_PORTS $gt]
foreach p {drpaddr_in drpclk_in drpdi_in drpen_in drpwe_in txpippmen_in txpippmovrden_in txpippmpd_in txpippmsel_in txpippmstepsize_in drpdo_out drprdy_out txbufstatus_out} {
    if {[lsearch -exact $gt_ports $p] < 0} {
        lappend gt_ports $p
    }
}
set_property -dict [list CONFIG.TX_BUFFER_MODE {1} CONFIG.ENABLE_OPTIONAL_PORTS $gt_ports] $gt

# ---- Block design --------------------------------------------------------------------------------
set bd_file [get_files zcu102_zpulse.bd]
open_bd_design $bd_file

set locked [get_bd_cells -hier -filter {TYPE == ip && IS_LOCKED == 1}]
if {[llength $locked]} {
    upgrade_bd_cells $locked
}

set sc [get_bd_cells smartconnect_0]
set first_mi [get_property CONFIG.NUM_MI $sc]
set_property CONFIG.NUM_MI [expr {$first_mi + 7}] $sc

set pl_clk [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]

create_bd_port -dir O -type clk clk_ctrl
connect_bd_net $pl_clk [get_bd_ports clk_ctrl]

for {set i 1} {$i <= 7} {incr i} {
    set h tx_channels/tx_channel_$i
    set m [format "M%02d" [expr {$first_mi + $i - 1}]]

    set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $h/phase_ctrl_0]
    set_property -dict [list \
        CONFIG.C_IS_DUAL {1} \
        CONFIG.C_ALL_OUTPUTS {1} \
        CONFIG.C_GPIO_WIDTH {32} \
        CONFIG.C_ALL_INPUTS_2 {1} \
        CONFIG.C_GPIO2_WIDTH {32} \
    ] $gpio

    # AXI: smartconnect_0/Mxx -> tx_channels -> tx_channel_i -> phase_ctrl_0
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 $h/S_AXI_PHASE
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 tx_channels/S_AXI_PHASE_$i
    connect_bd_intf_net [get_bd_intf_pins $h/S_AXI_PHASE] [get_bd_intf_pins $gpio/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins tx_channels/S_AXI_PHASE_$i] [get_bd_intf_pins $h/S_AXI_PHASE]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/${m}_AXI] [get_bd_intf_pins tx_channels/S_AXI_PHASE_$i]

    # GPIO clock / reset from the existing hierarchy pins
    connect_bd_net [get_bd_pins $h/s_axi_aclk] [get_bd_pins $gpio/s_axi_aclk]
    connect_bd_net [get_bd_pins $h/s_axi_aresetn] [get_bd_pins $gpio/s_axi_aresetn]

    # control word out, status word in
    create_bd_pin -dir O -from 31 -to 0 $h/phase_ctrl
    create_bd_pin -dir I -from 31 -to 0 $h/phase_status
    connect_bd_net [get_bd_pins $gpio/gpio_io_o] [get_bd_pins $h/phase_ctrl]
    connect_bd_net [get_bd_pins $h/phase_status] [get_bd_pins $gpio/gpio2_io_i]

    create_bd_pin -dir O -from 31 -to 0 tx_channels/phase_ctrl_$i
    create_bd_pin -dir I -from 31 -to 0 tx_channels/phase_status_$i
    connect_bd_net [get_bd_pins $h/phase_ctrl] [get_bd_pins tx_channels/phase_ctrl_$i]
    connect_bd_net [get_bd_pins tx_channels/phase_status_$i] [get_bd_pins $h/phase_status]

    create_bd_port -dir O -from 31 -to 0 phase_ctrl_$i
    create_bd_port -dir I -from 31 -to 0 phase_status_$i
    connect_bd_net [get_bd_pins tx_channels/phase_ctrl_$i] [get_bd_ports phase_ctrl_$i]
    connect_bd_net [get_bd_ports phase_status_$i] [get_bd_pins tx_channels/phase_status_$i]

    assign_bd_address -target_address_space /zynq_ultra_ps_e_0/Data \
        -offset [format "0x%08X" [expr {0xB0200000 + ($i - 1) * 0x10000}]] -range 64K \
        [get_bd_addr_segs $h/phase_ctrl_0/S_AXI/Reg]
}

validate_bd_design
save_bd_design

# keep the committed wrapper in sync with the block design
set wrapper [make_wrapper -files $bd_file -top -force]
file copy -force $wrapper [file join $repo_dir BlockDesign zcu102_zpulse hdl zcu102_zpulse_wrapper.vhd]

close_bd_design [current_bd_design]

puts "add_phase_ctrl.tcl: GT wizard, block design and wrapper updated"
