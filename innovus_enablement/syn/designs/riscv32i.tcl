# riscv32i from OpenROAD-flow-scripts (single-cycle RV32I), top = riscv_top.
# Data memory is 4x fakeram7_256x32; the macro here is our own abstract model
# (scripts/gen_fakeram.py 256x32), not ORFS' asap7 one.
set DESIGN_TOP    riscv_top
set RTL_DIR       $::env(HOME)/OpenROAD-flow-scripts/flow/designs/src/riscv32i
set RTL_FILES     [lsort [glob -nocomplain $RTL_DIR/*.v]]
set CLK_PORT      clk
set CLK_PERIOD_NS 1.0
set MACROS        {fakeram7_256x32}
# PnR
set UTIL          0.6
set MIN_CHANNEL_UM 10.0
