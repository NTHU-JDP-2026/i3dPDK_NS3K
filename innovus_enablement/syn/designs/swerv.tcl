# swerv from OpenROAD-flow-scripts (SweRV EH1 core without its memories (top swerv), no macros).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    swerv
set RTL_FILES     [list [file join [file dirname [info script]] .. cells_clkgate.v] $ORFS_DESIGNS/src/swerv/swerv_wrapper.sv2v.v]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
# util 0.4 (default 0.6): the SweRV logic needs the most routing of all the
# designs. At 0.6 routing gave up (>100k DRCs); at 0.5 swerv still had 23%
# vertical global-route overflow, 1212 DRCs and a 2 h route, and
# swerv_wrapper (plus 28 macros' pins) gave up again.
set UTIL          0.4

