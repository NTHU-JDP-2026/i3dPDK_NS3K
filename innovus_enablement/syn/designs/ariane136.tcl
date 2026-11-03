# ariane136 from OpenROAD-flow-scripts: CVA6 (Ariane) RV64 core, sv2v-converted, as ariane133 with 136 SRAMs
# fakeram45_256x16 through ORFS' SyncSpRamBeNx64 wrappers (macros.v).
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    ariane
set RTL_FILES     [list $ORFS_DESIGNS/src/ariane136/ariane.sv2v.v $ORFS_DESIGNS/nangate45/ariane136/macros.v]
set CLK_PORT      clk_i
set CLK_PERIOD_NS 1.0
set MACROS        {fakeram45_256x16}
set UTIL          0.5
# 136 macros placed by place_design -concurrent_macros: at the default MACRO_AREA_SLACK 1.25 the macro
# channels and halo stripes left the standard cells 0.91 of the rows (UTIL 0.8; Xplace GP then had no
# whitespace); the density is not monotonic in the core size (UTIL 0.75: 1.02, slack 1.5: 0.98,
# 1.75: 0.73), 2.0 gives 0.80 (PG-clean PDN), as for bp_quad.
set MACRO_AREA_SLACK 2.0
