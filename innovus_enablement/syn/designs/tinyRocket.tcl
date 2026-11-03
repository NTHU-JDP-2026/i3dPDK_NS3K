# tinyRocket from OpenROAD-flow-scripts: Rocket RV64 tile (TinyConfig), top = RocketTile.
# SRAMs: the I$ and D$ data arrays, fakeram45_64x32 x2, instantiated through the
# *_ext wrappers of ORFS' nangate45 TinyConfig.v (mem_ext/fakeram45_1024x32 sits
# outside RocketTile, in the test harness). The macro is our own abstract model:
# gen_fakeram.py 64x32 --name-prefix fakeram45_ --wmask.
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    RocketTile
set RTL_FILES     [list \
    $ORFS_DESIGNS/src/tinyRocket/AsyncResetReg.v \
    $ORFS_DESIGNS/src/tinyRocket/ClockDivider2.v \
    $ORFS_DESIGNS/src/tinyRocket/ClockDivider3.v \
    $ORFS_DESIGNS/src/tinyRocket/plusarg_reader.v \
    $ORFS_DESIGNS/src/tinyRocket/freechips.rocketchip.system.TinyConfig.v \
    $ORFS_DESIGNS/nangate45/tinyRocket/freechips.rocketchip.system.TinyConfig.v]
set CLK_PORT      clock
set CLK_PERIOD_NS 1.0
set MACROS        {fakeram45_64x32}
# PnR: util 0.6 with the default 0.048um M3 PG stripes. For reference, at
# util 0.6 on CFET_3T: no stripes 20 DRC, 0.024um 71, 0.096um 96,
# 0.192um 51692 (0.192um: util 0.5 -> 2793, util 0.4 -> 2).
set UTIL          0.6
