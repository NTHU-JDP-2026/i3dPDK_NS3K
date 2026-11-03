# Innovus (legacy UI) PnR flow for i3dPDK_NS3K (LIB NS3K_<N>T, e.g. NS3K_5T).
# A copy of i3dPDK_A16K's flow.tcl, made standalone: the PDK settings come from
# this checkout's innovus_enablement/pdk_config.tcl.
# Env: PDK_ROOT DESIGN LIB (e.g. NS3K_5T) OUT_DIR [THREADS] [PLACE_TIMING_DRIVEN=true|false|default] [LEF_SCALE] [STOP_AFTER=floorplan|place]
# (flow_fast.tcl sources this file with STOP_AFTER=floorplan and goes on from there.)
#      [CLK_PERIOD_NS] [UTIL] [MACRO_PLACE=auto|columns] [MACRO_CHANNEL_UM] [MIN_CHANNEL_UM]
#      [MACRO_HALO_UM] [IO_PIN_TRACKS] [MACRO_AREA_SLACK] [PLACE_CONG_EFFORT]
#      [PG_M3_PITCH_UM] [PG_M3_WIDTH_UM] [PG_M3_BLOCK=hard|partial|soft|obs|none]
#      [PG_M3_BLOCK_DENSITY] [PG_M3_BLOCK_SITES] [SIGNAL_TOP_LAYER]
#      [ECO_ROUTE=0|1] [ROUTE_UNIDIR=0|1] [PLACER=innovus|xplace]  -- override syn/designs/<design>.tcl
# Every run records its resolved parameters in $OUT_DIR/run_params.json.
# Geometry runs at LEF_SCALE x (default 4): at 1x Innovus 21 classifies the PDK
# as a 3nm-class node and requires the invs_3nm license. Wire R/C in the scaled
# tech LEF are compensated, but reported areas/lengths are LEF_SCALE^2 / LEF_SCALE x.
set pdk    $env(PDK_ROOT)
set design $env(DESIGN)
set lib    $env(LIB)
set out    $env(OUT_DIR)
lassign [split $lib _] arch trk
set ntrk   [string index $trk 0]
source $pdk/innovus_enablement/syn/designs/$design.tcl
# Per-design parameters come from syn/designs/<design>.tcl; an environment
# variable of the same name overrides them, and flow defaults fill the rest.
proc design_param {name default} {
    global env
    if {[info exists env($name)]} { return $env($name) }
    if {[uplevel #0 [list info exists $name]]} { return [uplevel #0 [list set $name]] }
    return $default
}
set CLK_PERIOD_NS [design_param CLK_PERIOD_NS 1.0]
set util          [design_param UTIL 0.6]
set macro_place   [design_param MACRO_PLACE auto]
set mac_ch_um     [design_param MACRO_CHANNEL_UM 2.0]
set min_ch_um     [design_param MIN_CHANNEL_UM 10.0]
set io_trk        [design_param IO_PIN_TRACKS 4]
set io_layers     [design_param IO_PIN_LAYERS 4]
set mac_slack     [design_param MACRO_AREA_SLACK 1.25]
set cong_effort   [design_param PLACE_CONG_EFFORT high]
set halo_um       [design_param MACRO_HALO_UM 0.5]
set m3_pitch_um   [design_param PG_M3_PITCH_UM 2.0]
set m3_width_um   [design_param PG_M3_WIDTH_UM 0.048]
set m3_block      [design_param PG_M3_BLOCK none]
if {$m3_block ni {none hard partial soft obs}} { error "PG_M3_BLOCK must be none, hard, partial, soft or obs, not $m3_block" }
# PG_M3_BLOCK=partial: max cell density (%) in the blockage, and its margin
# (sites) on each side of the stripe pair
set m3_block_density [design_param PG_M3_BLOCK_DENSITY 30]
set m3_block_sites   [design_param PG_M3_BLOCK_SITES 1]
# PG_M3_SNAP=None: draw the M3 stripe pairs with add_shape at their computed
# positions (centres 18 / 26 nm from the site grid, 96 nm apart), as the ICC2
# flow does. By default addStripe draws them, and with ROUTE_UNIDIR=1 it
# snaps every stripe centre onto an M3 track (IMPPP-2030: the unidir LEF
# allows on-grid wires only on M3; -snap_wire_center_to_grid None does not
# stop it): centres 0 / 22 nm from the site grid, 110 nm apart.
set m3_snap          [design_param PG_M3_SNAP ""]
# PG_STYLE: stripe (default) = the M3 VDD/VSS stripe pairs below; pillar =
# the same pairs as straps on PG_PILLAR_LAYER (default M5), tied to the rails
# by via pillars (rail->strap stacks; M1..M4 only carry their pads, no M3
# stripe), see "M3 PG stripes" below.
set pg_style      [design_param PG_STYLE stripe]
if {$pg_style ni {stripe pillar}} { error "PG_STYLE must be stripe or pillar, not $pg_style" }
set pg_layer      [expr {$pg_style eq "pillar" ? [design_param PG_PILLAR_LAYER M5] : "M3"}]
set sig_top       [design_param SIGNAL_TOP_LAYER M11]
set eco_route     [design_param ECO_ROUTE 0]
# ROUTE_UNIDIR=1: tech LEF <pdk>_<N>T_tech_unidir.lef, whose lower metals
# (pitch <= 0.024um) take RIGHTWAYONGRIDONLY + RECTONLY, so they route in the
# preferred direction only, on track (see gen_innovus_lef.py UNIDIR_*).
set route_unidir  [design_param ROUTE_UNIDIR 0]
# PLACER: global placement of the standard cells by Innovus (place_opt_design)
# or by Xplace on a GPU host (xplace_place.tcl; run with xplace/run_xplace_flow.sh).
set placer        [design_param PLACER innovus]
if {$placer ni {innovus xplace}} { error "PLACER must be innovus or xplace, not $placer" }
set threads [expr {[info exists env(THREADS)] ? $env(THREADS) : 8}]
set scale   [expr {[info exists env(LEF_SCALE)] ? $env(LEF_SCALE) : 4}]

# PDK settings ($pdk_name, $enab: generated LEFs, macros, netlists, stream
# map, $site_name, rails, CTS slew, liberty, routing direction).
if {$arch ne "NS3K"} { error "this flow is for LIB NS3K_<N>T, not $lib" }
source $pdk/innovus_enablement/pdk_config.tcl
set lefdir   $enab/[expr {$scale == 1 ? "lef" : "lef_x$scale"}]
set netlist  $enab/syn/out/$design/$lib/${DESIGN_TOP}.v
# Hard macros (design config $MACROS): abstract SRAMs from scripts/gen_fakeram.py.
if {![info exists MACROS]} { set MACROS {} }
# MACRO_LEF_DIR (default the LEF directory of the scale; relative: to innovus_enablement/): another set
# of macro abstracts, e.g. lef_x4_pgm6 (scripts/gen_macros.sh --pg-m6: PG straps horizontal on M6)
set macro_lefdir [design_param MACRO_LEF_DIR $lefdir]
if {[file pathtype $macro_lefdir] eq "relative"} { set macro_lefdir $enab/$macro_lefdir }
set macro_lefs [lmap m $MACROS {file join $macro_lefdir $m.lef}]
set macro_libs [lmap m $MACROS {file join $enab/macros $m.lib}]
file mkdir $out/rpt
setMultiCpuUsage -localCpu $threads

# ------------------------------------------------------------------ run record
# Resolved parameters + flow version, so every run can be traced and reproduced
# (and picked up by scripts/collect_dataset.py).
proc json_str {v} { return "\"[string map {\\ \\\\ \" \\\"} $v]\"" }
set flow_version unknown
catch { set fh [open $pdk/innovus_enablement/.flow_version]; set flow_version [string trim [read $fh]]; close $fh }
set run_params [list \
    design $design lib $lib pdk $pdk_name top $DESIGN_TOP tag [file tail $out] \
    clk_period_ns $CLK_PERIOD_NS util $util macros $MACROS macro_place $macro_place macro_channel_um $mac_ch_um io_pin_tracks $io_trk io_pin_layers $io_layers macro_area_slack $mac_slack place_cong_effort $cong_effort \
    min_channel_um $min_ch_um macro_halo_um $halo_um \
    pg_m3_pitch_um $m3_pitch_um pg_m3_width_um $m3_width_um pg_m3_block $m3_block pg_m3_block_density $m3_block_density pg_m3_block_sites $m3_block_sites pg_m3_snap $m3_snap pg_style $pg_style pg_layer $pg_layer \
    signal_top_layer $sig_top eco_route $eco_route route_unidir $route_unidir placer $placer lef_scale $scale \
    flow [expr {[info exists FLOW_VARIANT] ? $FLOW_VARIANT : "full"}] \
    flow_version $flow_version started [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] \
    host [info hostname] out_dir $out]
set fh [open $out/run_params.json w]
set items {}
foreach {k v} $run_params { lappend items "  [json_str $k]: [json_str $v]" }
puts $fh "\{\n[join $items ",\n"]\n\}"
close $fh

# ------------------------------------------------------------------ SDC
set io_dly [expr {0.2 * $CLK_PERIOD_NS}]
set fh [open $out/$DESIGN_TOP.sdc w]
# CLK_PORT "" (synthetic designs without IO, e.g. aoi300): no clock, no IO constraints;
# several ports (bp_quad): one clock on all of them
if {$CLK_PORT ne ""} {
puts $fh "create_clock -name clk -period $CLK_PERIOD_NS \[get_ports \{$CLK_PORT\}\]
set_clock_uncertainty 0.01 \[get_clocks clk\]
set_clock_transition 0.01 \[get_clocks clk\]
set_input_delay  $io_dly -clock clk \[remove_from_collection \[all_inputs\] \[get_ports \{$CLK_PORT\}\]\]
set_output_delay $io_dly -clock clk \[all_outputs\]
set_driving_cell -lib_cell BUF_X1 -pin Z \[remove_from_collection \[all_inputs\] \[get_ports \{$CLK_PORT\}\]\]
set_load 1 \[all_outputs\]"
}
close $fh

# ------------------------------------------------------------------ MMMC
# No QRC techfile / captable exists for this PDK: Innovus builds a cap table
# from the tech LEF (THICKNESS, width, spacing) and takes R from RPERSQ.
# Cap per unit length is scale-invariant but every wire is LEF_SCALE x longer,
# so caps are scaled by 1/LEF_SCALE. R needs no factor (R/sq * L/W).
set cf [expr {1.0 / $scale}]
set fh [open $out/mmmc.tcl w]
puts $fh "create_library_set -name libs_tt -timing {$lib_file $macro_libs}
create_rc_corner -name rc_typ -T 27 \\
    -preRoute_cap $cf -preRoute_clkcap $cf \\
    -postRoute_cap {$cf $cf $cf} -postRoute_clkcap {$cf $cf $cf} -postRoute_xcap {$cf $cf $cf}
create_delay_corner -name dc_tt -library_set libs_tt -rc_corner rc_typ
create_constraint_mode -name func -sdc_files {$out/$DESIGN_TOP.sdc}
create_analysis_view -name view_tt -constraint_mode func -delay_corner dc_tt
set_analysis_view -setup {view_tt} -hold {view_tt}"
close $fh

# ------------------------------------------------------------------ init
# TECH_LEF (experiments): tech LEF path, overriding the one above.
set tech_lef [file normalize [design_param TECH_LEF $lefdir/${pdk_name}_${ntrk}T_tech[expr {$route_unidir ? "_unidir" : ""}].lef]]
lappend run_params tech_lef $tech_lef macro_lef_dir $macro_lefdir
# PG_VIA_LEF / PG_VIA_PREF (experiments): an extra LEF of fixed PG vias and the vias the PDN stacks
# (sroute, editPowerVia) are to use, e.g. lef_x4/i3dPDK_NS3K_5T_pgvias_icc2.lef with its PGVIA* (the
# ICC2 flow's via geometry; editPowerVia's exact-crossover vias have larger M1/M2 pads).
set pg_via_lef  [lmap f [design_param PG_VIA_LEF ""] {file normalize $f}]
set pg_via_pref [design_param PG_VIA_PREF ""]
lappend run_params pg_via_lef $pg_via_lef pg_via_pref $pg_via_pref
set init_lef_file   [list $tech_lef $lefdir/${lib}_cells.lef {*}$macro_lefs {*}$pg_via_lef]
set init_verilog    $netlist
set init_top_cell   $DESIGN_TOP
set init_pwr_net    VDD
set init_gnd_net    VSS
set init_mmmc_file  $out/mmmc.tcl
init_design

# M1 is pin-access only; signals use M2-SIGNAL_TOP_LAYER (default M11; the
# PDN on M8/M9 is only the core ring and a few macro halo stripes, which the
# router avoids). With M2-M7 only, tinyRocket (small macros, util 0.6) had
# 28%/33% global-route overflow and 68k DRCs; with M2-M11, 2 DRCs.
# Stay <= M11: CFET GDS layers collide with M12 and up.
setDesignMode -bottomRoutingLayer M2 -topRoutingLayer $sig_top
# PLACE_CONG_EFFORT (auto|low|medium|high, default high; auto = Innovus'
# own default): congestion effort of every global placement (the macro
# placement and place_opt_design). With auto, swerv_wrapper crammed cells into
# a channel between macros and the core edge and routing gave up (29k DRCs).
if {$cong_effort ne "auto"} { setPlaceMode -place_global_cong_effort $cong_effort }
# PLACE_TIMING_DRIVEN (true|false|default): setPlaceMode -timingDriven for every global placement
# (macro placement, place_design, place_opt_design's placement). Default: false in the fast flow
# (FLOW=fast: no timing), Innovus' own setting (timing driven when an SDC is loaded) in the full flow.
# CTS' optDesign -postCTS is not affected.
set place_td [design_param PLACE_TIMING_DRIVEN [expr {[info exists FLOW_VARIANT] && $FLOW_VARIANT eq "fast" ? "false" : "default"}]]
lappend run_params place_timing_driven $place_td
if {$place_td ne "default"} { setPlaceMode -timingDriven $place_td }
# PLACE_UNIFORM_DENSITY=1 / PLACE_MAX_DENSITY=<0..1> (experiments): spread the
# global placement (setPlaceMode -place_global_uniform_density /
# -place_global_max_density). place_opt_design's default placement has a
# shorter HPWL than ICC2's but a higher pin density and a higher routed-WL /
# HPWL ratio (1.11-1.48 vs 1.01-1.23 on the 13 designs, pillar UTIL 0.8).
set place_uniform [design_param PLACE_UNIFORM_DENSITY 0]
set place_maxd    [design_param PLACE_MAX_DENSITY none]
if {$place_uniform} { setPlaceMode -place_global_uniform_density true }
if {$place_maxd ne "none"} { setPlaceMode -place_global_max_density $place_maxd }
lappend run_params place_uniform_density $place_uniform place_max_density $place_maxd
setDontUse SDFF_X1 true
setDontUse SDFF_X2 true

# PG: multi-row cells use VDD_1/VDD_2/VSS_1/VSS_2; constants tie straight to the rails
# (the PDK has no TIE cells).
globalNetConnect VDD -type pgpin -pin VDD* -inst * -override
globalNetConnect VSS -type pgpin -pin VSS* -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override

# ------------------------------------------------------------------ floorplan
# Rails are on BPR: row/cell PG parity must be computed there, or multi-row
# cells (DFF, ...) land on rows whose rail polarity is inverted.
setFPlanMode -powerRailLayer $rail_layer
set m     [expr {0.5 * $scale}]
# Macro halo (1x um). It also hosts the M9 VDD/VSS stripe pair (0.26um) and
# its placement blockage (+1 site each side), so keep it >= ~0.4um.
set halo  [expr {$halo_um * $scale}]
set blocks [dbGet -p2 top.insts.cell.baseClass block]
if {$blocks eq "0x0"} { set blocks {} }
set site_w [dbGet [dbGet -p head.sites.name $site_name].size_x]
set row_h  [dbGet [dbGet -p head.sites.name $site_name].size_y]
proc snap_up {v g} { expr {ceil($v / $g - 1e-6) * $g} }

# Macro signal pins are M4 stubs at pitch/2 + k*pitch from the macro origin
# (gen_fakeram.py; the macro height is a whole number of M4 pitches, so
# MX/R180 keep that too). The macro origin y therefore goes on the grid
# (first M4 track) - pitch/2 + k*pitch, read from the floorplan's M4 tracks,
# or every pin ends up off-track and neighbouring wires violate spacing to
# it. The track phase is not simply the LEF OFFSET (A16K: OFFSET 0.12, first
# track 0.144), and the ROUTE_UNIDIR LEFs move it by half a pitch: assuming
# cy1 + k*pitch put every macro pin half a track off under ROUTE_UNIDIR
# (off-track M4 wires to them).
if {[catch {dbGet [dbGet -p head.layers.name M4].pitchY} m4_pitch] || ![string is double -strict $m4_pitch] || $m4_pitch <= 0} {
    set m4_pitch [expr {0.06 * $scale}]
}
# y on the macro-origin grid: up (ceil), down (floor) or nearest (round).
# Needs the floorplan (tracks).
proc m4_grid {y mode} {
    global m4_pitch
    set y0 [expr {$m4_pitch / 2}]
    foreach t [dbGet -p2 top.fPlan.tracks.layers.name M4] {
        if {[dbGet $t.dir] eq "y"} { set y0 [expr {[dbGet $t.start] - $m4_pitch / 2}] }
    }
    expr {$y0 + [::tcl::mathfunc::$mode [expr {($y - $y0) / $m4_pitch + ($mode eq "ceil" ? -1e-6 : $mode eq "floor" ? 1e-6 : 0)}]] * $m4_pitch}
}
# Shift (one M4 pitch, signed) that puts the horizontal PG straps of macro b on the tracks of
# their layer, or 0: none needed, or the macro has no horizontal PG strap above M4.
proc macro_pg_track_dy {b} {
    global m4_pitch
    foreach as [dbGet $b.cell.pgTerms.pins.allShapes] {
        set l [dbGet $as.layer.name]
        if {$l in {BPR M0 M1 M2 M3 M4}} continue
        set r [lindex [dbGet $as.shapes.rect] 0]
        if {[llength $r] == 1} { set r [lindex $r 0] }
        lassign $r x1 y1 x2 y2
        if {$x2 - $x1 <= $y2 - $y1} continue
        lassign [lindex [dbGet $b.box] 0] - by1 - by2
        set yc [expr {($y1 + $y2) / 2}]
        if {[dbGet $b.orient] in {MX R180}} { set yc [expr {($by2 - $by1) - $yc}] }
        set ya [expr {$by1 + $yc}]
        foreach t [dbGet -p2 top.fPlan.tracks.layers.name $l] {
            if {[dbGet $t.dir] ne "y"} continue
            set k [expr {($ya - [dbGet $t.start]) / [dbGet $t.step]}]
            return [expr {abs($k - round($k)) < 1e-3 ? 0 : $m4_pitch}]
        }
    }
    return 0
}
set pin_sides {Left M4 Top M5 Right M4 Bottom M5}
# IO pin layers: IO_PIN_LAYERS of M4/M6/M8/M10 (left/right) and M5/M7/M9/M11
# (top/bottom), up to SIGNAL_TOP_LAYER. On one layer, the 2513/3031 IO pins of
# bp_fe_top/bp_be_top set a core side 3x what the cells and macros need (std
# cells 2% of the core). The pins cross the M8/M9 core ring on other layers.
set top_n [string range $sig_top 1 end]
set io_hlayers {}; set io_vlayers {}
foreach l {M4 M6 M8 M10} { if {[string range $l 1 end] <= $top_n && [llength $io_hlayers] < $io_layers} { lappend io_hlayers $l } }
foreach l {M5 M7 M9 M11} { if {[string range $l 1 end] <= $top_n && [llength $io_vlayers] < $io_layers} { lappend io_vlayers $l } }
set io_nl [expr {min([llength $io_hlayers], [llength $io_vlayers])}]
set io_pitch $m4_pitch
foreach l [concat $io_hlayers $io_vlayers] {
    catch { set io_pitch [expr {max($io_pitch, [dbGet [dbGet -p head.layers.name $l].pitchX], [dbGet [dbGet -p head.layers.name $l].pitchY])}] }
}
if {[llength $blocks] && [string match def:* $macro_place]} {
    # MACRO_PLACE=def:<DEF> (experiments): the die, core and macros of another
    # tool's run (the ICC2 flow's DEF, any DEF units): core = the rows' extent,
    # macros placed and fixed after the rows exist (below), snapped like auto.
    set fp_def [string range $macro_place 4 end]
    set fh [open $fp_def]; set dtxt [read $fh]; close $fh
    regexp {UNITS DISTANCE MICRONS (\d+)} $dtxt -> dbu
    set k [expr {double($scale) / $dbu}]
    set dpts [regexp -all -inline {\(\s*(-?\d+)\s+(-?\d+)\s*\)} [lindex [regexp -inline {DIEAREA[^;]*;} $dtxt] 0]]
    set dxs {}; set dys {}
    foreach {- x y} $dpts { lappend dxs [expr {$x * $k}]; lappend dys [expr {$y * $k}] }
    set rx1 1e18; set ry1 1e18; set rx2 -1e18; set ry2 -1e18
    foreach {- x y n sx} [regexp -all -inline {\nROW \S+ \S+ (-?\d+) (-?\d+) \S+ DO (\d+) BY 1 STEP (\d+)} $dtxt] {
        set rx1 [expr {min($rx1, $x * $k)}]; set ry1 [expr {min($ry1, $y * $k)}]
        set rx2 [expr {max($rx2, ($x + $n * $sx) * $k)}]; set ry2 [expr {max($ry2, $y * $k + $row_h)}]
    }
    set dx1 [tcl::mathfunc::min {*}$dxs]; set dy1 [tcl::mathfunc::min {*}$dys]
    set dx2 [tcl::mathfunc::max {*}$dxs]; set dy2 [tcl::mathfunc::max {*}$dys]
    floorPlan -site $site_name -flip f -s [expr {$rx2 - $rx1}] [expr {$ry2 - $ry1}] \
        [expr {$rx1 - $dx1}] [expr {$ry1 - $dy1}] [expr {$dx2 - $rx2}] [expr {$dy2 - $ry2}]
    addHaloToBlock $halo $halo $halo $halo -allBlock
    # macro name -> {x y orient} (DEF orientation -> Innovus), from the
    # one-line component entries "- <name> <cell> + FIXED|PLACED ( x y ) <orient>"
    set omap {N R0 S R180 FN MY FS MX W R90 E R270 FW MX90 FE MY90}
    set comps {}
    foreach line [split $dtxt "\n"] {
        if {[regexp {^\s*- (\S+) \S+ \+ (?:FIXED|PLACED) \( (-?\d+) (-?\d+) \) (\S+)} $line -> nm x y o]} {
            dict set comps [string map {\\ {}} $nm] [list [expr {$x * $k}] [expr {$y * $k}] [dict get $omap $o]]
        }
    }
    set fp_macros {}
    foreach b $blocks {
        set nm [dbGet $b.name]
        if {![dict exists $comps $nm]} { error "MACRO_PLACE=def: macro $nm not in $fp_def" }
        dict set fp_macros $nm [dict get $comps $nm]
    }
    puts "macro floorplan (def $fp_def): die [dbGet top.fPlan.box] core [dbGet top.fPlan.coreBox], [dict size $fp_macros] macros"
} elseif {[llength $blocks] && $macro_place eq "columns"} {
    # MACRO_PLACE=columns: macros go in two columns against the left/right
    # core edges, pins facing the logic in the middle; the core is sized from
    # the columns and from the standard-cell area at $util.
    set cols [list {} {}]
    set i 0
    foreach b $blocks { lset cols [expr {$i % 2}] [concat [lindex $cols [expr {$i % 2}]] $b]; incr i }
    set col_h 0; set col_w 0
    foreach col $cols {
        set h 0
        foreach b $col {
            set h [expr {$h + [snap_up [dbGet $b.cell.size_y] $row_h] + 2 * $halo + $m4_pitch}]
            set col_w [expr {max($col_w, [dbGet $b.cell.size_x])}]
        }
        set col_h [expr {max($col_h, $h)}]
    }
    set std_area [expr [join [dbGet [dbGet -p2 top.insts.cell.baseClass core].area] +]]
    set core_h [snap_up [expr {max($col_h, sqrt($std_area / $util))}] [expr {2 * $row_h}]]
    set ncol   [expr {[llength [lindex $cols 1]] ? 2 : 1}]
    # The logic channel between the columns also carries the macro-pin and IO
    # routing, which the std-cell area alone underestimates when the macros
    # dominate (riscv32i: a 4.6um channel gave hotspot score ~1200), so it is
    # at least MIN_CHANNEL_UM (1x) wide; otherwise $util sets it.
    set min_ch [expr {$min_ch_um * $scale}]
    set core_w [snap_up [expr {$ncol * ($col_w + $halo) + max($std_area / $util / $core_h, $min_ch)}] $site_w]
    floorPlan -site $site_name -flip f -s $core_w $core_h $m $m $m $m
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    # Pins are on the left edge of the macro in R0: MY on the left column.
    foreach col $cols side {left right} {
        set y $cy1
        foreach b $col {
            set w [dbGet $b.cell.size_x]
            set x [expr {$side eq "left" ? $cx1 : $cx2 - $w}]
            set y [m4_grid $y ceil]
            placeInstance [dbGet $b.name] [list $x $y] [expr {$side eq "left" ? "MY" : "R0"}] -fixed
            set y [expr {$y + [dbGet $b.cell.size_y] + 2 * $halo}]
        }
    }
    addHaloToBlock $halo $halo $halo $halo -allBlock
    puts "macro floorplan (columns): core [dbGet top.fPlan.coreBox] std_area $std_area"
    set pin_sides {Top M5 Bottom M5}
} elseif {[llength $blocks]} {
    # MACRO_PLACE=auto: the core holds the standard cells at $util plus every
    # macro with its halo; the macros are placed later by
    # place_design -concurrent_macros (after the rows and IO pins exist).
    # Area alone is not enough: the macros must also fit side by side
    # (riscv32i: four tall SRAMs do not fit in the square core of the right
    # area, and refine_macro_place then fails to remove the overlaps). The
    # core width is scanned and, for each width, the macros are shelf-packed
    # (with slack pk, below); the height is the larger of the packed macro height and
    # area / width. A shelf with two or more macros also reserves one
    # MIN_CHANNEL_UM (1x) logic channel: sized from the areas alone, riscv32i
    # got a ~5um channel holding most of the logic and 66k shorts. (One
    # channel per macro pair made bp_fe_top's 11 macros a 1:21 column.)
    # The aspect ratio stays within 1:2..2:1, and every side can take a
    # quarter of the IO pins at one pin per IO_PIN_TRACKS tracks (default 4:
    # at 2, bp_fe_top's 2511 pins filled the whole perimeter and could not be
    # routed out). Smallest area wins,
    # with a penalty on the aspect ratio.
    set std_area [expr [join [dbGet [dbGet -p2 top.insts.cell.baseClass core].area] +]]
    set mac_area 0; set dims {}
    foreach b $blocks {
        set bw [expr {[dbGet $b.cell.size_x] + 2 * $halo}]
        set bh [expr {[dbGet $b.cell.size_y] + 2 * $halo}]
        set mac_area [expr {$mac_area + $bw * $bh}]
        lappend dims [list $bw $bh]
    }
    # UTIL only covers the standard cells; the macros (+halo) get their own
    # margin MACRO_AREA_SLACK, and the shelf packing a slack of
    # max(1.05, sqrt(MACRO_AREA_SLACK)). With the macro area counted exactly,
    # swerv_wrapper (28 macros, 65% of the core) could not be legalized by
    # refine_macro_place, or left the logic crammed into one corner.
    set pk       [expr {max(1.05, sqrt($mac_slack))}]
    set dims     [lsort -real -decreasing -index 1 $dims]
    set area     [expr {$std_area / $util + $mac_area * $mac_slack}]
    set min_ch   [expr {$min_ch_um * $scale}]
    set min_side [expr {ceil([llength [dbGet top.terms.name]] / 4.0 / $io_nl) * $io_trk * $io_pitch}]
    set max_w    [tcl::mathfunc::max {*}[lmap d $dims {lindex $d 0}]]
    set sum_w    [expr [join [lmap d $dims {lindex $d 0}] +] + $min_ch]
    set best {}
    for {set i 0} {$i <= 400} {incr i} {
        set W [expr {$pk * ($max_w + ($sum_w - $max_w) * $i / 400.0)}]
        foreach W [list $W [expr {sqrt($area)}] $min_side] {
            if {$W < $pk * $max_w || $W < $min_side} continue
            # shelf packing into W / pk
            set hm 0; set rw 0; set rh 0; set rn 0
            foreach d $dims {
                lassign $d w h
                set nw [expr {$rn == 1 ? $rw + $w + $min_ch : $rw + $w}]
                if {$rn > 0 && $nw > $W / $pk + 1e-6} {
                    set hm [expr {$hm + $rh}]; set rw 0; set rh 0; set rn 0; set nw $w
                }
                set rw $nw; set rh [expr {max($rh, $h)}]; incr rn
            }
            set H [expr {max($pk * ($hm + $rh), $area / $W, $W / 2.0, $min_side)}]
            if {$H > 2 * $W} continue
            set score [expr {$W * $H * (1 + 0.2 * abs(log($W / $H)))}]
            if {![llength $best] || $score < [lindex $best 0]} { set best [list $score $W $H] }
        }
    }
    lassign $best - core_w core_h
    set core_w [snap_up $core_w $site_w]
    set core_h [snap_up $core_h [expr {2 * $row_h}]]
    floorPlan -site $site_name -flip f -s $core_w $core_h $m $m $m $m
    addHaloToBlock $halo $halo $halo $halo -allBlock
    puts "macro floorplan (auto): core [dbGet top.fPlan.coreBox] std_area $std_area macro_area(+halo) $mac_area"
} else {
    floorPlan -site $site_name -flip f -r 1.0 $util $m $m $m $m
}
# Pins: horizontal M4 on left/right, vertical M5 on top/bottom (top/bottom
# only when macro columns occupy the left/right edges).
# Each side's pins go round-robin onto IO_PIN_LAYERS layers (left/right: the
# horizontal io_hlayers, top/bottom: the vertical io_vlayers, see above), each
# layer's pins spread over the side and staggered by 1/n of the pin spacing
# so pins on different layers do not stack at one spot.
set ports [expr {[dbGet top.numTerms] ? [lsort -dictionary [dbGet top.terms.name]] : {}}]
set nside [expr {[llength $pin_sides] / 2}]
set q [expr {([llength $ports] + $nside - 1) / $nside}]
lassign [lindex [dbGet top.fPlan.box] 0] dx1 dy1 dx2 dy2
# Layers with tracks at offset 0 (the ROUTE_UNIDIR LEFs) have a track on the
# die edge, and a default-depth IO pin crosses only that one: the router
# reached the pin on it, half outside the die (M4 OFFGRID, M5 Out Of Die). The pins then reach 3 such pitches into the die.
set zero_off_pitch 0
foreach l [dbGet head.layers] {
    if {[dbGet $l.type] ne "routing" || [dbGet $l.name] in {BPR M0}} continue
    set hz [expr {[dbGet $l.direction] eq "Horizontal"}]
    if {[dbGet $l.[expr {$hz ? "offsetY" : "offsetX"}]] == 0} {
        set zero_off_pitch [expr {max($zero_off_pitch, [dbGet $l.[expr {$hz ? "pitchY" : "pitchX"}]])}]
    }
}
set pin_depth [expr {$zero_off_pitch > 0 ? [list -pinDepth [expr {3 * $zero_off_pitch}]] : {}}]
setPinAssignMode -pinEditInBatch true
set i 0
foreach {side layer} $pin_sides {
    set grp [lrange $ports [expr {$i * $q}] [expr {($i + 1) * $q - 1}]]
    incr i
    if {![llength $grp]} continue
    set lays [expr {$side in {Left Right} ? $io_hlayers : $io_vlayers}]
    set nl   [llength $lays]
    set len  [expr {$side in {Left Right} ? $dy2 - $dy1 : $dx2 - $dx1}]
    set d    [expr {$len / [llength $grp] }]
    for {set k 0} {$k < $nl} {incr k} {
        set sub {}
        for {set j $k} {$j < [llength $grp]} {incr j $nl} { lappend sub [lindex $grp $j] }
        if {![llength $sub]} continue
        # layer k spreads over [start + k*d, end - (nl-1-k)*d] along the side.
        # editPin -spreadType RANGE runs clockwise from -start to -end, so
        # the right side goes top to bottom and the bottom side right to
        # left; given the other way round the range wrapped around the die
        # and those pins landed on the other sides, on the wrong layer
        # direction for them (1-2 pins per layer on the right side, M4 pins
        # on the top edge).
        # Ranges stop one pin slot short of the corners: a pin placed on
        # the corner itself went to the neighbouring side (the last M10
        # pin of the right side on the top edge: bp_be_top, swerv_wrapper,
        # ariane133).
        set cn [expr {$io_pitch * $io_trk}]
        set a [expr {$k * $d + $cn}]; set b [expr {($nl - 1 - $k) * $d + $cn}]
        switch $side {
            Left   { set p0 [list $dx1 [expr {$dy1 + $a}]]; set p1 [list $dx1 [expr {$dy2 - $b}]] }
            Right  { set p1 [list $dx2 [expr {$dy1 + $a}]]; set p0 [list $dx2 [expr {$dy2 - $b}]] }
            Top    { set p0 [list [expr {$dx1 + $a}] $dy2]; set p1 [list [expr {$dx2 - $b}] $dy2] }
            Bottom { set p1 [list [expr {$dx1 + $a}] $dy1]; set p0 [list [expr {$dx2 - $b}] $dy1] }
        }
        editPin -pin $sub -layer [lindex $lays $k] -spreadType RANGE -start $p0 -end $p1 -fixOverlap 1 {*}$pin_depth
    }
}
setPinAssignMode -pinEditInBatch false

# Multi-row cells live on <site>_<N>H_<VDD|VSS> sites (see gen_innovus_lef.py).
# With -flip f the first row is MX, so row boundary k carries VDD when k is even.
# One N-row-high row is created wherever the cell's bottom rail matches
# (R0), or for odd N where its top rail matches (MX).
proc create_multi_height_rows {} {
    global site_name
    lassign [lindex [dbGet top.fPlan.coreBox] 0] x1 y1 x2 y2
    set h [dbGet [dbGet -p head.sites.name $site_name].size_y]
    set nrow [expr {int(round(($y2 - $y1) / $h))}]
    foreach s [dbGet head.sites.name] {
        if {![regexp {_(\d)H_(VDD|VSS)$} $s -> R B]} { continue }
        set n 0
        for {set k 0} {$k <= $nrow - $R} {incr k} {
            set P [expr {$k % 2 == 0 ? "VDD" : "VSS"}]
            if {$P eq $B} {
                set flip {}
            } elseif {$R % 2} {
                set flip -flip1st
            } else {
                continue
            }
            createRow -site $s {*}$flip \
                -area [list $x1 [expr {$y1 + $k * $h}] $x2 [expr {$y1 + ($k + $R) * $h}]]
            incr n
        }
        puts "create_multi_height_rows: $n rows of $s"
    }
}
create_multi_height_rows

if {[llength $blocks] && [string match def:* $macro_place]} {
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    foreach b $blocks {
        lassign [dict get $fp_macros [dbGet $b.name]] x y o
        set x [expr {$cx1 + round(($x - $cx1) / $site_w) * $site_w}]
        set y [m4_grid $y round]
        placeInstance [dbGet $b.name] [list $x $y] $o -fixed
        puts "def macro: [dbGet $b.name] $o box [dbGet $b.box]"
    }
}
if {[llength $blocks] && $macro_place eq "auto"} {
    # Mixed-size placement of macros + standard cells, then keep only the
    # macros: snap them to the site / M4 track grid, fix them, and unplace the
    # standard cells (place_opt_design places them again around the macros).
    # R90/R270 would turn the horizontal M4 pin stubs vertical.
    # No spacing constraints: -min_space_to_macro had no visible effect, and
    # -forbidden_space_to_core/-macro make refine_macro_place leave macros
    # overlapping when they cannot be met. The core sizing leaves room for
    # channels, and narrow gaps are handled after the row cut.
    set_macro_place_constraint -all_macros -orientation {R0 MX MY R180}
    # Without refine_macro_place the macros are not legalized (they overlap).
    setPlaceMode -place_global_place_io_pins false -place_design_refine_macro true
    place_design -concurrent_macros
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    foreach b $blocks {
        puts "place_design macro: [dbGet $b.name] [dbGet $b.orient] pt [dbGet $b.pt] box [dbGet $b.box]"
        lassign [lindex [dbGet $b.box] 0] bx1 by1 bx2 by2
        set x [expr {$cx1 + round(($bx1 - $cx1) / $site_w) * $site_w}]
        set y [m4_grid $by1 round]
        set x [expr {min(max($x, $cx1), $cx1 + floor(($cx2 - $cx1 - ($bx2 - $bx1)) / $site_w + 1e-6) * $site_w)}]
        set y [expr {min(max($y, [m4_grid $cy1 ceil]), [m4_grid [expr {$cy2 - ($by2 - $by1)}] floor])}]
        placeInstance [dbGet $b.name] [list $x $y] [dbGet $b.orient] -fixed
        # Macros whose PG straps are horizontal on a layer above M4 (gen_fakeram.py --pg-dir
        # horizontal: centred half an M4 pitch off the M4 grid): one M4 pitch up or down when the
        # straps would sit between that layer's tracks (its RIGHTWAYONGRIDONLY flags the strap
        # extensions; NS3K M6, pitch 2 x M4).
        set dy [macro_pg_track_dy $b]
        if {$dy != 0} {
            set y2 [expr {$y + $dy}]
            if {$y2 < [m4_grid $cy1 ceil] - 1e-6 || $y2 + ($by2 - $by1) > $cy2 + 1e-6} { set y2 [expr {$y - $dy}] }
            placeInstance [dbGet $b.name] [list $x $y2] [dbGet $b.orient] -fixed
        }
    }
    foreach b $blocks {
        foreach c $blocks {
            if {$c <= $b} continue
            lassign [lindex [dbGet $b.box] 0] a1 a2 a3 a4
            lassign [lindex [dbGet $c.box] 0] c1 c2 c3 c4
            if {$a1 < $c3 - 1e-3 && $c1 < $a3 - 1e-3 && $a2 < $c4 - 1e-3 && $c2 < $a4 - 1e-3} {
                error "auto macro placement: [dbGet $b.name] and [dbGet $c.name] overlap"
            }
        }
    }
    dbSet [dbGet -p2 top.insts.cell.baseClass core].pStatus unplaced
    # place_design leaves place_opt_design in incremental (seed) mode, which
    # refuses unplaced cells.
    setPlaceMode -place_opt_run_global_place full
}
if {[llength $blocks]} {
    foreach b $blocks { puts "macro [dbGet $b.name] [dbGet $b.orient] [dbGet $b.box]" }
}
# Front-side PDN: M8/M9 core ring in the core margin, BPR follow-pins extended
# out to it with BPR->M9 via stacks outside the core. Via stacks inside the
# core would collide with the dense M1 pins (0.042um pitch, ending 3nm from
# the rails), so the rails are fed only from the ring. Needs viaBPR0, which is
# inferred (the tf has no BPR->M0 contact). The ring goes in before any row
# is cut: -follow core follows the row outline, and a notch left by the row
# cuts (bp_fe_top) cut into a macro halo stripe.
set rw [expr {0.10 * $scale}]
set rs [expr {0.06 * $scale}]
# PG_RING_LAYERS "<horizontal> <vertical>" (experiments; default "M8 M9"): the
# rails end on the left/right (vertical) segments. "M4 M5" keeps the rail
# stacks below M5, every pad on an M2/M4 track (pitch 0.096 divides the 0.48
# row pitch; M6/M8 pitches do not, which RIGHTWAYONGRIDONLY on M6/M8 flags).
# With macros, the macro halo stripes go on the vertical ring layer (M9, or M5 with "M4 M5": then no PG
# shape is above M5, and none of the rail stacks has an M6/M8 pad).
lassign [design_param PG_RING_LAYERS "M8 M9"] ring_h ring_v
lappend run_params pg_ring_layers "$ring_h $ring_v"
# PG_RING_ONGRID=1 (strictly unidirectional LEFs): every ring side centred on a track of its layer,
# with the smallest offset / spacing >= rs that does it (NS3K M4/M5 ring: the VSS sides were up to
# half a pitch off, which verify_drc flags on the short rings of the small designs).
set ring_ongrid [design_param PG_RING_ONGRID 0]
lappend run_params pg_ring_ongrid $ring_ongrid
set ring_off [dict create top $rs bottom $rs left $rs right $rs]
set ring_sp  [dict create top $rs bottom $rs left $rs right $rs]
if {$ring_ongrid} {
    lassign [lindex [dbGet top.fPlan.coreBox] 0] rcx1 rcy1 rcx2 rcy2
    foreach side {top bottom left right} l [list $ring_h $ring_h $ring_v $ring_v] d {y y x x} \
            e [list $rcy2 $rcy1 $rcx1 $rcx2] sg {1 -1 -1 1} {
        set lo [dbGet -p head.layers.name $l]
        set t0 [dbGet $lo.[expr {$d eq "y" ? "offsetY" : "offsetX"}]]
        set tp [dbGet $lo.[expr {$d eq "y" ? "pitchY" : "pitchX"}]]
        foreach t [dbGet top.fPlan.tracks] {
            if {[dbGet $t.dir] eq $d && [lsearch [dbGet $t.layers.name] $l] >= 0} { set t0 [dbGet $t.start]; set tp [dbGet $t.step] }
        }
        # inner (VDD) side centre moved outwards onto the next track
        set k0 [expr {($e + $sg * ($rs + $rw / 2) - $t0) / $tp}]
        set dk [expr {$sg > 0 ? ceil($k0 - 1e-6) - $k0 : $k0 - floor($k0 + 1e-6)}]
        dict set ring_off $side [expr {$rs + $dk * $tp}]
        # outer (VSS) side a whole number of tracks further out
        dict set ring_sp $side [expr {ceil(($rw + $rs) / $tp - 1e-6) * $tp - $rw}]
    }
    puts "ring on grid: offsets $ring_off spacings $ring_sp"
}
addRing -nets {VDD VSS} -type core_rings -follow core \
        -layer  [list top $ring_h bottom $ring_h left $ring_v right $ring_v] \
        -width  [list top $rw bottom $rw left $rw right $rw] \
        -spacing [list top [dict get $ring_sp top] bottom [dict get $ring_sp bottom] left [dict get $ring_sp left] right [dict get $ring_sp right]] \
        -offset [list top [dict get $ring_off top] bottom [dict get $ring_off bottom] left [dict get $ring_off left] right [dict get $ring_off right]]

# Remove rows under each macro plus its halo (exactly once).
foreach b $blocks {
    lassign [lindex [dbGet $b.box] 0] bx1 by1 bx2 by2
    cutRow -area [list [expr {$bx1 - $halo}] [expr {$by1 - $halo}] [expr {$bx2 + $halo}] [expr {$by2 + $halo}]]
}
# A gap narrower than MACRO_CHANNEL_UM (1x) between a macro halo and the core
# edge or another macro halo would be a pocket of a few cells, hard to
# legalize, to route and to power: no rows there either.
set mac_ch [expr {$mac_ch_um * $scale}]
lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
set hb [lmap b $blocks {
    lassign [lindex [dbGet $b.box] 0] bx1 by1 bx2 by2
    list [expr {$bx1 - $halo}] [expr {$by1 - $halo}] [expr {$bx2 + $halo}] [expr {$by2 + $halo}]
}]
set pockets {}
foreach h $hb {
    lassign $h x1 y1 x2 y2
    foreach {g area} [list [expr {$x1 - $cx1}] [list $cx1 $y1 $x1 $y2] \
                           [expr {$cx2 - $x2}] [list $x2 $y1 $cx2 $y2] \
                           [expr {$y1 - $cy1}] [list $x1 $cy1 $x2 $y1] \
                           [expr {$cy2 - $y2}] [list $x1 $y2 $x2 $cy2]] {
        if {$g > 1e-3 && $g < $mac_ch} { lappend pockets $area }
    }
    foreach k $hb {
        if {$k eq $h} continue
        lassign $k u1 v1 u2 v2
        # k to the right of h, overlapping in y / k above h, overlapping in x
        if {$u1 - $x2 > 1e-3 && $u1 - $x2 < $mac_ch && $v1 < $y2 && $v2 > $y1} {
            lappend pockets [list $x2 [expr {max($y1, $v1)}] $u1 [expr {min($y2, $v2)}]]
        }
        if {$v1 - $y2 > 1e-3 && $v1 - $y2 < $mac_ch && $u1 < $x2 && $u2 > $x1} {
            lappend pockets [list [expr {max($x1, $u1)}] $y2 [expr {min($x2, $u2)}] $v1]
        }
    }
}
foreach a $pockets { cutRow -area $a }
puts "macro pockets narrower than $mac_ch_um um cut: [llength $pockets]"

set rail_targets {ring}
set m9_x {}
if {[llength $blocks]} {
    # Rows are cut at the macro halo, so rail segments boxed in between
    # macros cannot reach the ring: a VDD/VSS M9 stripe pair in the halo on
    # each side of every macro that has rows butting against that side of the
    # halo (no cells in the halo, so the BPR->M9 via stacks are clean) feeds
    # them. The stripes span the
    # die height and pick up the M8 ring at both ends.
    lassign [lindex [dbGet top.fPlan.box] 0] dx1 dy1 dx2 dy2
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    # PG_HALO_ONGRID=1 (strictly unidirectional tech LEFs, whose M9 takes
    # RIGHTWAYONGRIDONLY): each stripe centred on an M9 track, the VSS one two
    # tracks right of the VDD one (rs9 instead of rs). Otherwise addStripe snaps
    # each centre to a track by itself, the pair 0.64 apart (not a multiple of the
    # 0.352 pitch) moves off the row cuts made for it, and the rails beside the
    # macros end short of it (ariane133 under _unidir_dir: over 1000 dangling
    # rail ends).
    set halo_ongrid [design_param PG_HALO_ONGRID 0]
    lappend run_params pg_halo_ongrid $halo_ongrid
    # the halo stripes are on the vertical ring layer (M9 by default, M5 with PG_RING_LAYERS "M4 M5")
    set hl $ring_v
    set rs9 $rs
    if {$halo_ongrid} {
        # the design's M9 tracks (vertical: dir x), not the LEF OFFSET: the floorplan puts
        # them at multiples of the pitch (start 0.352 for OFFSET 0.176)
        set l9 [dbGet -p head.layers.name $hl]
        set p9 [dbGet $l9.pitchX]; set o9 [dbGet $l9.offsetX]
        foreach t [dbGet top.fPlan.tracks] {
            if {[dbGet $t.dir] eq "x" && [lsearch [dbGet $t.layers.name] $hl] >= 0} {
                set o9 [dbGet $t.start]; set p9 [dbGet $t.step]
            }
        }
        # the VSS stripe the fewest tracks right of the VDD one that keeps rs between them
        # (M9, pitch 0.352: two tracks; M5, pitch 0.176: four)
        set rs9 [expr {ceil(($rw + $rs) / $p9 - 1e-6) * $p9 - $rw}]
    }
    set pair [expr {2 * $rw + $rs9}]
    set stripe_x {}
    set row_boxes [lmap r [dbGet top.fPlan.rows] {lindex [dbGet $r.box] 0}]
    foreach b $blocks {
        lassign [lindex [dbGet $b.box] 0] bx1 by1 bx2 by2
        set left 0; set right 0
        foreach rb $row_boxes {
            lassign $rb rx1 ry1 rx2 ry2
            if {$ry2 <= $by1 - $halo || $ry1 >= $by2 + $halo} continue
            if {$rx2 > $bx1 - $halo - 2 * $site_w && $rx2 < $bx1 + 1e-3} { set left 1 }
            if {$rx1 < $bx2 + $halo + 2 * $site_w && $rx1 > $bx2 - 1e-3} { set right 1 }
        }
        # Each stripe keeps a window for its left edge x: a right-side stripe
        # must clear the macro (x >= bx2), a left-side one too (x + pair <=
        # bx1); rails beside a macro cannot reach a stripe over its body.
        # The window keeps 2 sites off the macro: a merged stripe 0.024 from a
        # macro edge got no BPR->M9 stacks on its near half (the via pads
        # would hit the macro OBS; 30 open VDD rails on bp_be_top).
        # PG_HALO_EVERY_MACRO=1: a macro with no rows butting on either side still gets a pair, on
        # the side farther from the core edge (a tie point of its own for its PG straps). Off by
        # default: every pair cuts a full-height strip of rows (ariane136: 85 pairs instead of 39,
        # placement density 141%), and the M6 straps reach the stripes of their neighbours.
        if {!$left && !$right && $hl ne "M9" && [design_param PG_HALO_EVERY_MACRO 0]} {
            if {$bx1 - $cx1 >= $cx2 - $bx2} { set left 1 } else { set right 1 }
        }
        set mg [expr {2 * $site_w}]
        set cand {}
        if {$left}  { lappend cand [list [expr {$bx1 - ($halo + $pair) / 2}] -1e9 [expr {$bx1 - $pair - $mg}]] }
        if {$right} { lappend cand [list [expr {$bx2 + ($halo - $pair) / 2}] [expr {$bx2 + $mg}] 1e9] }
        foreach c $cand {
            lassign $c xa lo hi
            set xa [expr {$cx1 + round(($xa - $cx1) / $site_w) * $site_w}]
            # Stripes that would overlap (e.g. beside two stacked macros a
            # little offset in x, or facing each other across a gap) become
            # one, placed inside both windows (centred when both sides are
            # bounded, else as far out as the tighter bound needs).
            set merged 0
            set alt {}
            for {set i 0} {$i < [llength $stripe_x]} {incr i} {
                lassign [lindex $stripe_x $i] xo lo0 hi0
                if {abs($xo - $xa) >= $pair + $rs} continue
                set merged 1
                set nlo [expr {max($lo0, $lo)}]; set nhi [expr {min($hi0, $hi)}]
                if {$nhi - $nlo < -1e-6} {
                    # Disjoint windows: two macros a little offset in x at
                    # different heights (1.06 apart on one bp_be_top), each
                    # pair would sit over the other macro. Put this pair
                    # right beside the other one (rs apart, site grid,
                    # inside its own window); each then crosses the other
                    # macro's body on M9, which is fine (macro OBS stops at
                    # M4, no rails there). Keeping only one pair left the
                    # rails of the other side open (bp_be_top: 80 VSS).
                    foreach xs [list [expr {$cx1 + floor(($xo - $pair - $rs - $cx1) / $site_w + 1e-6) * $site_w}] \
                                     [expr {$cx1 + ceil(($xo + $pair + $rs - $cx1) / $site_w - 1e-6) * $site_w}]] {
                        if {$xs < $lo - 1e-6 || $xs > $hi + 1e-6} continue
                        set ok 1
                        foreach c2 $stripe_x {
                            if {abs([lindex $c2 0] - $xs) < $pair + $rs - 1e-6} { set ok 0 }
                        }
                        if {$ok} { set alt [list $xs $lo $hi]; break }
                    }
                    if {[llength $alt]} {
                        puts "halo M9 stripes at $xo and $xa clash; $xa moved to [lindex $alt 0]"
                    } else {
                        puts "WARNING: halo M9 stripes at $xo and $xa clash and no position suits both; keeping $xo"
                    }
                    break
                }
                if {$nlo > -1e8 && $nhi < 1e8} {
                    set xn [expr {($nlo + $nhi) / 2}]
                } elseif {$nlo > -1e8} {
                    set xn [expr {max($xo, $xa, $nlo)}]
                } else {
                    set xn [expr {min($xo, $xa, $nhi)}]
                }
                # snap to the site grid without leaving the window
                set xs [expr {$cx1 + round(($xn - $cx1) / $site_w) * $site_w}]
                if {$xs < $nlo - 1e-6} { set xs [expr {$xs + $site_w}] }
                if {$xs > $nhi + 1e-6} { set xs [expr {$xs - $site_w}] }
                if {$xs < $nlo - 1e-6 || $xs > $nhi + 1e-6} { set xs $xn }
                lset stripe_x $i [list $xs $nlo $nhi]
                break
            }
            if {!$merged} { lappend stripe_x [list $xa $lo $hi] }
            if {[llength $alt]} { lappend stripe_x $alt }
        }
    }
    if {$halo_ongrid} {
        # nearest left edge whose stripe centre is on an M9 track, inside the
        # stripe's window
        set stripe_x [lmap c $stripe_x {
            lassign $c xs lo hi
            set k [expr {round(($xs + $rw / 2 - $o9) / $p9)}]
            set xg {}
            foreach dk {0 -1 1 -2 2 -3 3} {
                set xn [expr {$o9 + ($k + $dk) * $p9 - $rw / 2}]
                if {$xn >= $lo - 1e-6 && $xn <= $hi + 1e-6} { set xg $xn; break }
            }
            if {$xg eq ""} {
                set xg [expr {$o9 + $k * $p9 - $rw / 2}]
                puts "WARNING: no on-grid position for the halo M9 stripe pair at $xs in its window; $xg"
            }
            list $xg $lo $hi
        }]
    }
    set stripe_x [lmap c $stripe_x {lindex $c 0}]
    puts "halo $hl stripe pairs at x = $stripe_x"
    foreach xa [lsort -real $stripe_x] {
        # Each stripe ends at the outer edge of its own ring (VDD is the inner
        # ring, VSS the outer one), not at the die edge: the M9 IO pins on the
        # top/bottom die edge cut the tips off otherwise (riscv32i: a dangling
        # VSS piece), and a VDD stripe running on over the VSS ring dangles.
        foreach net {VDD VSS} xs [list $xa [expr {$xa + $rw + $rs9}]] k {0 1} {
            set rb [expr {[dict get $ring_off bottom] + $rw + $k * ([dict get $ring_sp bottom] + $rw)}]
            set rt [expr {[dict get $ring_off top] + $rw + $k * ([dict get $ring_sp top] + $rw)}]
            addStripe -nets $net -layer $hl -direction vertical -width $rw -number_of_sets 1 \
                      -area [list $xs [expr {$cy1 - $rb}] [expr {$xs + $rw}] [expr {$cy2 + $rt}]]
        }
        # The stripe drops a BPR->M9 stack on every rail it crosses, including
        # rows above/below the macro: no rows under the strip (sroute extends
        # the rails on both sides to the stripe, as in the halo).
        cutRow -area [list [expr {$xa - $site_w}] $cy1 [expr {$xa + $pair + $site_w}] $cy2]
    }
    # Row pieces left too narrow to hold cells (between a macro halo and a
    # stripe) would trap cells the legalizer cannot place: drop them.
    # Cutting a multi-height row splits the rows it overlaps and can leave
    # new slivers, so repeat until none is left. Narrow pieces with the same
    # x range in consecutive rows are cut as one area (one cutRow per row
    # piece took >15 min on bp_fe_top); the area is shrunk by 1 nm, as an
    # area equal to the row box does not always remove the row.
    set min_row_w [expr {1.0 * $scale}]
    set nrm 0; set ncut 0
    for {set pass 0} {$pass < 10} {incr pass} {
        set byx [dict create]
        foreach r [dbGet top.fPlan.rows] {
            lassign [lindex [dbGet $r.box] 0] rx1 ry1 rx2 ry2
            if {$rx2 - $rx1 < $min_row_w} {
                dict lappend byx [format "%.4f %.4f" $rx1 $rx2] [list $ry1 $ry2]
                incr nrm
            }
        }
        if {![dict size $byx]} break
        dict for {xr ys} $byx {
            lassign $xr x1 x2
            set ys [lsort -real -index 0 $ys]
            lassign [lindex $ys 0] y1 y2
            foreach iv [lrange $ys 1 end] {
                lassign $iv a b
                if {$a <= $y2 + 1e-3} { set y2 [expr {max($y2, $b)}]; continue }
                cutRow -area [list [expr {$x1 + 0.001}] [expr {$y1 + 0.001}] [expr {$x2 - 0.001}] [expr {$y2 - 0.001}]]
                incr ncut; set y1 $a; set y2 $b
            }
            cutRow -area [list [expr {$x1 + 0.001}] [expr {$y1 + 0.001}] [expr {$x2 - 0.001}] [expr {$y2 - 0.001}]]
            incr ncut
        }
    }
    set left 0
    foreach r [dbGet top.fPlan.rows] {
        lassign [lindex [dbGet $r.box] 0] rx1 ry1 rx2 ry2
        if {$rx2 - $rx1 < $min_row_w} { incr left }
    }
    puts "removed $nrm row pieces narrower than [expr {$min_row_w / $scale}] um with $ncut cuts ($left left after $pass passes)"
    set m9_x [lmap xa $stripe_x {list [expr {$xa - $site_w}] [expr {$xa + $pair + $site_w}]}]
    set rail_targets {ring stripe}
}
# SROUTE_VIA_SCALE (experiments): setSrouteMode -corePinMaxViaScale
# {widthPct heightPct} for the rail->ring/stripe stacks.
set sroute_via_scale [design_param SROUTE_VIA_SCALE none]
if {$sroute_via_scale ne "none"} { setSrouteMode -corePinMaxViaScale $sroute_via_scale }
lappend run_params sroute_via_scale $sroute_via_scale
sroute -connect {corePin} -nets {VDD VSS} -corePinTarget $rail_targets \
       -layerChangeRange [list $rail_layer M9] -targetViaLayerRange [list $rail_layer M9] \
       -allowJogging 0 -allowLayerChange 0
if {[llength $blocks]} {
    # Macro PG straps (M5) go straight to the ring. After the rails: a strap
    # extended first ran under another macro's halo stripe and blocked every
    # BPR->M9 stack of the other net there (bp_fe_top); now the extension
    # has to avoid the stacks (each macro has several straps per net).
    # Jogging allowed and the halo stripes as targets too: with straight
    # extensions to the ring only, 5 of ariane133's 133 densely packed
    # macros got one of their two straps blocked and lost VDD or VSS.
    # With the M4/M5 ring the extensions stay on M4/M5 (jogs on M4, which takes off-grid shapes; none
    # on M6/M8, whose RIGHTWAYONGRIDONLY flags them).
    # (macro straps horizontal on M6, gen_fakeram.py --pg-dir horizontal: extensions on M6 itself)
    set mpl {}
    foreach b $blocks { lappend mpl {*}[dbGet $b.cell.pgTerms.pins.allShapes.layer.name] }
    set mpl [lsort -unique $mpl]
    set bp_layers [expr {$ring_v eq "M9" ? {M5 M9} : ("M6" in $mpl ? [list $ring_v M6] : [list M4 $ring_v])}]
    sroute -connect {blockPin} -nets {VDD VSS} -blockPinTarget {ring stripe} \
           -layerChangeRange $bp_layers -targetViaLayerRange $bp_layers -allowJogging 1
}

# M3 PG stripes (on by default; PG_M3_PITCH_UM 0 turns them off): vertical VDD/VSS M3 pairs every
# PG_M3_PITCH_UM across the core, tied to every BPR rail they cross with a
# BPR->M3 stack, ending on a rail inside the core (stripe width and the
# VDD-VSS gap are PG_M3_WIDTH_UM). The stack pads on M1 would collide with
# cell M1 pins; PG_M3_BLOCK picks how placement avoids them:
#   none: no blockage (default). Placement first drops cells on the pads,
#         later refinePlace moves them off; final layouts are clean, at the
#         cost of more congestion around the stripes.
#   hard: hard placement blockage over pair + PG_M3_BLOCK_SITES sites on
#         each side (default 1; 0 = the pair only)
#   partial: partial placement blockage (at most PG_M3_BLOCK_DENSITY % cells,
#         default 30) over pair + PG_M3_BLOCK_SITES sites on each side
#         (default 1): Innovus' counterpart of Xplace's lower target density
#         in the M3 stripe bins; place_opt_design and its incremental
#         placement honour it
#   soft: soft placement blockage over pair + PG_M3_BLOCK_SITES sites on each
#         side: kept free by global placement only; legalization and
#         optimization may put cells there
#   obs:  no blockage; placer told to treat M1 preroutes as obstructions
#         (made no difference at global placement in our runs)
# Stripes run only over rows (split around macros, halos, pockets) and stay
# clear of the halo M9 stripes.
# PG_STYLE=pillar puts the same pairs on $pg_layer (M5) instead: every
# crossing with a rail of its net gets a via pillar (rail->M5 stack with
# pads on M1..M4), and M3 carries no stripe, only the pillars' pads. The
# straps also stay off every macro strap extension on their own layer (a
# horizontal M5 one would short with them).
if {$m3_pitch_um > 0} {
    # PG_VIA_PREF: the vias of the stripe/pillar crossing stacks (made by addStripe and editPowerVia), set
    # after sroute: the rail -> ring stacks keep the generated vias (the fixed 2-cut ones left rail ends open)
    if {$pg_via_pref ne ""} { setViaGenMode -viarule_preference $pg_via_pref }
    set sw   [expr {$m3_width_um * $scale}]
    # VSS strap/stripe offset from the VDD one (left edges): 2 widths
    set dvss [expr {2 * $sw}]
    # PG_STRAP_ONGRID=1 (pillar; with the strictly unidirectional LEFs, whose M5 takes
    # RIGHTWAYONGRIDONLY): both straps centred on tracks of $pg_layer, the VSS one the number of
    # tracks nearest 2 widths right of the VDD one (NS3K M5: 2 x 0.176 for 2 x 0.192), the pair
    # centred on a site centre. Otherwise the straps sit up to half a pitch off the tracks, which
    # verify_drc flags next to macros (OFFGRID).
    set strap_ongrid [expr {$pg_style eq "pillar" && [design_param PG_STRAP_ONGRID 0]}]
    lappend run_params pg_strap_ongrid $strap_ongrid
    if {$strap_ongrid} {
        set lp [dbGet -p head.layers.name $pg_layer]
        set tp [dbGet $lp.pitchX]; set to [dbGet $lp.offsetX]
        foreach t [dbGet top.fPlan.tracks] {
            if {[dbGet $t.dir] eq "x" && [lsearch [dbGet $t.layers.name] $pg_layer] >= 0} {
                set to [dbGet $t.start]; set tp [dbGet $t.step]
            }
        }
        set dvss [expr {max(1, round(2 * $sw / $tp)) * $tp}]
    }
    set pair [expr {$dvss + $sw}]
    set p    [expr {$m3_pitch_um * $scale}]
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    lassign [lindex [dbGet top.fPlan.box] 0] dx1 dy1 dx2 dy2
    set rail_hw [expr {$rail_hw1 * $scale}]
    catch {
        lassign [lindex [dbGet [lindex [dbGet -p2 top.pgNets.sWires.shape followpin] 0].box] 0] - fy1 - fy2
        set rail_hw [expr {($fy2 - $fy1) / 2}]
    }
    set row1_boxes [lmap r [dbGet -p2 top.fPlan.rows.site.name $site_name] {lindex [dbGet $r.box] 0}]
    # vertical macro PG strap extensions (sroute blockPin), on any layer,
    # and every one on the stripe layer itself
    set v_blockwires {}
    foreach n {VDD VSS} {
        foreach w [dbGet [dbGet -p top.pgNets.name $n].sWires] {
            if {[dbGet $w.shape] ne "blockwire"} continue
            lassign [lindex [dbGet $w.box] 0] w1 w2 w3 w4
            if {$w4 - $w2 > $w3 - $w1 || [dbGet $w.layer.name] eq $pg_layer} { lappend v_blockwires [list $w1 $w2 $w3 $w4] }
        }
    }
    set nset 0
    for {set x [expr {$cx1 + $p / 2}]} {$x + $pair + $site_w < $cx2} {set x [expr {$x + $p}]} {
        # centre the pair in a whole number of sites
        set x0 [expr {$cx1 + round(($x - $cx1) / $site_w) * $site_w + ($site_w - $pair) / 2}]
        if {$strap_ongrid} {
            # the VDD strap centre on the track nearest its place in the centred pair
            set xc [expr {$to + round(($x0 + $sw / 2 - $to) / $tp) * $tp}]
            set x0 [expr {$xc - $sw / 2}]
        }
        set b1 [expr {$x0 - $site_w}]; set b2 [expr {$x0 + $pair + $site_w}]
        # Stay clear of the halo M9 stripes: their BPR->M9 stacks have M3 pads.
        set clash 0
        foreach xr $m9_x {
            lassign $xr m1 m2
            if {$b2 > $m1 && $b1 < $m2} { set clash 1 }
        }
        if {$clash} continue
        # The stripe runs where rows cover its whole band (so every piece has
        # rails to tie to: no macros, halos, pockets or halo M9 stripes). It
        # stays inside the core: M3->M8 stacks down from the ring were
        # blocked by the IO pins at the die edge (bp_fe_top).
        set ivs {}
        foreach rb $row1_boxes {
            lassign $rb rx1 ry1 rx2 ry2
            if {$rx1 <= $b1 + 1e-3 && $rx2 >= $b2 - 1e-3} { lappend ivs [list $ry1 $ry2] }
        }
        set segs {}
        foreach iv [lsort -real -index 0 $ivs] {
            lassign $iv r1 r2
            if {[llength $segs] && $r1 <= [lindex $segs end 1] + 1e-3} {
                lset segs end 1 [expr {max([lindex $segs end 1], $r2)}]
            } else {
                lappend segs [list $r1 $r2]
            }
        }
        # x within 2*halo of a macro edge: stay off the rows beside the macro
        # (+halo) too, clear of the macro pin stubs.
        foreach b $blocks {
            lassign [lindex [dbGet $b.box] 0] a1 a2 a3 a4
            if {!($b2 > $a1 - 2 * $halo && $b1 < $a3 + 2 * $halo)} continue
            set e1 [expr {$a2 - $halo}]; set e2 [expr {$a4 + $halo}]
            set new {}
            foreach sg $segs {
                lassign $sg s1 s2
                if {$e2 <= $s1 || $e1 >= $s2} { lappend new $sg; continue }
                if {$e1 > $s1} { lappend new [list $s1 $e1] }
                if {$e2 < $s2} { lappend new [list $e2 $s2] }
            }
            set segs $new
        }
        # No stripe piece under a vertical macro PG strap extension (the
        # blockwire sroute runs from the macro to the ring or a halo stripe):
        # the stacks there get moved or dropped (NSFET_5T bp_fe_top: two VDD
        # pieces below/above a macro dangled). That holds on any layer:
        # blockPin jogs within M5-M9, and the stacks an M7 extension drops to
        # its own rails cut the other net's M3 stripe into dangling pieces
        # (swerv_wrapper: 14 open VDD ends).
        set new {}
        foreach sg $segs {
            lassign $sg s1 s2
            set hit 0
            foreach bw $v_blockwires {
                lassign $bw w1 w2 w3 w4
                if {$b2 > $w1 && $b1 < $w3 && $s2 > $w2 && $s1 < $w4} { set hit 1; break }
            }
            if {!$hit} { lappend new $sg }
        }
        set segs $new
        foreach sg $segs {
            lassign $sg s1 s2
            if {$s2 - $s1 < 6 * $row_h} continue
            # Both ends are pulled in onto a rail of the stripe's own net (boundary k from the core bottom is VDD when k is even,
            # see create_multi_height_rows) at least one row inside the row
            # area, covering the whole rail width, so they end on a BPR->M3
            # stack (editPowerVia uses the exact crossover) instead of
            # dangling. VDD and VSS are therefore added separately.
            foreach net {VDD VSS} xs [list $x0 [expr {$x0 + $dvss}]] par {0 1} {
                set k [expr {int(ceil(($s1 - $cy1) / $row_h - 1e-6)) + 1}]
                if {$k % 2 != $par} { incr k }
                set y1 [expr {$cy1 + $k * $row_h - $rail_hw}]
                set k [expr {int(floor(($s2 - $cy1) / $row_h + 1e-6)) - 1}]
                if {$k % 2 != $par} { incr k -1 }
                set y2 [expr {$cy1 + $k * $row_h + $rail_hw}]
                if {$y2 - $y1 < 2 * $row_h} continue
                if {$m3_snap eq "None"} {
                    add_shape -layer $pg_layer -net $net -shape STRIPE -status FIXED \
                              -rect [list $xs $y1 [expr {$xs + $sw}] $y2]
                } else {
                    addStripe -nets $net -layer $pg_layer -direction vertical -width $sw \
                              -number_of_sets 1 -area [list $xs $y1 [expr {$xs + $sw}] $y2]
                }
            }
            if {$m3_block eq "hard"} {
                set mg [expr {$m3_block_sites * $site_w}]
                createPlaceBlockage -type hard \
                    -box [list [expr {$x0 - $mg}] [expr {max($s1, $cy1)}] [expr {$x0 + $pair + $mg}] [expr {min($s2, $cy2)}]]
            } elseif {$m3_block eq "partial"} {
                set mg [expr {$m3_block_sites * $site_w}]
                createPlaceBlockage -type partial -density $m3_block_density \
                    -box [list [expr {$x0 - $mg}] [expr {max($s1, $cy1)}] [expr {$x0 + $pair + $mg}] [expr {min($s2, $cy2)}]]
            } elseif {$m3_block eq "soft"} {
                set mg [expr {$m3_block_sites * $site_w}]
                createPlaceBlockage -type soft \
                    -box [list [expr {$x0 - $mg}] [expr {max($s1, $cy1)}] [expr {$x0 + $pair + $mg}] [expr {min($s2, $cy2)}]]
            }
            incr nset
        }
    }
    editPowerVia -add_vias 1 -nets {VDD VSS} -bottom_layer $rail_layer -top_layer $pg_layer \
                 -orthogonal_only 1 -via_using_exact_crossover_size 1
    # routing layer number of M1 (BPR=1, M0=2, M1=3; without BPR: M0=1, M1=2)
    if {$m3_block eq "obs"} { setPlaceMode -place_detail_preroute_as_obs [expr {$rail_layer eq "BPR" ? 3 : 2}] }
    puts "pg_m3_stripes: $nset sets on $pg_layer ($pg_style), pitch $m3_pitch_um um, width $m3_width_um um, block $m3_block"
}

# No editTrim here: when two macros leave no room for a halo stripe between
# them, sroute leaves dangling rail stubs (bp_be_top: 39, cosmetic; the rails
# reach another stripe), but editTrim also cut the rail from the row start to
# its first via, and the cells later placed there lost VDD.
# Tracks at offset 0 (the ROUTE_UNIDIR LEFs) put one track on each die edge,
# and NanoRoute uses it (tinyRocket: M4 wires half outside the die, 11
# OFFGRID + 5 Out Of Die on M5 at the via above). A thin routing blockage
# over every edge track of those layers keeps the router off it; it stays
# clear of the next track's wires (pitch - width/2 - spacing from the edge).
# (Deeper IO pins, above, let the pins be reached from inner tracks.)
lassign [lindex [dbGet top.fPlan.box] 0] dx1 dy1 dx2 dy2
set nedge 0
foreach l [dbGet head.layers] {
    if {[dbGet $l.type] ne "routing" || [dbGet $l.name] in {BPR M0}} continue
    set hz [expr {[dbGet $l.direction] eq "Horizontal"}]
    set pt [dbGet $l.[expr {$hz ? "pitchY" : "pitchX"}]]
    set of [dbGet $l.[expr {$hz ? "offsetY" : "offsetX"}]]
    if {$pt <= 0 || $of != 0} continue
    set b [expr {($pt - [dbGet $l.width] / 2 - [dbGet $l.minSpacing]) / 2}]
    if {$b <= 0} continue
    set lo [expr {$hz ? $dy1 : $dx1}]; set hi [expr {$hz ? $dy2 : $dx2}]
    foreach e [list $lo $hi] s {1 -1} {
        set k [expr {($e - $lo - $of) / $pt}]
        if {abs($k - round($k)) > 1e-6} continue
        set e2 [expr {$e + $s * $b}]
        set box [expr {$hz ? [list $dx1 [expr {min($e, $e2)}] $dx2 [expr {max($e, $e2)}]]
                          : [list [expr {min($e, $e2)}] $dy1 [expr {max($e, $e2)}] $dy2]}]
        createRouteBlk -box $box -layer [dbGet $l.name] -name edge_track
        incr nedge
    }
}
puts "die-edge track blockages: $nedge"
# PG check and floorplan DEF right after the macros and the PDN are in, before
# hours of place and route: rpt/conn_pg_floorplan.rpt, <top>.floorplan.def
# (die, rows, pins, macros, VDD/VSS special nets). With PG_CHECK_ABORT=1
# (default) the run stops here if VDD/VSS are not clean; the DB is saved
# first so it can be restored and inspected.
verifyConnectivity -net {VDD VSS} -type special -noUnroutedNet -report $out/rpt/conn_pg_floorplan.rpt
set npg 0
catch {
    set fh [open $out/rpt/conn_pg_floorplan.rpt]
    foreach {- n} [regexp -all -inline {\n\s*(\d+) Problem\(s\)} [read $fh]] { incr npg $n }
    close $fh
}
puts "PG check after floorplan: $npg problem(s) (rpt/conn_pg_floorplan.rpt)"
defOut -floorplan $out/$DESIGN_TOP.floorplan.def
saveDesign -libs $out/db/floorplan.enc
if {$npg > 0 && [design_param PG_CHECK_ABORT 1]} {
    error "VDD/VSS not clean after the floorplan/PDN ($npg problems, see rpt/conn_pg_floorplan.rpt)"
}
# PDN_ONLY=1 (PDN work; with PG_CHECK_ABORT=0): verify_drc of the PDN alone (rpt/drc_pdn.rpt), then stop
if {[design_param PDN_ONLY 0]} {
    # standard-cell area over the 1-high row area left (> 1: the placer refuses, IMPSP-190)
    set ra 0
    foreach r [dbGet -p2 top.fPlan.rows.site.name $site_name] {
        lassign [lindex [dbGet $r.box] 0] x1 y1 x2 y2
        set ra [expr {$ra + ($x2 - $x1) * ($y2 - $y1)}]
    }
    set sa [expr [join [dbGet [dbGet -p2 top.insts.cell.baseClass core].area] +]]
    puts "PDN_ONLY std cell density [format %.3f [expr {$sa / max($ra, 1e-9)}]] (std area $sa, row area $ra)"
    verify_drc -report $out/rpt/drc_pdn.rpt -limit 100000
    exit
}
if {[info exists env(STOP_AFTER)] && $env(STOP_AFTER) eq "floorplan"} { return }

# ------------------------------------------------------------------ place
setPlaceMode -place_global_place_io_pins false
if {$placer eq "xplace"} {
    source $pdk/innovus_enablement/pnr/xplace_place.tcl
} else {
    place_opt_design -out_dir $out/rpt/place
}
checkPlace $out/rpt/checkPlace.rpt
saveDesign -libs $out/db/place.enc
if {[info exists env(STOP_AFTER)] && $env(STOP_AFTER) eq "place"} {
    verify_drc -report $out/rpt/drc_place.rpt -limit 100000
    verifyConnectivity -net {VDD VSS} -type special -report $out/rpt/conn_pg_place.rpt
    exit
}

# ------------------------------------------------------------------ CTS
set_ccopt_property buffer_cells   {BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16}
set_ccopt_property inverter_cells {INV_X1 INV_X2 INV_X4 INV_X8 INV_X16}
# Clock slew target per PDK ($cts_trans, above the minimum CCOpt reports).
set_ccopt_property target_max_trans $cts_trans
create_route_type -name clk_rt -bottom_preferred_layer M3 -top_preferred_layer M4
set_ccopt_property route_type clk_rt -net_type trunk
set_ccopt_property route_type clk_rt -net_type leaf
create_ccopt_clock_tree_spec -file $out/ccopt.spec
source $out/ccopt.spec
ccopt_design
optDesign -postCTS -hold -outDir $out/rpt/cts
saveDesign -libs $out/db/cts.enc

# ------------------------------------------------------------------ route
setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven false
routeDesign
setExtractRCMode -engine postRoute -effortLevel low
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -hold -outDir $out/rpt/route
# Final DRC clean-up pass (removes most leftovers at dense pin clusters).
# Off by default (ECO_ROUTE=0) to save runtime; a few more DRCs are acceptable.
if {$eco_route} { ecoRoute -fix_drc }
saveDesign -libs $out/db/route.enc

# ------------------------------------------------------------------ signoff-ish
timeDesign -postRoute        -outDir $out/rpt/final -prefix final
timeDesign -postRoute -hold  -outDir $out/rpt/final -prefix final
report_area  > $out/rpt/area.rpt
report_power -outfile $out/rpt/power.rpt
summaryReport -noHtml -outfile $out/rpt/summary.rpt
verify_drc -report $out/rpt/drc.rpt -limit 100000
verifyConnectivity -type all -report $out/rpt/conn.rpt
checkPlace $out/rpt/checkPlace_final.rpt

rcOut -spef $out/$DESIGN_TOP.spef
saveNetlist $out/${DESIGN_TOP}.pnr.v
defOut -floorplan -netlist -routing $out/$DESIGN_TOP.def
# Routing-only GDS at LEF_SCALE x; cell GDS (1x) is merged after descaling.
streamOut $out/$DESIGN_TOP.gds -mapFile $enab/${pdk_name}_streamOut.map \
          -units 2000 -mode ALL
exit
