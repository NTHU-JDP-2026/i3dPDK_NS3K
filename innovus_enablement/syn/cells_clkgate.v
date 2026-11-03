// OPENROAD_CLKGATE for i3dPDK_A16K: the PDK has no integrated clock-gating
// (or latch) cell, so the gate is a plain wire, as in ORFS' own fallback
// (platforms/*/cells_clkgate.v without OPENROAD_CLKGATE defined). Gated
// clocks become free-running; the netlist is still fine for layout studies.
module OPENROAD_CLKGATE (CK, E, GCK);
  input CK;
  input E;
  output GCK;
  assign GCK = CK;
endmodule
