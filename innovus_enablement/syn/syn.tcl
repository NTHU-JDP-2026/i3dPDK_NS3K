# Yosys synthesis to i3dPDK_NS3K (copy of i3dPDK_A16K's syn.tcl). Env: LIB_FILE DESIGN_CFG OUT_DIR MACRO_DIR [CLK_PERIOD_NS]
# Macros listed in the design config ($MACROS) are read as black boxes from
# $MACRO_DIR/<name>.lib (see scripts/gen_fakeram.py).
yosys -import
set lib $::env(LIB_FILE)
source $::env(DESIGN_CFG)
if {[info exists ::env(CLK_PERIOD_NS)]} { set CLK_PERIOD_NS $::env(CLK_PERIOD_NS) }
set out $::env(OUT_DIR)
# No scan flow (SDFF has no test_cell); X32 drivers are left to Innovus sizing.
set dont_use {SDFF_X1 SDFF_X2}
if {![info exists MACROS]} { set MACROS {} }
set macro_libs [lmap m $MACROS {file join $::env(MACRO_DIR) $m.lib}]

read_liberty -lib $lib
foreach ml $macro_libs { read_liberty -lib $ml }
# Optional INCLUDE_DIRS in the design config (`include search path).
if {![info exists INCLUDE_DIRS]} { set INCLUDE_DIRS {} }
set incs [lmap d $INCLUDE_DIRS {string cat -I $d}]
foreach f $RTL_FILES { read_verilog -defer {*}$incs $f }
hierarchy -check -top $DESIGN_TOP
# Keep every macro instance: with the design flattened, a macro whose read
# data is unused would be removed with the logic around it (ariane133: ORFS'
# "limping" SRAM wrappers tie most read data to 0, and 89 of the SRAMs plus
# most of the D$ disappeared).
foreach m $MACROS { setattr -set keep 1 t:$m }
synth -top $DESIGN_TOP -flatten
opt -purge
# The PDK has no set/reset flops (DFF_X1/X2 only): async set/reset becomes
# synchronous (reset now acts at the next clock edge). No-op for sync designs.
async2sync

dfflibmap -liberty $lib {*}[concat {*}[lmap c $dont_use {list -dont_use $c}]]
opt
abc -liberty $lib -D [expr {int($CLK_PERIOD_NS * 1000)}] {*}[concat {*}[lmap c $dont_use {list -dont_use $c}]]
opt_clean -purge

# No TIE cells: constants stay as 1'b0/1'b1 (tie to VSS/VDD in Innovus).
setundef -zero
# Innovus-friendly netlist: buffer port-to-port feedthroughs instead of assigns.
insbuf -buf BUF_X1 A Z
opt_clean -purge
check -assert

tee -o $out/stat.rpt stat -liberty $lib {*}[concat {*}[lmap ml $macro_libs {list -liberty $ml}]]
write_verilog -noattr -noexpr -nohex -nodec $out/${DESIGN_TOP}.v
