# SERV (bit-serial RV32I), top = serv_synth_wrapper (RF RAM is external ports)
set DESIGN_TOP    serv_synth_wrapper
set RTL_DIR       $::env(HOME)/RTL/serv/rtl
set RTL_FILES     [glob -nocomplain $RTL_DIR/*.v]
set CLK_PORT      clk
set CLK_PERIOD_NS 0.25
set MACROS        {}
# PnR
set UTIL          0.6
