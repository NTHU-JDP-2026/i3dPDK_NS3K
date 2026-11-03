# bp_quad from OpenROAD-flow-scripts: bsg_chip, a quad-core BlackParrot with its on-chip network and IO links
# (sv2v-converted, the largest design here). SRAMs fakeram45_256x48, 32x32, 64x124, 512x64, 64x62, 128x116, partly
# through ORFS' nangate45 wrappers (macros.v). Macros: scripts/gen_macros.sh. ORFS clocks it with eight clock ports
# (core A/B/C, bsg_tag, the IO link clocks and tokens); here they are all one clock of CLK_PERIOD_NS.
set ORFS_DESIGNS  $::env(HOME)/OpenROAD-flow-scripts/flow/designs
set DESIGN_TOP    bsg_chip
set RTL_FILES     [list $ORFS_DESIGNS/src/bp_quad/bsg_chip_block.sv2v.v $ORFS_DESIGNS/nangate45/bp_quad/macros.v]
set CLK_PORT      {p_clk_A_i p_clk_B_i p_clk_C_i p_bsg_tag_clk_i p_ci_clk_i p_co_clk_i p_ci2_tkn_i p_co2_tkn_i}
set CLK_PERIOD_NS 1.0
set UTIL          0.5
set MACROS        {fakeram45_256x48 fakeram45_32x32 fakeram45_64x124 fakeram45_512x64 fakeram45_64x62 fakeram45_128x116}
# 220 macros: at the default MACRO_AREA_SLACK 1.25 the channels under MACRO_CHANNEL_UM between them, blocked,
# left 59% of the core for the standard cells (UTIL 0.8: placement density 126%, IMPSP-190).
set MACRO_AREA_SLACK 2.0
