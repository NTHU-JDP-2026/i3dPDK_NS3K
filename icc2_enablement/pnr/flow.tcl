# IC Compiler II PnR flow for i3dPDK_NS3K (LIB NS3K_<N>T, e.g. NS3K_5T), at
# the PDK's native geometry (TECH/*.tf, the PDK cell data rebuilt by ndm/, TLU+): no 4x scaling, which
# only the Innovus flow needs (its invs_3nm licence check).
# The physical set-up follows innovus_enablement/pnr/flow.tcl: core on the
# track grid, IO pins on M4-M11, M0 rails fed from an M8/M9 core ring, M3
# VDD/VSS stripe pairs tied to the rails, M2-M4 unidirectional on track,
# signals on M2-SIGNAL_TOP_LAYER.
# Env: PDK_ROOT DESIGN LIB OUT_DIR [FLOW=fast|full] [THREADS] [STOP_AFTER=floorplan|place]
#      [CLK_PERIOD_NS] [UTIL] [IO_PIN_TRACKS] [IO_PIN_LAYERS] [PG_M3_PITCH_UM]
#      [PG_M3_WIDTH_UM] [PG_M3_BLOCK=none|hard|partial] [PG_M3_BLOCK_DENSITY]
#      [PG_M3_BLOCK_SITES] [SIGNAL_TOP_LAYER] [ROUTE_UNIDIR=0|1] [PLACE_OPT=0|1]
#      [ROUTE_MAX_ITER] [MACRO_HALO_UM] [MACRO_CHANNEL_UM] [MIN_CHANNEL_UM]
#      [MACRO_AREA_SLACK] [PG_CHECK_ABORT] [ROUTE_GUIDE_LAYERS]  -- override syn/designs/<design>.tcl
# FLOW=fast (default): place_opt, CTS (build + route clock), route_auto, no
# post-CTS / post-route optimization (as innovus_enablement/pnr/flow_fast.tcl).
# FLOW=full: clock_opt with its final optimization, route_auto + route_opt.
# Every run records its resolved parameters in $OUT_DIR/run_params.json.
set pdk    $env(PDK_ROOT)
set design $env(DESIGN)
set lib    $env(LIB)
set out    $env(OUT_DIR)
lassign [split $lib _] arch trk
if {$arch ne "NS3K"} { error "this flow is for LIB NS3K_<N>T, not $lib" }
proc design_param {name default} {
    global env
    if {[info exists env($name)]} { return $env($name) }
    if {[uplevel #0 [list info exists $name]]} { return [uplevel #0 [list set $name]] }
    return $default
}
source $pdk/icc2_enablement/pdk_config.tcl
source $syn_dir/designs/$design.tcl
set CLK_PERIOD_NS [design_param CLK_PERIOD_NS 1.0]
set util          [design_param UTIL 0.6]
set io_trk        [design_param IO_PIN_TRACKS 4]
set io_layers_n   [design_param IO_PIN_LAYERS 4]
set m3_pitch_um   [design_param PG_M3_PITCH_UM 2.0]
set m3_width_um   [design_param PG_M3_WIDTH_UM 0.048]
set m3_block      [design_param PG_M3_BLOCK none]
if {$m3_block ni {none hard partial}} { error "PG_M3_BLOCK must be none, hard or partial, not $m3_block" }
set m3_block_density [design_param PG_M3_BLOCK_DENSITY 30]
set m3_block_sites   [design_param PG_M3_BLOCK_SITES 1]
# PG_STYLE: stripe (default) = the M3 VDD/VSS stripe pairs below; pillar = the
# same pairs as straps on PG_PILLAR_LAYER (default M5), tied to every rail of
# their net by a rail->strap via stack (pads on M1..M4, no M3 stripe), as in
# the Innovus flow (innovus_enablement/pnr/flow.tcl).
set pg_style      [design_param PG_STYLE stripe]
if {$pg_style ni {stripe pillar}} { error "PG_STYLE must be stripe or pillar, not $pg_style" }
set pg_layer      [expr {$pg_style eq "pillar" ? [design_param PG_PILLAR_LAYER M5] : "M3"}]
set sig_top       [design_param SIGNAL_TOP_LAYER M11]
set place_opt     [design_param PLACE_OPT 1]
set route_max_iter [design_param ROUTE_MAX_ITER 0]
set flow          [design_param FLOW fast]
if {$flow ni {fast full}} { error "FLOW must be fast or full, not $flow" }
set threads [expr {[info exists env(THREADS)] ? $env(THREADS) : 8}]
if {![info exists MACROS]} { set MACROS {} }
set netlist   $syn_dir/out/$design/$lib/${DESIGN_TOP}.v
set macro_ndms [lmap m $MACROS {file join $macro_ndm_dir $m.ndm}]
foreach f [concat $netlist $cell_ndm $macro_ndms $tech_tf $tluplus] {
    if {![file exists $f]} { error "missing input $f" }
}
file mkdir $out/rpt
set_host_options -max_cores $threads

# ------------------------------------------------------------------ run record
proc json_str {v} { return "\"[string map {\\ \\\\ \" \\\"} $v]\"" }
proc write_run_params {} {
    global out run_params
    set fh [open $out/run_params.json w]
    puts $fh "\{\n[join [lmap {k v} $run_params {string cat "  " [json_str $k] ": " [json_str $v]}] ",\n"]\n\}"
    close $fh
}
set flow_version unknown
catch { set fh [open $enab/.flow_version]; set flow_version [string trim [read $fh]]; close $fh }
set run_params [list \
    design $design lib $lib pdk $pdk_name top $DESIGN_TOP tag [file tail $out] tool icc2 \
    clk_period_ns $CLK_PERIOD_NS util $util macros $MACROS io_pin_tracks $io_trk io_pin_layers $io_layers_n \
    pg_m3_pitch_um $m3_pitch_um pg_m3_width_um $m3_width_um pg_m3_block $m3_block \
    pg_m3_block_density $m3_block_density pg_m3_block_sites $m3_block_sites pg_style $pg_style pg_layer $pg_layer \
    signal_top_layer $sig_top route_unidir $route_unidir place_opt $place_opt \
    route_max_iter $route_max_iter lef_scale 1 flow $flow \
    flow_version $flow_version started [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] \
    host [info hostname] out_dir $out]
write_run_params

# ------------------------------------------------------------------ library, netlist
create_lib $out/$DESIGN_TOP.nlib -technology $tech_tf -ref_libs [concat $cell_ndm $macro_ndms]
read_verilog -top $DESIGN_TOP $netlist
current_block $DESIGN_TOP
link_block
# Instances of cells no library defines are dropped, as Innovus treats them
# (an empty module): ariane133's netlist has 3 clockless Yosys $_FF_ cells
# (unmapped by dfflibmap), which place_opt refuses (ROPT-007).
set unbound [get_cells -quiet -hierarchical -filter "is_unbound==true"]
lappend run_params unbound_cells_removed [sizeof_collection $unbound]
if {[sizeof_collection $unbound]} {
    puts "WARNING: removing [sizeof_collection $unbound] instance(s) of undefined cells: [lsort -unique [get_attribute $unbound ref_name]] ([get_object_name $unbound])"
    remove_cells $unbound
}
foreach {l d} $layer_dirs {
    if {[sizeof_collection [get_layers -quiet $l]]} { set_attribute [get_layers $l] routing_direction $d }
}
foreach c $dont_use { set_lib_cell_purpose -include none [get_lib_cells */$c] }

# ------------------------------------------------------------------ timing set-up
# One mode/corner; wire RC from the PDK's TLU+ (native geometry: no factors).
read_parasitic_tech -tlup $tluplus -layermap $tlu_map -name typ
create_mode func
create_corner tt
create_scenario -name func_tt -mode func -corner tt
current_scenario func_tt
set_parasitic_parameters -early_spec typ -late_spec typ -corners tt
set io_dly [expr {0.2 * $CLK_PERIOD_NS}]
# read_sdc takes no remove_from_collection: the data inputs are listed.
set data_in [expr {$CLK_PORT eq "" ? {} : [get_object_name [get_ports -quiet -filter "direction==in && name!=$CLK_PORT"]]}]
set sdc $out/$DESIGN_TOP.sdc
set fh [open $sdc w]
# CLK_PORT "" (synthetic designs without IO, e.g. aoi300): no clock, no IO constraints
if {$CLK_PORT ne ""} {
puts $fh "create_clock -name clk -period $CLK_PERIOD_NS \[get_ports $CLK_PORT\]
set_clock_uncertainty 0.01 \[get_clocks clk\]
set_clock_transition 0.01 \[get_clocks clk\]
set_input_delay  $io_dly -clock clk \[get_ports \{$data_in\}\]
set_output_delay $io_dly -clock clk \[all_outputs\]
set_driving_cell -lib_cell BUF_X1 -pin Z \[get_ports \{$data_in\}\]
set_load 1 \[all_outputs\]"
}
close $fh
read_sdc $sdc
set_scenario_status func_tt -active true -setup true -hold true -max_transition true \
    -max_capacitance true -leakage_power false -dynamic_power false

# ------------------------------------------------------------------ PG nets
# Multi-row cells have VDD_1/VDD_2/VSS_1/VSS_2; the PDK has no TIE cells, so
# netlist constants are tied straight to the rails.
create_net -power VDD
create_net -ground VSS
connect_pg_net -net VDD [get_pins -quiet -hierarchical -filter "port_type==power"]
connect_pg_net -net VSS [get_pins -quiet -hierarchical -filter "port_type==ground"]
set tie_hi [get_pins -quiet -hierarchical -filter "constant_value==1 && direction==in"]
set tie_lo [get_pins -quiet -hierarchical -filter "constant_value==0 && direction==in"]
if {[sizeof_collection $tie_hi]} { connect_pg_net -net VDD $tie_hi }
if {[sizeof_collection $tie_lo]} { connect_pg_net -net VSS $tie_lo }
puts "constant pins tied to the rails: [sizeof_collection $tie_hi] to VDD, [sizeof_collection $tie_lo] to VSS"

# ------------------------------------------------------------------ floorplan
proc snap_up {v g} { expr {ceil($v / $g - 1e-6) * $g} }
proc bbox4 {obj} { lassign [get_attribute $obj bbox] p1 p2; concat $p1 $p2 }
# boxes of all site rows (a collection is no Tcl list: no lmap over it)
proc row_boxes {} {
    set l {}
    foreach_in_collection r [get_site_rows] { lappend l [bbox4 $r] }
    return $l
}
# a cell's own outline (its bbox includes a keepout margin)
proc cellbox4 {obj} { lassign [get_attribute $obj boundary_bbox] p1 p2; concat $p1 $p2 }
# Track pitch of a layer: the tf pitch, never below width + spacing (tf M11:
# 0.11 < 0.112, as the Innovus tech LEF)
proc track_pitch {l} {
    set p [get_attribute [get_layers $l] pitch]
    catch { set p [expr {max($p, [get_attribute [get_layers $l] min_width] + [get_attribute [get_layers $l] min_spacing])}] }
    return $p
}
# First track of a layer: offset 0 on the unidirectional layers (a track on
# every row boundary, rows hold tracks 1-4), pitch/2 elsewhere, as in the
# Innovus tech LEFs; a track on the die edge itself is left out.
proc track_start {l} {
    global route_unidir unidir_layers
    set p [track_pitch $l]
    return [expr {$route_unidir && $l in $unidir_layers ? $p : $p / 2}]
}
set site   [get_site_defs $site_name]
set site_w [get_attribute $site width]
set row_h  [get_attribute $site height]
set std_area 0.0
foreach_in_collection c [get_cells -hierarchical -filter "is_hierarchical==false && design_type==lib_cell"] {
    set std_area [expr {$std_area + [get_attribute $c area]}]
}
set blocks [get_cells -quiet -hierarchical -filter "is_hierarchical==false && design_type==macro"]
set nblk   [sizeof_collection $blocks]
# Macro parameters (1x um), as in the Innovus flow
set halo      [design_param MACRO_HALO_UM 0.5]
set mac_ch    [design_param MACRO_CHANNEL_UM 2.0]
set min_ch    [design_param MIN_CHANNEL_UM 10.0]
set mac_slack [design_param MACRO_AREA_SLACK 1.25]
lappend run_params macro_halo_um $halo macro_channel_um $mac_ch min_channel_um $min_ch macro_area_slack $mac_slack
# IO pin layers: IO_PIN_LAYERS horizontal (M4/M6/M8/M10, left/right sides) and
# vertical (M5/M7/M9/M11, top/bottom) layers up to SIGNAL_TOP_LAYER.
set top_n [string range $sig_top 1 end]
set io_hlayers {}; set io_vlayers {}
foreach l {M4 M6 M8 M10} { if {[string range $l 1 end] <= $top_n && [llength $io_hlayers] < $io_layers_n} { lappend io_hlayers $l } }
foreach l {M5 M7 M9 M11} { if {[string range $l 1 end] <= $top_n && [llength $io_vlayers] < $io_layers_n} { lappend io_vlayers $l } }
set io_nl [expr {min([llength $io_hlayers], [llength $io_vlayers])}]
set m4_pitch [track_pitch M4]
set io_pitch $m4_pitch
foreach l [concat $io_hlayers $io_vlayers] { set io_pitch [expr {max($io_pitch, [track_pitch $l])}] }

if {$nblk} {
    # The core holds the standard cells at UTIL plus every macro with its halo
    # (MACRO_AREA_SLACK margin). The core width is scanned and, for each
    # width, the macros are shelf-packed (slack pk); a shelf with two or more
    # macros also reserves one MIN_CHANNEL_UM logic channel. Aspect ratio
    # within 1:2..2:1, every side takes a quarter of the IO pins at one pin
    # per IO_PIN_TRACKS tracks; smallest area wins, with a penalty on the
    # aspect ratio. (The Innovus flow's MACRO_PLACE=auto sizing.)
    set mac_area 0; set dims {}
    foreach_in_collection b $blocks {
        lassign [cellbox4 $b] bx1 by1 bx2 by2
        set bw [expr {$bx2 - $bx1 + 2 * $halo}]
        set bh [expr {$by2 - $by1 + 2 * $halo}]
        set mac_area [expr {$mac_area + $bw * $bh}]
        lappend dims [list $bw $bh]
    }
    set pk       [expr {max(1.05, sqrt($mac_slack))}]
    set dims     [lsort -real -decreasing -index 1 $dims]
    set area     [expr {$std_area / $util + $mac_area * $mac_slack}]
    set min_side [expr {ceil([sizeof_collection [get_ports]] / 4.0 / $io_nl) * $io_trk * $io_pitch}]
    set max_w    [tcl::mathfunc::max {*}[lmap d $dims {lindex $d 0}]]
    set sum_w    [expr [join [lmap d $dims {lindex $d 0}] +] + $min_ch]
    set best {}
    for {set i 0} {$i <= 400} {incr i} {
        set W [expr {$pk * ($max_w + ($sum_w - $max_w) * $i / 400.0)}]
        foreach W [list $W [expr {sqrt($area)}] $min_side] {
            if {$W < $pk * $max_w || $W < $min_side} continue
            set hm 0; set rw0 0; set rh 0; set rn 0
            foreach d $dims {
                lassign $d w h
                set nw [expr {$rn == 1 ? $rw0 + $w + $min_ch : $rw0 + $w}]
                if {$rn > 0 && $nw > $W / $pk + 1e-6} {
                    set hm [expr {$hm + $rh}]; set rw0 0; set rh 0; set rn 0; set nw $w
                }
                set rw0 $nw; set rh [expr {max($rh, $h)}]; incr rn
            }
            set H [expr {max($pk * ($hm + $rh), $area / $W, $W / 2.0, $min_side)}]
            if {$H > 2 * $W} continue
            set score [expr {$W * $H * (1 + 0.2 * abs(log($W / $H)))}]
            if {![llength $best] || $score < [lindex $best 0]} { set best [list $score $W $H] }
        }
    }
    lassign $best - core_w core_h
    puts "macro floorplan: std_area $std_area macro_area(+halo) $mac_area"
} else {
    set core_w [expr {sqrt($std_area / $util)}]
    set core_h $core_w
}
set core_w [snap_up $core_w $site_w]
set core_h [snap_up $core_h [expr {2 * $row_h}]]
# Core origin on the track grid: x on the site / M1 / M3 grid (0.044), y on the
# M0 / M2 / M4 grid (0.024), so every row holds M2 tracks 1-4 and every M1
# pin is centred on an M3 track (as in the Innovus flow).
set m_x [snap_up 0.5 $site_w]
set m_y [snap_up 0.5 0.024]
# -use_site_row: plain site rows, which cut_rows can cut (it leaves the
# default site arrays alone, NDMUI-552: rows stayed under the macros).
initialize_floorplan -control_type core -shape R -side_length [list $core_w $core_h] \
    -core_offset [list $m_x $m_y] -site_def $site_name -flip_first_row true -use_site_row
lassign [lindex [get_attribute [current_block] boundary_bbox] 1] dx2 dy2
set cx1 $m_x; set cy1 $m_y; set cx2 [expr {$m_x + $core_w}]; set cy2 [expr {$m_y + $core_h}]
puts "floorplan: core ($cx1 $cy1) ($cx2 $cy2), die $dx2 x $dy2, std_area $std_area"

# Tracks on every routing layer in its preferred direction, from the die origin.
remove_tracks -all
foreach {l d} $layer_dirs {
    if {$l eq "M0" || ![sizeof_collection [get_layers -quiet $l]]} continue
    set p   [track_pitch $l]
    set off [track_start $l]
    set len [expr {$d eq "horizontal" ? $dy2 : $dx2}]
    set n [expr {int(floor(($len - $off) / $p - 1e-6)) + 1}]
    create_track -layer $l -dir [expr {$d eq "horizontal" ? "Y" : "X"}] -coord $off -space $p -count $n
}
set_ignored_layers -min_routing_layer M2 -max_routing_layer $sig_top
# ROUTE_UNIDIR=1: every routing layer (M2-SIGNAL_TOP_LAYER) in its preferred
# direction only, as a hard rule: a preferred-direction-only routing guide over
# the die, honoured by global routing during placement, clock routing and the
# router. M2-M4 wires and VIA2-VIA4 are also on track. (The tf has no
# per-layer direction rule; the Innovus flow uses LEF58_RIGHTWAYONGRIDONLY on
# M2-M4 only.) VIA1 is not put on the grid: OR3_X1's A1/A2 M1 pins are centred
# 2 nm off the M1/M3 track grid, and an on-grid VIA1 there needed an M1 patch
# wider than tall, a non-preferred-direction route on M1 (jpeg, swerv,
# tinyRocket). Its M2 side is on track through M2's wire grid anyway.
# ROUTE_GUIDE_LAYERS overrides the guide's layers.
set guide_def {}
for {set i 2} {$i <= $top_n} {incr i} { lappend guide_def M$i }
set guide_layers [design_param ROUTE_GUIDE_LAYERS $guide_def]
lappend run_params route_guide_layers $guide_layers
if {$route_unidir} {
    create_routing_guide -name unidir -boundary [list [list 0 0] [list $dx2 $dy2]] \
        -layers $guide_layers -preferred_direction_only
    set_app_options -name route.common.wire_on_grid_by_layer_name -value [lmap l $unidir_layers {list $l true}]
    set_app_options -name route.common.via_on_grid_by_layer_name -value {{VIA2 true} {VIA3 true} {VIA4 true}}
}
# ROUTE_M1: by default ICC2 extends pins on M1 to reach a free M2 track
# (jpeg: 41207 vertical M1 segments, 1952 um, 3328 longer than a row).
#   0:      connect_within_pins M1 via_standard_cell_pins (jpeg: still 29699
#           M1 segments beyond the pins, 1574 longer than a row)
#   forbid: forbid_new_metal M1: no new M1 metal at all, as NanoRoute with
#           bottom routing layer M2 in the Innovus flow
set route_m1 [design_param ROUTE_M1 1]
lappend run_params route_m1 $route_m1
if {$route_m1 eq "0"} {
    set_app_options -name route.common.connect_within_pins_by_layer_name -value {{M1 via_standard_cell_pins}}
} elseif {$route_m1 eq "forbid"} {
    set_app_options -name route.common.forbid_new_metal_by_layer_name -value {{M1 true}}
}

# IO pins: one pin per IO_PIN_TRACKS tracks, horizontal layers on the
# left/right, vertical on the top/bottom.
# The clock port goes on M4 (left/right): the clock routing rule (M3-M4)
# leaves a clock port on any other layer unrouted (ZRT-130; serv and
# dynamic_node had their clk port on M7 and the clock root net open).
if {[sizeof_collection [get_ports -quiet *]]} {
    set_block_pin_constraints -self -allowed_layers [concat $io_hlayers $io_vlayers] -pin_spacing $io_trk -sides {1 2 3 4}
    if {$CLK_PORT ne ""} { set_individual_pin_constraints -ports [get_ports $CLK_PORT] -allowed_layers M4 }
    place_pins -self
}

# ------------------------------------------------------------------ core ring
# M8/M9 core ring in the core margin; M0 rails extended out to it, tied by
# M0->M9 via stacks outside the core (stacks inside the core would hit the
# dense M1 pins). Before any row is cut: the ring follows the row outline, and
# around a cut pocket it ran into a halo M9 stripe (tinyRocket).
set rw 0.10
set rs 0.06
# PG_RING_LAYERS "<horizontal> <vertical>" (experiments; default "M8 M9"), as
# in the Innovus flow: "M4 M5" keeps the rail stacks below M5, every pad on an
# M2/M4 track. Designs without macros only (the halo stripes assume M8/M9).
lassign [design_param PG_RING_LAYERS "M8 M9"] ring_h ring_v
lappend run_params pg_ring_layers "$ring_h $ring_v"
create_pg_ring_pattern ring_pat -horizontal_layer $ring_h -horizontal_width $rw -horizontal_spacing $rs \
    -vertical_layer $ring_v -vertical_width $rw -vertical_spacing $rs
set_pg_strategy ring_s -core -pattern {{name: ring_pat} {nets: {VDD VSS}} {offset: {0.06 0.06}}}
compile_pg -strategies ring_s
# Ring extent per net: {x of the left M9 segment, x of the right one, y of the
# bottom M8 segment's outer edge, y of the top one's outer edge}
foreach net {VDD VSS} {
    set xs {}; set ys {}
    foreach_in_collection s [get_shapes -of_objects [get_nets $net] -filter "shape_use==ring"] {
        lassign [bbox4 $s] s1 s2 s3 s4
        if {$s4 - $s2 > $s3 - $s1} { lappend xs [list $s1 $s3] } else { lappend ys [list $s2 $s4] }
    }
    set xs [lsort -real -index 0 $xs]; set ys [lsort -real -index 0 $ys]
    dict set ring $net [list [lindex $xs 0] [lindex $xs end] [lindex $ys 0 0] [lindex $ys end 1]]
}

# ------------------------------------------------------------------ macros
# Macro signal pins are M4 stubs at pitch/2 + k*pitch from the macro origin
# (gen_fakeram.py; the macro height is a whole number of M4 pitches, so MX and
# R180 keep that too): the macro y goes on (first M4 track) - pitch/2 +
# k*pitch, x on the site grid. R90/R270 would turn the stubs vertical.
proc m4_grid {y mode} {
    global m4_pitch
    set y0 [expr {[track_start M4] - $m4_pitch / 2}]
    expr {$y0 + [::tcl::mathfunc::$mode [expr {($y - $y0) / $m4_pitch + ($mode eq "ceil" ? -1e-6 : $mode eq "floor" ? 1e-6 : 0)}]] * $m4_pitch}
}
set macro_boxes {}
if {$nblk} {
    set_macro_constraints -allowed_orientations {R0 MX MY R180} $blocks
    # hard keepout = the halo: no standard cells there (it carries the macro
    # pin escapes and the halo M9 stripes)
    create_keepout_margin -type hard -outer [list $halo $halo $halo $halo] $blocks
    # Macro + halo inside the core (ICC2 lets the keepout run past the core
    # edge; the rows left between such a macro and the edge got a halo M9
    # stripe on top of the ring): a temporary hard_macro blockage one halo wide
    # along the core edge.
    set edge_blk {}
    foreach bb [list [list [list $cx1 $cy1] [list [expr {$cx1 + $halo}] $cy2]] \
                     [list [list [expr {$cx2 - $halo}] $cy1] [list $cx2 $cy2]] \
                     [list [list $cx1 $cy1] [list $cx2 [expr {$cy1 + $halo}]]] \
                     [list [list $cx1 [expr {$cy2 - $halo}]] [list $cx2 $cy2]]] {
        lappend edge_blk [create_placement_blockage -type hard_macro -boundary $bb]
    }
    create_placement -floorplan -effort high
    foreach b $edge_blk { remove_placement_blockages $b }
    # keep the macros only: the coarse standard-cell placement it also makes
    # sits off the rows (M0 shorts with the rails in check_pg_drc)
    set_attribute [get_cells -hierarchical -filter "is_hierarchical==false && design_type==lib_cell"] physical_status unplaced
    foreach_in_collection b $blocks {
        lassign [cellbox4 $b] bx1 by1 bx2 by2
        set x [expr {$cx1 + round(($bx1 - $cx1) / $site_w) * $site_w}]
        set y [m4_grid $by1 round]
        set x [expr {min(max($x, $cx1 + [snap_up $halo $site_w]), $cx1 + floor(($cx2 - $halo - $cx1 - ($bx2 - $bx1)) / $site_w + 1e-6) * $site_w)}]
        set y [expr {min(max($y, [m4_grid [expr {$cy1 + $halo}] ceil]), [m4_grid [expr {$cy2 - $halo - ($by2 - $by1)}] floor])}]
        move_objects -delta [list [expr {$x - $bx1}] [expr {$y - $by1}]] $b
        set_placement_status fixed $b
        lassign [cellbox4 $b] bx1 by1 bx2 by2
        lappend macro_boxes [list $bx1 $by1 $bx2 $by2]
        puts "macro [get_object_name $b] [get_attribute $b orientation] {$bx1 $by1 $bx2 $by2}"
    }
    foreach a $macro_boxes {
        foreach c $macro_boxes {
            if {$c eq $a} continue
            lassign $a a1 a2 a3 a4; lassign $c c1 c2 c3 c4
            if {$a1 < $c3 - 1e-3 && $c1 < $a3 - 1e-3 && $a2 < $c4 - 1e-3 && $c2 < $a4 - 1e-3} {
                error "macro placement: macros at {$a} and {$c} overlap"
            }
        }
    }
    # Rows: none under a macro (+1 site / +1 row: rails stay clear of its M0
    # OBS); rows in the halo stay (the keepout keeps cells out) so its rails
    # reach the halo M9 stripes. A gap narrower than MACRO_CHANNEL_UM between a
    # macro halo and the core edge or another halo would be a pocket of a few
    # cells, hard to legalize, route and power: a hard placement blockage
    # there. (Cutting its rows as the Innovus flow does left rail pieces above
    # two neighbouring macros that reached neither halo stripe: bp_be_top,
    # bp_fe_top.)
    foreach a $macro_boxes {
        lassign $a x1 y1 x2 y2
        cut_rows -within [list [list [expr {$x1 - $site_w}] [expr {$y1 - $row_h}]] [list [expr {$x2 + $site_w}] [expr {$y2 + $row_h}]]]
    }
    set hb [lmap a $macro_boxes {
        lassign $a x1 y1 x2 y2
        list [expr {$x1 - $halo}] [expr {$y1 - $halo}] [expr {$x2 + $halo}] [expr {$y2 + $halo}]
    }]
    set pockets {}
    foreach h $hb {
        lassign $h x1 y1 x2 y2
        foreach {g ar} [list [expr {$x1 - $cx1}] [list $cx1 $y1 $x1 $y2] \
                             [expr {$cx2 - $x2}] [list $x2 $y1 $cx2 $y2] \
                             [expr {$y1 - $cy1}] [list $x1 $cy1 $x2 $y1] \
                             [expr {$cy2 - $y2}] [list $x1 $y2 $x2 $cy2]] {
            if {$g > 1e-3 && $g < $mac_ch} { lappend pockets $ar }
        }
        foreach k $hb {
            if {$k eq $h} continue
            lassign $k u1 v1 u2 v2
            if {$u1 - $x2 > 1e-3 && $u1 - $x2 < $mac_ch && $v1 < $y2 && $v2 > $y1} {
                lappend pockets [list $x2 [expr {max($y1, $v1)}] $u1 [expr {min($y2, $v2)}]]
            }
            if {$v1 - $y2 > 1e-3 && $v1 - $y2 < $mac_ch && $u1 < $x2 && $u2 > $x1} {
                lappend pockets [list [expr {max($x1, $u1)}] $y2 [expr {min($x2, $u2)}] $v1]
            }
        }
    }
    foreach a $pockets {
        lassign $a x1 y1 x2 y2
        create_placement_blockage -type hard -boundary [list [list $x1 $y1] [list $x2 $y2]]
    }
    puts "macro pockets narrower than $mac_ch um blocked: [llength $pockets]"
}

# ------------------------------------------------------------------ PDN
set m9_x {}
set m9_targets {}
if {$nblk} {
    # Halo M9 stripes: rails boxed in between macros cannot reach the ring, so
    # a VDD/VSS M9 stripe pair in the halo on each side of every macro that has
    # rows beside it feeds them (M0->M9 stacks; the halo has no cells). The
    # stripes span the core and pick up the M8 ring at both ends, each at the
    # outer edge of its own ring. Overlapping pairs (e.g. beside two stacked
    # macros a little offset in x, or facing each other across a gap) become
    # one, inside both windows; a pair whose window is disjoint from the other
    # one's goes right beside it. (The Innovus flow's halo stripes.)
    set pair [expr {2 * $rw + $rs}]
    set stripe_x {}
    set row_boxes [row_boxes]
    set mg [expr {2 * $site_w}]
    foreach a $macro_boxes {
        lassign $a bx1 by1 bx2 by2
        set left 0; set right 0
        foreach rb $row_boxes {
            lassign $rb rx1 ry1 rx2 ry2
            if {$ry2 <= $by1 - $halo || $ry1 >= $by2 + $halo} continue
            if {$rx2 > $bx1 - $halo - 2 * $site_w && $rx2 < $bx1 + 1e-3} { set left 1 }
            if {$rx1 < $bx2 + $halo + 2 * $site_w && $rx1 > $bx2 - 1e-3} { set right 1 }
        }
        set cand {}
        if {$left}  { lappend cand [list [expr {$bx1 - ($halo + $pair) / 2}] -1e9 [expr {$bx1 - $pair - $mg}]] }
        if {$right} { lappend cand [list [expr {$bx2 + ($halo - $pair) / 2}] [expr {$bx2 + $mg}] 1e9] }
        foreach c $cand {
            lassign $c xa lo hi
            set xa [expr {$cx1 + round(($xa - $cx1) / $site_w) * $site_w}]
            # inside the core only (outside it the ring feeds the rails)
            if {$xa < $cx1 - 1e-6 || $xa + $pair > $cx2 + 1e-6} continue
            set merged 0
            set alt {}
            for {set i 0} {$i < [llength $stripe_x]} {incr i} {
                lassign [lindex $stripe_x $i] xo lo0 hi0
                if {abs($xo - $xa) >= $pair + $rs} continue
                set merged 1
                set nlo [expr {max($lo0, $lo)}]; set nhi [expr {min($hi0, $hi)}]
                if {$nhi - $nlo < -1e-6} {
                    foreach xs [list [expr {$cx1 + floor(($xo - $pair - $rs - $cx1) / $site_w + 1e-6) * $site_w}] \
                                     [expr {$cx1 + ceil(($xo + $pair + $rs - $cx1) / $site_w - 1e-6) * $site_w}]] {
                        if {$xs < $lo - 1e-6 || $xs > $hi + 1e-6} continue
                        set ok 1
                        foreach c2 $stripe_x { if {abs([lindex $c2 0] - $xs) < $pair + $rs - 1e-6} { set ok 0 } }
                        if {$ok} { set alt [list $xs $lo $hi]; break }
                    }
                    if {![llength $alt]} { puts "WARNING: halo M9 stripes at $xo and $xa clash and no position suits both; keeping $xo" }
                    break
                }
                if {$nlo > -1e8 && $nhi < 1e8} {
                    set xn [expr {($nlo + $nhi) / 2}]
                } elseif {$nlo > -1e8} {
                    set xn [expr {max($xo, $xa, $nlo)}]
                } else {
                    set xn [expr {min($xo, $xa, $nhi)}]
                }
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
    set stripe_x [lsort -real [lmap c $stripe_x {
        set xs [lindex $c 0]
        expr {min(max($xs, $cx1), $cx1 + floor(($cx2 - $pair - $cx1) / $site_w + 1e-6) * $site_w)}
    }]]
    puts "halo M9 stripe pairs at x = $stripe_x"
    foreach xa $stripe_x {
        foreach net {VDD VSS} xs [list $xa [expr {$xa + $rw + $rs}]] {
            lassign [dict get $ring $net] - - ylo yhi
            create_shape -shape_type rect -layer M9 -net $net -shape_use stripe \
                -boundary [list [list $xs $ylo] [list [expr {$xs + $rw}] $yhi]]
            lappend m9_targets [list $net [expr {$xs + $rw / 2}]]
        }
        # no cells under the strip (its M0->M9 stacks)
        create_placement_blockage -type hard \
            -boundary [list [list [expr {$xa - $site_w}] $cy1] [list [expr {$xa + $pair + $site_w}] $cy2]]
        lappend m9_x [list [expr {$xa - $site_w}] [expr {$xa + $pair + $site_w}]]
    }
    # Row pieces too narrow to hold cells (left between cuts, e.g. between
    # two macros 0.22 um apart): dropped, with their rails (otherwise rail
    # stubs whose only stacks would sit at a macro edge).
    set narrow {}
    foreach_in_collection r [get_site_rows] {
        lassign [bbox4 $r] rx1 ry1 rx2 ry2
        if {$rx2 - $rx1 < 1.0} { lappend narrow $r }
    }
    foreach r $narrow { remove_site_rows $r }
    set left 0
    foreach_in_collection r [get_site_rows] {
        lassign [bbox4 $r] rx1 ry1 rx2 ry2
        if {$rx2 - $rx1 < 1.0} { incr left }
    }
    puts "removed [llength $narrow] row pieces narrower than 1 um ($left left)"
}
foreach net {VDD VSS} {
    lassign [dict get $ring $net] l r
    lappend m9_targets [list $net [expr {([lindex $l 0] + [lindex $l 1]) / 2}]] [list $net [expr {([lindex $r 0] + [lindex $r 1]) / 2}]]
}

create_pg_std_cell_conn_pattern rail_pat -layers $rail_layer -rail_width [list $rail_w $rail_w]
set_pg_strategy rail_s -core -pattern {{name: rail_pat} {nets: {VDD VSS}}} -extension {{stop: outermost_ring}}
set_pg_strategy_via_rule rail_via -via_rule {
    {{{strategies: rail_s}} {existing: ring} {via_master: default}}
    {{intersection: undefined} {via_master: NIL}}
}
compile_pg -strategies rail_s -via_rule rail_via
# compile_pg draws the rails along the core, around the macros but not only
# over rows: pieces shorter than any row left (1 um), e.g. in a 0.22 um gap
# between two macros, would only be tied by stacks at a macro edge. Removed.
set short_rails [get_shapes -quiet -filter "layer_name==$rail_layer && shape_use==lib_cell_pin_connect && width < 1.0"]
set nsr 0
foreach_in_collection r $short_rails {
    lassign [bbox4 $r] r1 r2 r3 r4
    if {$r3 - $r1 < 1.0} { remove_shapes $r; incr nsr }
}
puts "rail pieces shorter than 1 um removed: $nsr"

# Polarity of the rails: which net runs on the core's bottom boundary (rail
# boundary k from the core bottom carries VDD when k % 2 == par0).
set bottom_net ""
foreach net {VDD VSS} {
    foreach_in_collection s [get_shapes -quiet -of_objects [get_nets $net] -filter "layer_name==$rail_layer"] {
        lassign [bbox4 $s] - p2 - p4
        if {abs(($p2 + $p4) / 2 - $cy1) < 1e-4} { set bottom_net $net }
    }
}
if {$bottom_net eq ""} { error "no $rail_layer rail on the core bottom boundary" }
set par0 [expr {$bottom_net eq "VDD" ? 0 : 1}]
puts "rails: $bottom_net on the core bottom boundary"

if {$nblk} {
    # Halo stripes: to the rails they cross and to their ring at both ends.
    # No rail stacks where a stripe runs within 2 sites of a macro edge (over
    # that macro's y range + 2 sites): their M1-M4 pads would sit on the
    # macro's M4 pin escapes. A stripe is placed 2 sites off its own macro,
    # but a moved pair (disjoint merge windows) or a stripe passing another
    # macro's halo can come closer (swerv_wrapper: 28 shorts between macro pin
    # nets and VSS/VDD stack pads 0.02-0.03 um from a macro edge).
    set ko [expr {2 * $site_w}]
    foreach net {VDD VSS} {
        set boxes {}
        foreach_in_collection s [get_shapes -filter "layer_name==M9 && shape_use==stripe && owner.name==$net"] {
            lassign [bbox4 $s] s1 s2 s3 s4
            set ivs [list [list $s2 $s4]]
            foreach a $macro_boxes {
                lassign $a a1 a2 a3 a4
                if {!($s1 < $a3 + $ko && $s3 > $a1 - $ko)} continue
                set e1 [expr {$a2 - $ko}]; set e2 [expr {$a4 + $ko}]
                set new {}
                foreach iv $ivs {
                    lassign $iv v1 v2
                    if {$e2 <= $v1 || $e1 >= $v2} { lappend new $iv; continue }
                    if {$e1 > $v1} { lappend new [list $v1 $e1] }
                    if {$e2 < $v2} { lappend new [list $e2 $v2] }
                }
                set ivs $new
            }
            foreach iv $ivs {
                lassign $iv v1 v2
                lappend boxes [list [list [expr {$s1 - 0.01}] $v1] [list [expr {$s3 + 0.01}] $v2]]
            }
        }
        if {[llength $boxes]} {
            create_pg_vias -nets $net -from_layers M9 -to_layers $rail_layer -from_types stripe -within_bbox $boxes
        }
    }
    create_pg_vias -nets {VDD VSS} -from_layers M9 -to_layers M8 -from_types stripe -to_types ring
    # Macro PG: the macro's M5 straps are tied by M6 straps across the macro,
    # each centred on a rail of its own net (a VDD/VSS pair every ~2 um), which
    # run out to the nearest M9 of their net on either side (halo stripe or
    # ring). On the rail grid, two straps that meet always carry the same net,
    # and a strap crossing the other net's M9 stays clear of that net's
    # rail->M9 stacks (one row away).
    set sw6 0.06
    set nstrap 0
    foreach a $macro_boxes {
        lassign $a bx1 by1 bx2 by2
        set k1 [expr {int(ceil(($by1 - $cy1) / $row_h - 1e-6)) + 2}]
        set k2 [expr {int(floor(($by2 - $cy1) / $row_h + 1e-6)) - 2}]
        for {set k $k1} {$k + 1 <= $k2} {incr k 16} {
            foreach kk [list $k [expr {$k + 1}]] {
                set net [expr {$kk % 2 == $par0 ? "VDD" : "VSS"}]
                set y [expr {$cy1 + $kk * $row_h}]
                set xl -1e9; set xr 1e9
                foreach t $m9_targets {
                    lassign $t tn tx
                    if {$tn ne $net} continue
                    if {$tx < $bx1 && $tx > $xl} { set xl $tx }
                    if {$tx > $bx2 && $tx < $xr} { set xr $tx }
                }
                create_shape -shape_type rect -layer M6 -net $net -shape_use stripe \
                    -boundary [list [list [expr {$xl - $rw / 2}] [expr {$y - $sw6 / 2}]] [list [expr {$xr + $rw / 2}] [expr {$y + $sw6 / 2}]]]
                incr nstrap
            }
        }
    }
    create_pg_vias -nets {VDD VSS} -from_layers M6 -to_layers M5 -from_types stripe
    create_pg_vias -nets {VDD VSS} -from_layers M9 -to_layers M6 -from_types {stripe ring} -to_types stripe
    puts "macro M6 straps: $nstrap"
}

# M3 PG stripes (PG_M3_PITCH_UM 0 turns them off): vertical VDD/VSS pairs
# (stripe width and VDD-VSS gap PG_M3_WIDTH_UM) every PG_M3_PITCH_UM across the
# core, each pair centred on a site, tied to every rail of its net it crosses
# by an M0->M3 stack. They run only where rows cover the whole band (split
# around macros), stay off the halo M9 stripes and off the rows beside a macro
# (+halo) within 2 halos of its edge; both ends are pulled in onto a rail of
# the stripe's own net at least one row inside the row area, so they end on a
# stack.
#   PG_M3_BLOCK none: no blockage (default); hard: hard placement blockage over
#   the pair + PG_M3_BLOCK_SITES sites each side; partial: at most
#   PG_M3_BLOCK_DENSITY % cells there.
set nset 0
if {$m3_pitch_um > 0} {
    set sw   $m3_width_um
    set pair [expr {3 * $sw}]
    set p    $m3_pitch_um
    set rail_hw [expr {$rail_w / 2}]
    set row_boxes [row_boxes]
    for {set x [expr {$cx1 + $p / 2}]} {$x + $pair + $site_w < $cx2} {set x [expr {$x + $p}]} {
        set x0 [expr {$cx1 + round(($x - $cx1) / $site_w) * $site_w + ($site_w - $pair) / 2}]
        set b1 [expr {$x0 - $site_w}]; set b2 [expr {$x0 + $pair + $site_w}]
        set clash 0
        foreach xr $m9_x {
            lassign $xr m1 m2
            if {$b2 > $m1 && $b1 < $m2} { set clash 1 }
        }
        if {$clash} continue
        set ivs {}
        foreach rb $row_boxes {
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
        foreach a $macro_boxes {
            lassign $a a1 a2 a3 a4
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
        set placed 0
        foreach sg $segs {
            lassign $sg s1 s2
            if {$s2 - $s1 < 6 * $row_h} continue
            foreach net {VDD VSS} xs [list $x0 [expr {$x0 + 2 * $sw}]] par [list $par0 [expr {1 - $par0}]] {
                set k [expr {int(ceil(($s1 - $cy1) / $row_h - 1e-6)) + 1}]
                if {$k % 2 != $par} { incr k }
                set y1 [expr {$cy1 + $k * $row_h - $rail_hw}]
                set k [expr {int(floor(($s2 - $cy1) / $row_h + 1e-6)) - 1}]
                if {$k % 2 != $par} { incr k -1 }
                set y2 [expr {$cy1 + $k * $row_h + $rail_hw}]
                if {$y2 - $y1 < 2 * $row_h} continue
                create_shape -shape_type rect -layer $pg_layer -net $net -shape_use stripe \
                    -boundary [list [list $xs $y1] [list [expr {$xs + $sw}] $y2]]
            }
            if {$m3_block ne "none"} {
                set mg [expr {$m3_block_sites * $site_w}]
                set bb [list [list [expr {$x0 - $mg}] [expr {max($s1, $cy1)}]] [list [expr {$x0 + $pair + $mg}] [expr {min($s2, $cy2)}]]]
                if {$m3_block eq "hard"} {
                    create_placement_blockage -type hard -boundary $bb
                } else {
                    create_placement_blockage -type partial -blocked_percentage [expr {100 - $m3_block_density}] -boundary $bb
                }
            }
            set placed 1
        }
        incr nset $placed
    }
    # PG_VIA_WIDE=1 (experiments): the stripe/pillar -> rail stacks with the vias Innovus' editPowerVia
    # -via_using_exact_crossover_size makes in the Innovus flow (1x2 cuts, pads stretched: M0-M2 enclosure
    # 9 x 3 nm, M2-M4 9 x 1 nm, M4/M5 9 x 6 nm, e.g. the M2 pad 48 x 16 nm instead of 32 x 12 nm)
    set pg_via_wide [design_param PG_VIA_WIDE 0]
    lappend run_params pg_via_wide $pg_via_wide
    set vm {}
    if {$pg_via_wide} {
        foreach {cut lo hi ex ey} {VIA0 M0 M1 0.009 0.003  VIA1 M1 M2 0.009 0.003  VIA2 M2 M3 0.009 0.001
                                   VIA3 M3 M4 0.009 0.001  VIA4 M4 M5 0.009 0.006} {
            set n PGW_$cut
            create_via_def -force $n -cut_layer $cut -lower_layer $lo -upper_layer $hi -cut_size {0.01 0.01} \
                -lower_enclosure [list $ex $ey] -upper_enclosure [list $ex $ey] -min_rows 1 -min_columns 2 \
                -xy_min_cut_spacing {0.01 0.01}
            lappend vm $n
        }
        # PG_VIA_DRC: create_pg_vias -drc option (no_check: inserted as is; default: ICC2's own DRC handling)
        set pg_via_drc [design_param PG_VIA_DRC no_check]
        lappend run_params pg_via_drc $pg_via_drc
        set vm [list -via_masters $vm {*}[expr {$pg_via_drc eq "default" ? {} : [list -drc $pg_via_drc]}]]
    }
    create_pg_vias -nets {VDD VSS} -from_layers $pg_layer -to_layers $rail_layer -from_types stripe -within_bbox [list [list $cx1 $cy1] [list $cx2 $cy2]] {*}$vm
}
puts "pg_m3_stripes: $nset sets on $pg_layer ($pg_style), pitch $m3_pitch_um um, width $m3_width_um um, block $m3_block"
write_run_params

# PG check and floorplan DEF before place and route. With PG_CHECK_ABORT=1
# (default) the run stops here if VDD/VSS have floating pieces (the block is
# saved first so it can be inspected).
redirect -file $out/rpt/pg_floorplan.rpt { check_pg_connectivity -check_std_cell_pins none }
redirect -append -file $out/rpt/pg_floorplan.rpt { check_pg_drc }
set npg 0
set fh [open $out/rpt/pg_floorplan.rpt]
foreach {- n} [regexp -all -inline {Number of floating [a-z ]+:\s*(\d+)} [read $fh]] { incr npg $n }
close $fh
puts "PG check after floorplan: $npg floating object(s) (rpt/pg_floorplan.rpt)"
write_def -include {rows_tracks vias specialnets ports blockages} $out/$DESIGN_TOP.floorplan.def
save_block -as floorplan
if {$npg > 0 && [design_param PG_CHECK_ABORT 1]} {
    save_lib
    error "VDD/VSS not clean after the floorplan/PDN ($npg floating, see rpt/pg_floorplan.rpt)"
}
if {[info exists env(STOP_AFTER)] && $env(STOP_AFTER) eq "floorplan"} { save_lib; exit }

# ------------------------------------------------------------------ place
set_app_options -name place.coarse.continue_on_missing_scandef -value true
# PLACE_PG_ADV=1 (experiments): ICC2's stricter PG-aware legalization and pin-density-aware placement
# (defaults: advanced prerouted-net check and advanced legalizer off, 1 track for the access check,
# no EOL spacing in it, touching tracks allowed, coarse placement not pin-density aware)
set place_pg_adv [design_param PLACE_PG_ADV 0]
lappend run_params place_pg_adv $place_pg_adv
if {$place_pg_adv} {
    set_app_options -name place.legalize.enable_advanced_prerouted_net_check -value true
    set_app_options -name place.legalize.enable_advanced_legalizer -value true
    set_app_options -name place.legalize.num_tracks_for_access_check -value 2
    set_app_options -name place.legalize.use_eol_spacing_for_access_check -value true
    set_app_options -name place.legalize.allow_touch_track_for_access_check -value false
    set_app_options -name place.coarse.pin_density_aware -value true
}
if {$place_opt} {
    place_opt
} else {
    create_placement
    legalize_placement
}
redirect -file $out/rpt/check_legality.rpt { check_legality -verbose }
save_block -as place
if {[info exists env(STOP_AFTER)] && $env(STOP_AFTER) eq "place"} {
    write_def $out/$DESIGN_TOP.place.def
    save_lib; exit
}

# ------------------------------------------------------------------ CTS
set_lib_cell_purpose -exclude cts [get_lib_cells */*]
set_lib_cell_purpose -include cts [get_lib_cells [lmap c [concat $cts_bufs $cts_invs] {string cat */ $c}]]
# no clock (CLK_PORT ""): no CTS
if {$CLK_PORT ne ""} {
    set_max_transition $cts_trans -clock_path [get_clocks clk]
    set_clock_routing_rules -default_rule -min_routing_layer M3 -max_routing_layer M4
    if {$flow eq "fast"} {
        clock_opt -from build_clock -to route_clock
    } else {
        clock_opt
    }
}
save_block -as cts

# ------------------------------------------------------------------ route
# ROUTE_UNIDIR=1: see the routing guide at the floorplan; rpt/wrong_way.rpt
# checks that no M2-M4 wire runs the other way.
set ra {}
if {$route_max_iter > 0} { set ra [list -max_detail_route_iterations $route_max_iter] }
if {$flow eq "fast"} {
    set_app_options -name route.global.timing_driven -value false
    set_app_options -name route.track.timing_driven  -value false
    set_app_options -name route.detail.timing_driven -value false
    route_auto {*}$ra
} else {
    route_auto {*}$ra
    route_opt
}
save_block -as route

# ------------------------------------------------------------------ reports
# Wrong-way wire length on every layer M1-SIGNAL_TOP_LAYER (detail-route shapes):
# a shape counts when it runs across the preferred direction for more than
# the layer's wire width (the square stubs at pins and vias do not).
proc report_wrong_way {file} {
    global layer_dirs sig_top
    set fh [open $file w]
    puts $fh [format "%-6s %14s %14s %8s %8s" layer total_um wrong_way_um pct shapes]
    for {set i 1} {$i <= [string range $sig_top 1 end]} {incr i} {
        set l M$i
        set hz [expr {[dict get $layer_dirs $l] eq "horizontal"}]
        set lw [get_attribute [get_layers $l] min_width]
        set tot 0.0; set ww 0.0; set n 0
        foreach_in_collection s [get_shapes -quiet -filter "layer_name==$l && shape_use==detail_route"] {
            lassign [get_attribute $s bbox] p1 p2
            set w [expr {[lindex $p2 0] - [lindex $p1 0]}]
            set h [expr {[lindex $p2 1] - [lindex $p1 1]}]
            set tot [expr {$tot + max($w, $h)}]
            set across [expr {$hz ? $h : $w}]
            if {$across > $lw + 1e-4} { set ww [expr {$ww + $across}]; incr n }
        }
        puts $fh [format "%-6s %14.3f %14.3f %7.3f%% %8d" $l $tot $ww [expr {$tot > 0 ? 100 * $ww / $tot : 0}] $n]
    }
    close $fh
}
redirect -file $out/rpt/check_routes.rpt { check_routes }
redirect -file $out/rpt/check_lvs.rpt { check_lvs -max_errors 100000 }
# PG after routing: floating PDN pieces and std-cell/macro PG pins
# (check_pg_connectivity), PG DRC, vias missing where same-net PG shapes
# overlap (mostly the router's tie-off wires), and opens/shorts of VDD/VSS
# including the constant pins tied to them (check_lvs on the PG nets).
redirect -file $out/rpt/pg_final.rpt { check_pg_connectivity }
redirect -append -file $out/rpt/pg_final.rpt { check_pg_drc }
redirect -append -file $out/rpt/pg_final.rpt { check_pg_missing_vias }
redirect -file $out/rpt/check_lvs_pg.rpt { check_lvs -nets [get_nets {VDD VSS}] -max_errors 100000 }
redirect -file $out/rpt/check_legality_final.rpt { check_legality -verbose }
redirect -file $out/rpt/design.rpt { report_design -library -netlist -floorplan -routing }
redirect -file $out/rpt/utilization.rpt { report_utilization }
redirect -file $out/rpt/qor.rpt { report_qor -summary }
redirect -file $out/rpt/timing.rpt { report_timing -max_paths 10 }
if {$CLK_PORT ne ""} { redirect -file $out/rpt/clock.rpt { report_clock_qor } }
report_wrong_way $out/rpt/wrong_way.rpt
write_def $out/$DESIGN_TOP.def
write_verilog -exclude {pg_objects} $out/${DESIGN_TOP}.pnr.v
lappend run_params finished [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]
write_run_params
save_lib
exit
