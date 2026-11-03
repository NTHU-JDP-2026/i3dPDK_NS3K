# black_parrot from OpenROAD-flow-scripts: BlackParrot single-core RV64 (front end + back end + CCE / memory
# interface). 12 SRAMs through ORFS' nangate45 hard_mem wrappers (macros.v): fakeram45_512x64 x4, 256x95 x2,
# 64x7 x2, 64x15 x2, 64x96 x2. Macros: scripts/gen_macros.sh (gen_fakeram.py --name-prefix fakeram45_ --wmask).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    black_parrot
set RTL_FILES     [list $ORFS_DESIGNS/src/black_parrot/pickled.v $ORFS_DESIGNS/nangate45/black_parrot/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set UTIL          0.6
set MACROS        {fakeram45_512x64 fakeram45_256x95 fakeram45_64x7 fakeram45_64x15 fakeram45_64x96}
