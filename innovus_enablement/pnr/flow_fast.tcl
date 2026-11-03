# Fast variant of flow.tcl: route violations (DRC), DRV (max tran/cap/fanout)
# and routed wirelength only; no timing/power closure. Run with
#   env FLOW=fast [OUT_TAG=<tag>] run_pnr.sh <design> <LIB>
# Setup, floorplan, macro placement and PDN are flow.tcl's own (sourced with
# STOP_AFTER=floorplan), so the physical conditions match the full flow.
#
# Where the time goes: detail-route DRC convergence at the congestion
# hotspots. tinyRocket (mpauto2 vs mpauto2_fast, run side by side): full flow
# 41 min, 417 DRC; this flow 28 min, 285 DRC, of which routeDesign 24 min
# (57 detail-route iterations). An older full run whose routeDesign stopped
# after 2 iterations (6715 left) spent 42 min in the ecoRoute inside
# optDesign -postRoute instead. Violation counts differ from the full flow's:
# compare fast runs with fast runs only.
#
# Skipped vs flow.tcl: optDesign -postCTS -hold, timing-driven routing,
# optDesign -postRoute, hold timing, power, SPEF, netlist, GDS.
set FLOW_VARIANT fast
set env(STOP_AFTER) floorplan
source [file join [file dirname [info script]] flow.tcl]

# ------------------------------------------------------------------ place
# place_opt_design (not bare place_design): its buffering of high-fanout and
# long nets changes what the router sees, and it only takes ~2 min.
# PLACE_OPT=0: no pre-CTS optimization, whose incremental placement re-places
# most cells (bare place_design here; optDesign -preCTS skipped after Xplace,
# see xplace_place.tcl).
setPlaceMode -place_global_place_io_pins false
# PLACE_CHECK_ROUTE=1: legalization (refinePlace, also inside place_opt_design
# and CTS) checks DRVs against FIXED wires, i.e. the PDN, as ICC2's
# place.legalize.enable_prerouted_net_check does by default
set place_check_route [design_param PLACE_CHECK_ROUTE 0]
lappend run_params place_check_route $place_check_route
if {$place_check_route} { setPlaceMode -place_detail_check_route true }
# PLACE_USE_CHECK_DRC=1 (baselines): setPlaceMode -place_detail_use_check_drc true (DRC engine in legalization)
set place_use_drc [design_param PLACE_USE_CHECK_DRC 0]
lappend run_params place_use_check_drc $place_use_drc
if {$place_use_drc} { setPlaceMode -place_detail_use_check_drc true }
# PLACE_CELL_PAD_SITES=<n> (baselines): Innovus cell padding (specifyCellPad, -left / -right n sites,
# honored by placement and legalization) for the types in PLACE_CELL_PAD_CELLS (comma separated; auto:
# the pin-access critical types, pin scarcity z >= PA_SCARCITY_Z in PA_SCARCITY_REPORT, as pa_flip.tcl)
set cell_pad [design_param PLACE_CELL_PAD_SITES 0]
lappend run_params place_cell_pad_sites $cell_pad
if {$cell_pad > 0} {
    set pad_cells [lsearch -all -inline -not -exact [split [design_param PLACE_CELL_PAD_CELLS auto] " ,"] ""]
    if {$pad_cells eq "auto"} {
        set rep [design_param PA_SCARCITY_REPORT $lefdir/NS3K_5T_cells.pin_scarcity.txt]
        set zmin [design_param PA_SCARCITY_Z 1.0]
        set pad_cells {}
        set fh [open $rep]
        while {[gets $fh line] >= 0} {
            if {[regexp {^\s*\d+\s+(\S+)\s+score=\S+\s+z=(\S+)} $line - c z] && $z >= $zmin} { lappend pad_cells $c }
        }
        close $fh
    }
    foreach c $pad_cells { specifyCellPad $c -left $cell_pad -right $cell_pad }
    setPlaceMode -place_detail_honor_inst_pad true
    puts "cell padding: $cell_pad sites each side on [join $pad_cells ,]"
    lappend run_params place_cell_pad_cells [join $pad_cells ,]
}
set place_opt [design_param PLACE_OPT 1]
if {$placer eq "xplace"} {
    source $pdk/innovus_enablement/pnr/xplace_place.tcl
} elseif {$place_opt} {
    place_opt_design -out_dir $out/rpt/place
} else {
    place_design
}
lappend run_params place_opt $place_opt
# With PG_M3_BLOCK=none, place_opt_design leaves cells on the M3 stripe via
# pads ("Pre-route DRC" in checkPlace; 4251 on tinyRocket). The refinePlace
# inside ccopt_design also moves them off; doing it here first keeps CTS
# working on a legal placement.
refinePlace
checkPlace $out/rpt/checkPlace.rpt
# (XPLACE_LG_CHECK_ROUTE=1 turned the PDN check on for the two legalizations above only)
setPlaceMode -place_detail_check_route [expr {$place_check_route ? "true" : "false"}]
# PA_FLIP=1: x-mirror (and shift) of the cells near the PDN chosen on the GPU host
# (pa_flip.tcl; run with xplace/run_xplace_flow.sh). PA_FLIP_STAGE: preroute (default)
# after CTS, right before routing; prects on the legal placement, before CTS (CTS and
# its legalization then work on the refined placement)
set pa_flip [design_param PA_FLIP 0]
set pa_flip_stage [design_param PA_FLIP_STAGE preroute]
if {$pa_flip_stage ni {preroute prects}} { error "PA_FLIP_STAGE=$pa_flip_stage: preroute or prects" }
lappend run_params pa_flip $pa_flip pa_flip_stage $pa_flip_stage
if {$pa_flip && $pa_flip_stage eq "prects"} {
    source $pdk/innovus_enablement/pnr/pa_flip.tcl
    # PA_FIX_CRIT=1 (default): every instance of the critical types (PA_SHIFT_CELLS, as pa_flip.tcl
    # resolved it) FIXED through CTS and the post-CTS legalizations, so that they keep their refined
    # position and orientation; released again before routing
    set pa_fix_crit [design_param PA_FIX_CRIT 1]
    set crit_fixed {}
    if {$pa_fix_crit && [info exists shift_cells]} {
        foreach ct $shift_cells {
            foreach inst [dbGet -e -p2 top.insts.cell.name $ct] {
                if {[dbGet $inst.pStatus] eq "placed"} { dbSet $inst.pStatus fixed; lappend crit_fixed $inst }
            }
        }
    } elseif {$pa_fix_crit} { puts "pa_fix_crit: no critical types (PA_SHIFT=0), nothing fixed" }
    puts "pa_fix_crit: [llength $crit_fixed] critical cells fixed through CTS"
    lappend run_params pa_fix_crit $pa_fix_crit pa_crit_fixed [llength $crit_fixed]
}
saveDesign -libs $out/db/place.enc

# ------------------------------------------------------------------ CTS
# Same clock tree as flow.tcl, without the post-CTS hold fixing. (Leaving CTS
# out made the clock a single net from one IO pin to every flop; its wires
# jammed that corner and routeDesign gave up on tinyRocket with 79k
# violations after one detail-route pass.)
# no clock (CLK_PORT ""): no CTS
if {$CLK_PORT ne ""} {
    set_ccopt_property buffer_cells   {BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16}
    set_ccopt_property inverter_cells {INV_X1 INV_X2 INV_X4 INV_X8 INV_X16}
    set_ccopt_property target_max_trans $cts_trans
    create_route_type -name clk_rt -bottom_preferred_layer M3 -top_preferred_layer M4
    set_ccopt_property route_type clk_rt -net_type trunk
    set_ccopt_property route_type clk_rt -net_type leaf
    create_ccopt_clock_tree_spec -file $out/ccopt.spec
    source $out/ccopt.spec
    # CTS_ONLY=1: build the clock tree only (ccopt_design -cts). By default ccopt_design
    # also runs optDesign -postCTS, whose high-fanout and DRV buffering rebuilds part of
    # the netlist (jpeg: ~1130 FE_OFC buffers, nets holding ~30% of the routed wire
    # length), differently for each placement.
    set cts_only [design_param CTS_ONLY 0]
    lappend run_params cts_only $cts_only
    # Innovus 22+: place_opt_design leaves a PODv2 db, which ccopt_design refuses
    # (IMPCCOPT-2440: "try clock_opt_design")
    if {[lindex [split [getVersion] .] 0] >= 22} {
        if {$cts_only} { error "CTS_ONLY=1: not set up for Innovus 22+ (clock_opt_design)" }
        clock_opt_design
    } elseif {$cts_only} {
        ccopt_design -cts
    } else {
        ccopt_design
    }
}

# POST_CTS_LEGALIZE=1: legalize again after CTS, and once more right before routing (after
# pa_flip.tcl); =2: both passes also check the cells against the PDN (setPlaceMode
# -place_detail_check_route, for these two passes only; it also moves cells the router copes
# with: aes 62, jpeg 59, and cannot place some, e.g. MUX2_X1 whose M1 obstruction clashes with
# every stripe via pad around). The post-CTS optimization leaves
# its own buffers overlapping or in a row of the wrong orientation now and then, whose PG
# pins then miss their rails (ariane133, Innovus placement: 253 overlaps, 12 orientation
# violations, 8 cells with VDD/VSS open after routing), and cells next to a PG via pad
# (M0/M1 spacing to the PDN). On a legal placement the =1 passes move nothing.
set post_lg [design_param POST_CTS_LEGALIZE 0]
lappend run_params post_cts_legalize $post_lg
proc post_cts_legalize {name} {
    global out place_check_route post_lg
    if {$post_lg >= 2} { setPlaceMode -place_detail_check_route true }
    puts "post-CTS legalize ($name):"
    refinePlace
    checkPlace $out/rpt/checkPlace_$name.rpt
    setPlaceMode -place_detail_check_route [expr {$place_check_route ? "true" : "false"}]
}
if {$post_lg} { post_cts_legalize postcts }

# ------------------------------------------------------------------ route
setNanoRouteMode -routeWithTimingDriven false -routeWithSiDriven false
# ROUTE_MAX_ITER caps the detail-route iterations (default: route until the
# router stops by itself). Most of the route time is the tail: tinyRocket went
# 14327 -> 1027 violations in the first 10 iterations (5.4 min) and took 53
# more (12 min) to reach 251. With a cap the DRC count means "violations left
# after N iterations": compare runs with the same cap only.
set route_max_iter [design_param ROUTE_MAX_ITER 0]
if {$route_max_iter > 0} { setNanoRouteMode -drouteEndIteration $route_max_iter }
lappend run_params route_max_iter $route_max_iter
# ROUTE_ON_GRID (experiments): value for setNanoRouteMode -drouteOnGridOnly
# (e.g. "wire 2:4 via 2:4"; default none).
set route_on_grid [design_param ROUTE_ON_GRID none]
if {$route_on_grid ne "none"} { setNanoRouteMode -drouteOnGridOnly $route_on_grid }
lappend run_params route_on_grid $route_on_grid
# ROUTE_SPLIT=1 (experiments): stop before routing and write the placed,
# clock-routed design (preroute_full.def, preroute.v) for routing in another
# session under another tech LEF (e.g. the strictly unidirectional one, whose
# on-grid M5-M9 the macro PDN cannot be built under).
set route_split [design_param ROUTE_SPLIT 0]
lappend run_params route_split $route_split
set fh [open $out/run_params.json w]
puts $fh "\{\n[join [lmap {k v} $run_params {string cat "  " [json_str $k] ": " [json_str $v]}] ",\n"]\n\}"
close $fh
if {$pa_flip && $pa_flip_stage eq "preroute"} { source $pdk/innovus_enablement/pnr/pa_flip.tcl }
if {$post_lg} { post_cts_legalize preroute }
if {[info exists crit_fixed] && [llength $crit_fixed]} {
    set n 0
    foreach inst $crit_fixed { if {![catch {dbSet $inst.pStatus placed}]} { incr n } }
    puts "pa_fix_crit: $n of [llength $crit_fixed] critical cells released before routing"
}
if {$route_split} {
    saveNetlist $out/preroute.v
    defOut -floorplan -netlist -routing $out/preroute_full.def
    exit
}
routeDesign
saveDesign -libs $out/db/route.enc

# ------------------------------------------------------------------ reports
# Same report names as flow.tcl, so summarize.sh and collect_dataset.py work.
setExtractRCMode -engine postRoute -effortLevel low
# post-route timeDesign refuses to run without OCV (IMPOPT-7027)
setAnalysisMode -analysisType onChipVariation -cppr both
timeDesign -postRoute -outDir $out/rpt/final -prefix final
report_area > $out/rpt/area.rpt
summaryReport -noHtml -outfile $out/rpt/summary.rpt
verify_drc -report $out/rpt/drc.rpt -limit 100000
verifyConnectivity -type all -report $out/rpt/conn.rpt
checkPlace $out/rpt/checkPlace_final.rpt
defOut -floorplan -netlist -routing $out/$DESIGN_TOP.def
exit
