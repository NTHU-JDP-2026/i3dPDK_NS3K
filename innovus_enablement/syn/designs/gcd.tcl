# gcd from OpenROAD-flow-scripts (GCD unit, no macros).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    gcd
set RTL_FILES     [list $ORFS_DESIGNS/src/gcd/gcd.v]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
set UTIL          0.6

