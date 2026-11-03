# bp_be_top from OpenROAD-flow-scripts (BlackParrot back end; SRAMs fakeram45_512x64 x8, 64x15, 64x96 through ORFS' hard_mem wrappers).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    bp_be_top
set RTL_FILES     [list $ORFS_DESIGNS/src/bp_be_top/pickled.v $ORFS_DESIGNS/nangate45/bp_be_top/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set UTIL          0.6
set MACROS        {fakeram45_512x64 fakeram45_64x15 fakeram45_64x96}
