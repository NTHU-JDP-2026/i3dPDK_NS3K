# ariane133 from OpenROAD-flow-scripts: CVA6 (Ariane) RV64 core, sv2v-converted.
# 133 SRAMs fakeram45_256x16 (caches) through ORFS' SyncSpRamBeNx64 wrappers
# (macros.v). Macro: gen_fakeram.py 256x16 --name-prefix fakeram45_ --wmask.
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    ariane
set RTL_FILES     [list \
    $ORFS_DESIGNS/src/ariane133/ariane.sv2v.v \
    $ORFS_DESIGNS/nangate45/ariane133/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set MACROS        {fakeram45_256x16}
# util 0.5 to start (ORFS uses 50%); a large CPU like swerv, which needed 0.4.
set UTIL          0.5
