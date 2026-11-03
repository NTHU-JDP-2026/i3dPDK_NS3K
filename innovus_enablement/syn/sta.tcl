# Pre-layout STA (no wire parasitics). Env: LIB_FILE DESIGN_CFG OUT_DIR MACRO_DIR [CLK_PERIOD_NS]
source $::env(DESIGN_CFG)
if {[info exists ::env(CLK_PERIOD_NS)]} { set CLK_PERIOD_NS $::env(CLK_PERIOD_NS) }
set out $::env(OUT_DIR)
read_liberty $::env(LIB_FILE)
if {[info exists MACROS]} {
    foreach m $MACROS { read_liberty [file join $::env(MACRO_DIR) $m.lib] }
}
read_verilog $out/${DESIGN_TOP}.v
link_design $DESIGN_TOP
create_clock -name clk -period $CLK_PERIOD_NS [get_ports $CLK_PORT]
set_input_delay  0 -clock clk [delete_from_list [all_inputs] [get_ports $CLK_PORT]]
set_output_delay 0 -clock clk [all_outputs]
set_load 1 [all_outputs]
set_driving_cell -lib_cell BUF_X1 -pin Z [all_inputs]
report_checks -path_delay max -digits 4 > $out/sta_max.rpt
report_checks -path_delay min -digits 4 > $out/sta_min.rpt
report_wns -digits 4
report_tns -digits 4
report_power
