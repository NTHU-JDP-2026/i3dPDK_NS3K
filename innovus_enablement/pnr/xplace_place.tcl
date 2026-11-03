# Standard-cell placement with Xplace as the global placer (PLACER=xplace).
# Sourced by flow.tcl / flow_fast.tcl in place of place_opt_design, right
# after the floorplan: macros, IO pins, rows and the PDN stay exactly as the
# floorplan left them, and Xplace only places the standard cells.
#
#   1. Write $out/xplace/<top>.in.def (defOut -floorplan -netlist -unplaced: die, rows,
#      tracks, IO pins, FIXED macros with their halos, blockages, VDD/VSS and
#      the netlist, standard cells unplaced) and <top>.in.lefs (the LEFs,
#      as <pdk name>/innovus_enablement/...), then touch <top>.in.ready.
#   2. Wait: xplace/run_xplace_flow.sh on the GPU host picks the DEF up, runs
#      the global placement and uploads <top>.gp.def (COMPONENTS only: every
#      standard cell PLACED at its global-placement location), then touches
#      <top>.gp.ready, or <top>.gp.failed if Xplace failed.
#   3. Load it and let Innovus do the rest of what place_opt_design does after
#      its own global placement: legalization and detailed placement
#      (refinePlace) and the pre-CTS optimization (optDesign -preCTS:
#      buffering, sizing, DRV fixing, with incremental legalization only).
#
# XPLACE_WAIT_MIN (default 120): give up if no placement arrives in that time.
set xp_dir $out/xplace
file mkdir $xp_dir
foreach f [glob -nocomplain $xp_dir/$DESIGN_TOP.gp.*] { file delete $f }
# -floorplan alone writes only the placed/fixed components (the macros).
defOut -floorplan -netlist -unplaced $xp_dir/$DESIGN_TOP.in.def
# LEF paths as i3dPDK_NS3K/innovus_enablement/...: the GPU host has this
# checkout under that name (run_xplace_gp.sh looks next to it), whatever the
# directory here is called.
set fh [open $xp_dir/$DESIGN_TOP.in.lefs w]
foreach f $init_lef_file {
    puts $fh [string map [list $enab/ $pdk_name/innovus_enablement/] $f]
}
close $fh
close [open $xp_dir/$DESIGN_TOP.in.ready w]

set xp_wait [design_param XPLACE_WAIT_MIN 120]
set xp_t0 [clock seconds]
puts "xplace: waiting for $xp_dir/$DESIGN_TOP.gp.ready (up to $xp_wait min)"
while {![file exists $xp_dir/$DESIGN_TOP.gp.ready]} {
    if {[file exists $xp_dir/$DESIGN_TOP.gp.failed]} {
        error "xplace: global placement failed on the GPU host (see $xp_dir/$DESIGN_TOP.gp.failed)"
    }
    if {[clock seconds] - $xp_t0 > 60 * $xp_wait} {
        error "xplace: no global placement after $xp_wait min"
    }
    after 10000
}
puts "xplace: global placement arrived after [expr {([clock seconds] - $xp_t0) / 60.0}] min"

set xp_std [dbGet -p2 top.insts.cell.baseClass core]
defIn -components $xp_dir/$DESIGN_TOP.gp.def
set xp_unpl [dbGet -p $xp_std.pStatus unplaced]
if {$xp_unpl ne "0x0" && [llength $xp_unpl]} {
    error "xplace: [llength $xp_unpl] of [llength $xp_std] standard cells left unplaced by $DESIGN_TOP.gp.def (e.g. [dbGet [lindex $xp_unpl 0].name])"
}
puts "xplace: loaded the global placement of [llength $xp_std] standard cells"

# XPLACE_DP_WL_EFFORT (experiments): setPlaceMode -place_detail_wire_length_opt_effort for this refinePlace
# (none|medium|high; default: Innovus' own)
set xp_dp_wl [design_param XPLACE_DP_WL_EFFORT ""]
lappend run_params xplace_dp_wl_effort $xp_dp_wl
if {$xp_dp_wl ne ""} { setPlaceMode -place_detail_wire_length_opt_effort $xp_dp_wl }
# XPLACE_LG_CHECK_ROUTE=1: legalize the global placement checking the cells against the PDN
# (setPlaceMode -place_detail_check_route; this refinePlace and the one after it in flow_fast.tcl
# only). place_design avoids those spots itself; this legalization did not and left e.g. MUX2_X1,
# whose M1 obstruction is 0.04um short of the M1 pad of every stripe via stack, beside the pads
# (dynamic_node, stripe: 14 PG spacing DRCs).
set xp_lg_cr [design_param XPLACE_LG_CHECK_ROUTE 0]
lappend run_params xplace_lg_check_route $xp_lg_cr
if {$xp_lg_cr} { setPlaceMode -place_detail_check_route true }
refinePlace
checkPlace $out/rpt/checkPlace_xplace_lg.rpt
# Placement right after legalization, before optDesign resizes/buffers
# (scripts/def_viz.py draws it on top of <top>.in.def).
defOut $xp_dir/$DESIGN_TOP.lg.def
# XPLACE_PRESERVE=1: skip optDesign -preCTS, which re-places most cells in
# its incremental placement (GigaPlace incrementalPlace; setOptMode -moveInst
# false does not stop it): on jpeg, 10695 of the 10802 XNOR2_X1 moved between
# lg.def and opt.def, many by 6+ sites or rows. Without it there is no pre-CTS
# buffering, sizing or DRV fixing (the fast flow ignores timing anyway).
set xp_preserve [design_param XPLACE_PRESERVE [expr {![design_param PLACE_OPT 1]}]]
lappend run_params xplace_preserve $xp_preserve
if {$xp_preserve} {
    puts "xplace: XPLACE_PRESERVE=1, optDesign -preCTS skipped"
} else {
    optDesign -preCTS -outDir $out/rpt/place
}
# placement after optDesign, before CTS
defOut $xp_dir/$DESIGN_TOP.opt.def
