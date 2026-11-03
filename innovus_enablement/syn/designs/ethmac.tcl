# ethmac from OpenROAD-flow-scripts (OpenCores Ethernet MAC, no macros; only the Wishbone clock wb_clk_i is constrained (the MII tx/rx clocks are left unconstrained)).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    ethmac
set RTL_FILES     [lsort [glob -nocomplain $ORFS_DESIGNS/src/ethmac/*.v]]
set CLK_PORT      wb_clk_i
set CLK_PERIOD_NS 1.0
set UTIL          0.6

