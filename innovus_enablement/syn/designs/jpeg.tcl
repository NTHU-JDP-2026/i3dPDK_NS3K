# jpeg from OpenROAD-flow-scripts (JPEG encoder, no macros).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    jpeg_encoder
set RTL_FILES     [lsort [glob -nocomplain $ORFS_DESIGNS/src/jpeg/*.v]]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
set UTIL          0.6
set INCLUDE_DIRS  [list $ORFS_DESIGNS/src/jpeg/include]
