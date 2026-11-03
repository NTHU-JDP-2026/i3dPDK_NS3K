# dynamic_node from OpenROAD-flow-scripts (OpenPiton dynamic network router, no macros).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    dynamic_node_top_wrap
set RTL_FILES     [list $ORFS_DESIGNS/src/dynamic_node/dynamic_node.pickle.v]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
set UTIL          0.6

