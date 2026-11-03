# bp_fe_top from OpenROAD-flow-scripts: BlackParrot front end (fetch, I$, BTB,
# I-TLB). 11 SRAMs through ORFS' nangate45 hard_mem_* wrappers (macros.v):
# fakeram45_512x64 x9, fakeram45_64x7, fakeram45_64x96. The macros are our own
# abstract models: gen_fakeram.py 512x64 64x7 64x96 --name-prefix fakeram45_ --wmask.
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    bp_fe_top
set RTL_FILES     [list \
    $ORFS_DESIGNS/src/bp_fe_top/pickled.v \
    $ORFS_DESIGNS/nangate45/bp_fe_top/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set MACROS        {fakeram45_512x64 fakeram45_64x7 fakeram45_64x96}
# util 0.5 (the other designs use 0.6): 11 macros leave narrow logic channels.
set UTIL          0.5
