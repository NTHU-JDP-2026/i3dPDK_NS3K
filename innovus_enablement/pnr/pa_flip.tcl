# Pin-access flips before routing (PA_FLIP=1; sourced by flow_fast.tcl after CTS, or with
# PA_FLIP_STAGE=prects on the legal placement before CTS; the file names keep "preroute"):
#   1. write $out/xplace/<top>.preroute.def (the placement) and touch <top>.preroute.ready;
#   2. wait for xplace/run_xplace_flow.sh on the GPU host to score every cell
#      near the PDN with the pin-access model (~/Xplace/pinaccess/flip.py) and
#      upload <top>.flip ("instance orientation" per line: the x-mirror of the
#      row's orientation with the lower predicted signal-PG risk, only where it
#      changes), then touch <top>.flip.ready (<top>.flip.failed on error);
#   3. set those orientations (same site, same row: an x-mirror stays legal)
#      and check the placement.
# Cells are flipped only in x: the row orientation (N/FS) stays. Innovus flips
# many cells itself between refinePlace and routing (wirelength); this runs
# after that, so it decides last (with PA_FLIP_STAGE=prects, CTS and the post-CTS
# legalization run after it and may move or flip cells again).
#
# PA_SHIFT=1: also move, on their row, the cells a flip cannot fix:
#   - every cell of a type in PA_SHIFT_CELLS within PA_SHIFT_SITES sites of a strap
#     centreline on PA_SHIFT_LAYER, to the nearest x clear of it (types failing next to a
#     strap whatever their orientation: signal-only violations, which the model does not
#     predict, e.g. OAI221 / AOI221 / OAI22 / AOI22 under an M3 stripe). Done BEFORE the
#     placement goes to flip.py, so the flips are chosen for the final positions (chosen
#     before, the neighbours refinePlace pushed around lost theirs: jpeg signal-PG 56 -> 189);
#   - the cells flip.py shifts (both mirrors at risk; PA_FLIP_ARGS --shift_thr ...):
#     "instance SHIFT dx orientation" lines, by dx sites, after the flips; then the listed
#     types once more.
# The moved cells are placed FIXED (clear of each other and of fixed cells such as the
# clock buffers) while refinePlace legalizes the others around them, then released.
set xp_dir $out/xplace
file mkdir $xp_dir
foreach f [glob -nocomplain $xp_dir/$DESIGN_TOP.flip* $xp_dir/$DESIGN_TOP.preroute.*] { file delete $f }

set pa_shift [design_param PA_SHIFT 0]
lappend run_params pa_shift $pa_shift
if {$pa_shift} {
    set shift_cells [lsearch -all -inline -not -exact [split [design_param PA_SHIFT_CELLS ""] " ,"] ""]
    # PA_SHIFT_CELLS=auto: the pin-access critical types of the library, the types whose track-aware
    # pin scarcity (Xplace tool/pin_scarcity_track.py, from the cell LEF alone) has z >= PA_SCARCITY_Z
    # (default 1.0, mean + 1 std); the report is PA_SCARCITY_REPORT
    if {$shift_cells eq "auto"} {
        set rep [design_param PA_SCARCITY_REPORT $lefdir/NS3K_5T_cells.pin_scarcity.txt]
        set zmin [design_param PA_SCARCITY_Z 1.0]
        set shift_cells {}
        set fh [open $rep]
        while {[gets $fh line] >= 0} {
            if {[regexp {^\s*\d+\s+(\S+)\s+score=\S+\s+z=(\S+)} $line - c z] && $z >= $zmin} { lappend shift_cells $c }
        }
        close $fh
        puts "pa_shift: [llength $shift_cells] critical types (pin scarcity z >= $zmin, $rep): [join $shift_cells ,]"
        lappend run_params pa_scarcity_z $zmin
    }
    set shift_layer [design_param PA_SHIFT_LAYER M3]
    set shift_sites [design_param PA_SHIFT_SITES 3]
    set shift_passes [design_param PA_SHIFT_PASSES 2]
    lappend run_params pa_shift_cells [join $shift_cells ,] pa_shift_layer $shift_layer pa_shift_sites $shift_sites
    set site_w [dbGet [dbGet -p head.sites.name $site_name].size_x]
    lassign [lindex [dbGet top.fPlan.coreBox] 0] cx1 cy1 cx2 cy2
    # strap centrelines: tall wires of the layer inside the core
    set straps {}
    foreach w [dbQuery -area [lindex [dbGet top.fPlan.box] 0] -objType sWire] {
        if {[dbGet $w.layer.name] ne $shift_layer} continue
        lassign [lindex [dbGet $w.box] 0] w1 w2 w3 w4
        if {$w4 - $w2 < 50 || $w1 < $cx1 || $w3 > $cx2} continue
        lappend straps [expr {($w1 + $w3) / 2.0}]
    }
    set straps [lsort -real -unique $straps]
    set band [expr {$shift_sites * $site_w}]
    set shift_stats [dict create list_moves 0 model_moves 0 disp 0.0]

    proc pa_band_hit {x1 x2} {
        upvar #0 straps straps band band
        foreach c $straps { if {$x2 > $c - $band + 1e-4 && $x1 < $c + $band - 1e-4} { return $c } }
        return ""
    }
    # the listed cells in a band, each with the nearest x clear of it on the site grid
    proc pa_list_moves {} {
        upvar #0 shift_cells shift_cells band band site_w site_w cx1 cx1
        set todo {}
        foreach ct $shift_cells {
            foreach inst [dbGet -e -p2 top.insts.cell.name $ct] {
                set x1 [dbGet $inst.box_llx]; set x2 [dbGet $inst.box_urx]
                set c [pa_band_hit $x1 $x2]
                if {$c eq ""} continue
                set w [expr {$x2 - $x1}]
                set xl [expr {$cx1 + floor(($c - $band - $w - $cx1) / $site_w + 1e-6) * $site_w}]
                set xr [expr {$cx1 + ceil(($c + $band - $cx1) / $site_w - 1e-6) * $site_w}]
                lappend todo [list $inst [expr {abs($xl - $x1) <= abs($xr - $x1) ? $xl : $xr}] [dbGet $inst.orient]]
            }
        }
        return $todo
    }
    # does [x, x+w] x [y, y+h] overlap an instance other than inst that refinePlace will not
    # move: fixed / cover / softFixed, or a clock tree cell (CCOpt's CTS_*: status placed, but
    # refinePlace treats them as preplaced; a moved cell placed on one stayed overlapping)
    proc pa_fixed_clash {inst x y w h} {
        foreach o [dbQuery -area [list [expr {$x + 1e-3}] [expr {$y + 1e-3}] [expr {$x + $w - 1e-3}] [expr {$y + $h - 1e-3}]] -objType inst] {
            if {$o eq $inst} continue
            if {[dbGet $o.pStatus] ni {placed unplaced} || [string match CTS_* [dbGet $o.name]]} { return 1 }
        }
        return 0
    }
    # place the moves fixed (clear of each other, of fixed cells and, for listed types, of
    # the bands), legalize the rest with refinePlace, release them; returns the cells moved
    proc pa_apply_moves {todo kind} {
        upvar #0 shift_cells shift_cells site_w site_w cx1 cx1 cx2 cx2 shift_stats shift_stats
        set taken [dict create]
        set fixed {}
        foreach t $todo {
            lassign $t inst x o
            set y [dbGet $inst.box_lly]; set h [expr {[dbGet $inst.box_ury] - $y}]
            set x0 [dbGet $inst.box_llx]; set w [expr {[dbGet $inst.box_urx] - $x0}]
            set listed [expr {[lsearch -exact $shift_cells [dbGet $inst.cell.name]] >= 0}]
            set dir [expr {$x < $x0 ? -1 : 1}]
            set ivs [expr {[dict exists $taken $y] ? [dict get $taken $y] : {}}]
            set ok 0
            for {set k 0} {$k < 20} {incr k} {
                set clash 0
                foreach iv $ivs { if {$x < [lindex $iv 1] - 1e-4 && $x + $w > [lindex $iv 0] + 1e-4} { set clash 1; break } }
                if {!$clash && $listed && [pa_band_hit $x [expr {$x + $w}]] ne ""} { set clash 1 }
                if {!$clash && [pa_fixed_clash $inst $x $y $w $h]} { set clash 1 }
                if {!$clash} { set ok 1; break }
                set x [expr {$x + $dir * $site_w}]
            }
            if {!$ok || $x < $cx1 || $x + $w > $cx2} continue
            dict lappend taken $y [list $x [expr {$x + $w}]]
            dict set shift_stats disp [expr {[dict get $shift_stats disp] + abs($x - $x0)}]
            placeInstance [dbGet $inst.name] $x $y $o -fixed
            lappend fixed $inst
        }
        if {[llength $fixed]} {
            refinePlace
            foreach inst $fixed { dbSet $inst.pStatus placed }
        }
        dict incr shift_stats ${kind}_moves [llength $fixed]
        return [llength $fixed]
    }
    for {set pass 1} {$pass <= $shift_passes} {incr pass} {
        set todo [pa_list_moves]
        if {![llength $todo]} break
        puts "pa_shift list pass $pass: [pa_apply_moves $todo list] of [llength $todo] listed cells in a band moved"
    }
}

# with Innovus as the placer (no xplace_place.tcl): the PDN DEF and the LEF
# list flip.py reads, as xplace_place.tcl writes them
if {![file exists $xp_dir/$DESIGN_TOP.in.def]} {
    defOut -floorplan $xp_dir/$DESIGN_TOP.in.def
    set fh [open $xp_dir/$DESIGN_TOP.in.lefs w]
    foreach f $init_lef_file {
        puts $fh [string map [list $enab/ $pdk_name/innovus_enablement/] $f]
    }
    close $fh
}
# with the nets, for the HPWL term of pinaccess/dp_refine.py
defOut -netlist $xp_dir/$DESIGN_TOP.preroute.def
close [open $xp_dir/$DESIGN_TOP.preroute.ready w]
set wait_min [design_param PA_FLIP_WAIT_MIN 60]
set t0 [clock seconds]
while {1} {
    if {[file exists $xp_dir/$DESIGN_TOP.flip.ready]} break
    if {[file exists $xp_dir/$DESIGN_TOP.flip.failed]} {
        error "pa_flip: the GPU host reported a failure ([string trim [read [open $xp_dir/$DESIGN_TOP.flip.failed]]])"
    }
    if {[clock seconds] - $t0 > $wait_min * 60} {
        error "pa_flip: no $DESIGN_TOP.flip.ready after $wait_min min"
    }
    after 10000
}
# names as Innovus stores them, matched without the DEF escapes
set ptr [dict create]
foreach i [dbGet top.insts] { dict set ptr [string map {\\ ""} [dbGet $i.name]] $i }
set fh [open $xp_dir/$DESIGN_TOP.flip]
set n 0; set miss 0
set model_shift {}
while {[gets $fh line] >= 0} {
    if {[llength $line] == 4 && [lindex $line 1] eq "SHIFT"} {
        lassign $line name - dx o
        set key [string map {\\ ""} $name]
        if {[dict exists $ptr $key]} { lappend model_shift [list [dict get $ptr $key] $dx $o] } else { incr miss }
        continue
    }
    if {[llength $line] != 2} continue
    lassign $line name o
    set key [string map {\\ ""} $name]
    if {![dict exists $ptr $key]} { incr miss; continue }
    # DEF orientation -> Innovus dbSet name
    dbSet [dict get $ptr $key].orient [dict get {N R0 S R180 FN MY FS MX} $o]
    incr n
}
close $fh
puts "pa_flip: $n cells flipped in x ($miss not found)"
lappend run_params pa_flip_cells $n

if {$pa_shift} {
    if {[llength $model_shift]} {
        set todo [lmap m $model_shift {
            lassign $m inst dx o
            list $inst [expr {[dbGet $inst.box_llx] + $dx * $site_w}] [dict get {N R0 S R180 FN MY FS MX} $o]
        }]
        puts "pa_shift model: [pa_apply_moves $todo model] of [llength $todo] cells moved"
        set todo [pa_list_moves]
        if {[llength $todo]} { puts "pa_shift list cleanup: [pa_apply_moves $todo list] of [llength $todo] moved" }
    }
    set left [llength [pa_list_moves]]
    set nm [expr {[dict get $shift_stats list_moves] + [dict get $shift_stats model_moves]}]
    set disp [expr {$nm ? [dict get $shift_stats disp] / $nm : 0}]
    puts "pa_shift: [llength $straps] straps on $shift_layer, [dict get $shift_stats list_moves] list + [dict get $shift_stats model_moves] model moves, mean [format %.3f $disp] um, $left listed cells left in a band"
    lappend run_params pa_shift_list_moves [dict get $shift_stats list_moves] pa_shift_model_moves [dict get $shift_stats model_moves] \
        pa_shift_mean_um [format %.4f $disp] pa_shift_left $left
}
checkPlace $out/rpt/checkPlace_paflip.rpt
# run_params.json was written before this file was sourced: again, with the flip / shift counts
set fh [open $out/run_params.json w]
puts $fh "\{\n[join [lmap {k v} $run_params {string cat "  " [json_str $k] ": " [json_str $v]}] ",\n"]\n\}"
close $fh
