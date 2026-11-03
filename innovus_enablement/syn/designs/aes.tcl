# aes from OpenROAD-flow-scripts (AES-128 cipher, no macros).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    aes_cipher_top
set RTL_FILES     [lsort [glob -nocomplain $ORFS_DESIGNS/src/aes/*.v]]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
# util 0.5 (default 0.6): at 0.6 the S-box logic needs more routing than
# CFET 3T has (17%/15% global-route overflow, routing gave up with 15k DRCs).
set UTIL          0.5

