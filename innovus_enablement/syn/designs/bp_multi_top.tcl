# bp_multi_top from OpenROAD-flow-scripts: BlackParrot core with its multicore (CCE) memory system. SRAMs through
# ORFS' nangate45 hard_mem wrappers (macros.v): fakeram45_512x64, 256x96, 32x64, 64x7, 64x15, 64x96.
# Macros: scripts/gen_macros.sh (gen_fakeram.py --name-prefix fakeram45_ --wmask).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    bp_multi_top
set RTL_FILES     [list $ORFS_DESIGNS/src/bp_multi_top/pickled.v $ORFS_DESIGNS/nangate45/bp_multi_top/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set UTIL          0.6
set MACROS        {fakeram45_512x64 fakeram45_256x96 fakeram45_32x64 fakeram45_64x7 fakeram45_64x15 fakeram45_64x96}
