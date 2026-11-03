# i3dPDK_NS3K: Synopsys IC Compiler II enablement

PnR flow for i3dPDK_NS3K in IC Compiler II (V-2023.12 on the nthucad hosts),
at the PDK's **native geometry**. The Innovus flow (`../innovus_enablement/`)
scales every LEF by 4x because Innovus 21 asks for an invs_3nm licence at 1x;
ICC2 has no such check, so nothing here is scaled and no R/C is compensated.

Netlists and per-design settings are shared with the Innovus flow
(`../innovus_enablement/syn/out/` and `syn/designs/`); synthesize there first.

| File | Purpose |
|---|---|
| `pdk_config.tcl` | Read by `pnr/flow.tcl`: tf, NDMs, TLU+, site, rails on M0, layer directions, `ROUTE_UNIDIR` default 1 |
| `scripts/fix_tf.py` | `tech/i3dPDK_NS3K_5T.tf`: the PDK tf with its vias on the 1 nm grid (below) |
| `scripts/fix_cell_lef.py` | Cell LEF for the NDM: drops OBS inside a cell's own PG pin (NAND2_X1) |
| `ndm/build_ndm.sh`, `build_ndm.tcl` | Build `ndm/out/NS3K_5T.ndm` (cells) and `ndm/out/fakeram*.ndm` (macros, `.lib` compiled by lc_shell) |
| `pnr/run_pnr.sh`, `flow.tcl` | ICC2 flow (on an ICC2 host) -> `pnr/out/<design>/NS3K_5T/<tag>/` |
| `pnr/run_batch.sh` | Several designs in parallel, detached |
| `pnr/summarize.sh` | One line per run: status, route DRC, wirelength, LVS shorts/opens, PG, wrong-way shapes, minutes |
| `sync_to_server.sh` | Pushes what the flow reads to the server and stamps `.flow_version` |

Generated and committed: `tech/`. Built on the server, not committed:
`ndm/out/`, `pnr/out/`.

## Use

```bash
./sync_to_server.sh                               # -> nthucad:i3dPDK_NS3K/
# on an ICC2 host (ic21/ic51/ic53), in ~/i3dPDK_NS3K/icc2_enablement:
ndm/build_ndm.sh                                  # once, and after any tf/LEF/lib change
cd pnr
env OUT_TAG=icc2_fast ./run_pnr.sh <design> NS3K_5T
env THREADS=6 ./run_batch.sh icc2_fast NS3K_5T gcd aes tinyRocket ...
./summarize.sh icc2_fast
```

The login shell on the hosts is tcsh; the scripts are bash (`bash -s` over
ssh avoids the quoting). `FLOW=fast` (default) is place_opt, CTS (build +
route clock), route_auto, no post-CTS/post-route optimization, like
`innovus_enablement/pnr/flow_fast.tcl`; `FLOW=full` adds clock_opt's final
optimization and route_opt. The parameters of `innovus_enablement/pnr/flow.tcl`
that make sense here keep their names (`UTIL`, `CLK_PERIOD_NS`,
`IO_PIN_TRACKS`, `IO_PIN_LAYERS`, `PG_M3_*`, `SIGNAL_TOP_LAYER`,
`ROUTE_UNIDIR`, `ROUTE_GUIDE_LAYERS`, `PLACE_OPT`, `ROUTE_MAX_ITER`, `MACRO_*`, `MIN_CHANNEL_UM`,
`PG_CHECK_ABORT`, `STOP_AFTER=floorplan|place`); each run records them in
`run_params.json`.

Outputs per run: `<top>.floorplan.def` (rows, tracks, pins, PDN), `<top>.def`
and `<top>.pnr.v` (routed), `<top>.nlib` (blocks `floorplan`, `place`, `cts`,
`route`), `rpt/` (`check_routes.rpt`, `check_lvs.rpt`, `pg_floorplan.rpt`,
`pg_final.rpt` and `check_lvs_pg.rpt` (PG after routing, the `PG` column of
`summarize.sh`), `wrong_way.rpt`, timing/QoR/utilization).

## Physical set-up (as the Innovus flow, at 1x)

- Core on the track grid: x on the site grid (0.044), y on the M2/M4 grid
  (0.024). Tracks start at the die origin, offset 0 on M2-M4 (each row holds
  M2 tracks 1-4, as the pin-access model assumes) and pitch/2 elsewhere.
- IO pins on M4/M6/M8/M10 (left/right) and M5/M7/M9/M11 (top/bottom), one per
  `IO_PIN_TRACKS` tracks; the clock port on M4 (the clock is routed on M3-M4).
- PDN: M0 rails, M8/M9 core ring with M0->M9 stacks outside the core, M3
  VDD/VSS stripe pairs every 2 um (each pair centred on a site, ends on a rail
  of its own net). Macro designs: macros placed by `create_placement
  -floorplan` (R0/MX/MY/R180, halo as a hard keepout, kept inside the core),
  snapped to the site / M4 pin grid; no rows under a macro, no cells in its halo or in pockets
  (their rows stay, blocked for cells) narrower than `MACRO_CHANNEL_UM`; VDD/VSS M9 stripe pairs in the halos
  (stacks down to the rails, the ring at both ends); each macro's M5 straps
  tied by M6 straps centred on rails of their own net, run out to the nearest
  M9 of that net. The run stops if VDD/VSS have floating pieces.
- `ROUTE_UNIDIR=1`: every routing layer (M2 up to `SIGNAL_TOP_LAYER`) in its
  preferred direction only, as a hard rule: a preferred-direction-only routing
  guide (`create_routing_guide -preferred_direction_only`) over the die, set at
  the floorplan so global routing during placement, CTS and route_auto all see
  it (`ROUTE_GUIDE_LAYERS` overrides its layers). M2-M4 wires and VIA2-VIA4 are
  also on track and only preferred-direction tracks exist. VIA1 is not forced
  on the grid: OR3_X1's A1/A2 pins sit 2 nm off it, and an on-grid VIA1 there
  took an M1 patch wider than tall, i.e. a non-preferred M1 route. ICC2's
  `check_routes` reports a non-preferred-direction route on any layer as a
  DRC, and `rpt/wrong_way.rpt` counts such shapes on M1 to the top layer (the
  `wrong-way` column of `summarize.sh`). The Innovus flow restricts only
  M2-M4 (its unidir LEF); NanoRoute routes M5 and up in both directions.

## Notes on the PDK data

- **Via definitions off the 1 nm grid.** VIA78/VIA89 have 0.031 cuts and
  VIA1112/via1213 0.053, so their pads have odd widths and, centred on a
  track, edges on half nm: dynamic_node had 103 "Off minimum grid" on M7. Some
  cuts also disagree with their cut layer (VIA78 0.031 vs VIA7 0.030, VIA1112
  0.053 vs VIA11 0.054). `fix_tf.py` sets every cut to its cut layer's width
  rounded up to an even nm and raises enclosures so pads reach the metal's
  minWidth (14 changes, listed when it runs). At 4x the Innovus flow never sees
  this.
- **NAND2_X1** repeats its VDD rail in its M0 OBS; the PDK's own NDM
  (`BE/*.ndm`) carries it, and check_lvs reports an M0 short with the
  followpin and both neighbours at every instance. The flow therefore builds
  its own cell NDM from the cell LEF without that OBS (`fix_cell_lef.py`) and
  `FE/*.db`. `INV_X16_2`, `INV_X32_2`, `INV_X32_3` (no timing) are left out.
- tf M11 pitch 0.11 < width + spacing 0.112: tracks use 0.112.
- OR3_X1's A1 and A2 M1 pins are centred 2 nm off the M1/M3 track grid (all
  other 183 signal M1 rects are on it); the flow leaves VIA1 off the grid
  rather than move the pins (the LEF would then disagree with the GDS).
- The tf has no preferred directions: even layers horizontal, odd vertical.
- The liberty has no `pg_pin`s: lm_shell takes VDD/VSS from the LEF and fixes
  their direction (the NDM-032 "Error"s in `ndm/work/*/lm.log` are expected).
- TLU+ extraction (no nxtgrd): ICC2 warns that its TLU+ extractor is obsolete
  below 7 nm; timing is indicative only.

## Runs (2026-10-08, `icc2_fast`, ic53, 6 threads)

`check_routes` DRC, routed WL (um), wall-clock minutes, next to Innovus
`ns3k_uni3_fast` (`verify_drc`, WL in 1x um). Not like for like: different
checkers, ICC2 checks the tf rules at 1x, Innovus its 4x LEF. ICC2 routes
every layer unidirectionally (wrong-way 0 on M1-M11 on every run), Innovus
M2-M4 only. UTIL is the target of the core sizing (standard cells only); "util
after place" is report_utilization's cell area / row area. bp_fe_top and
bp_be_top come out low because their core side is set by the IO pin count
(about 2500 and 3000 pins), as in the Innovus flow (same die sizes).

| design | UTIL | util after place | ICC2 DRC | ICC2 WL | min | Innovus DRC | Innovus WL | min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gcd | 0.6 | 0.57 | 0 | 368 | 0 | 11 | 362 | 0 |
| serv | 0.6 | 0.60 | 0 | 1635 | 0 | 21 | 1591 | 1 |
| aes | 0.5 | 0.51 | 0 | 25691 | 1 | 324 | 26378 | 4 |
| riscv32i | 0.6 | 0.59 | 0 | 21891 | 2 | 161 | 20158 | 7 |
| dynamic_node | 0.6 | 0.59 | 0 | 32709 | 2 | 134 | 32326 | 4 |
| tinyRocket | 0.6 | 0.61 | 0 | 59014 | 4 | 504 | 62314 | 15 |
| bp_fe_top | 0.5 | 0.36 | 0 | 170188 | 7 | 592 | 174479 | 24 |
| ethmac | 0.6 | 0.60 | 0 | 87769 | 7 | 973 | 88766 | 17 |
| bp_be_top | 0.6 | 0.35 | 0 | 275777 | 10 | 1001 | 295646 | 37 |
| jpeg | 0.6 | 0.59 | 0 | 81212 | 7 | 1194 | 84980 | 17 |
| swerv | 0.4 | 0.41 | 0 | 341454 | 18 | 2309 | 401752 | 44 |
| swerv_wrapper | 0.4 | 0.40 | 0 | 452580 | 22 | 2015 | 494744 | 50 |
| ariane133 | 0.5 | 0.51 | 0 | 537146 | 47 | 4139 | 565012 | 203 |

check_lvs (signal and VDD/VSS nets, incl. the constant pins tied to the
rails: 2243 on ariane133, 1064 on bp_fe_top) and check_pg_connectivity: no
shorts, opens or floating PG anywhere, and no DRC.
check_pg_missing_vias still reports overlaps without a via, nearly all
between the router's tie-off wires.

ICC2 vs Innovus: both checkers find the same M2/M3 spacing/short violations
on the same layout (Innovus layouts brought to 1x and checked by
check_routes: aes 128/196, tinyRocket 227/277, jpeg 958/236 signal-PG /
signal-signal, as verify_drc), and ICC2 routes Innovus' own placement, PDN
and clock tree (signal routes removed) to 0 DRC (tinyRocket, jpeg). The gap
in the table comes from NanoRoute. The checkers do differ elsewhere: ICC2
flags a non-preferred-direction route on any layer (Innovus allows M5 and
up both ways), and the Innovus unidir LEF adds M3 RECTONLY /
RIGHTWAYONGRIDONLY, which flag 305 single M3 shapes (166 on PG stripes)
on the ICC2 layouts.

Fixed on the way to this table (swerv_wrapper had 28 M4 shorts between macro
pin nets and VDD/VSS): halo M9 stripes drop no rail stacks within 2 sites of
any macro edge (a moved pair, or a stripe crossing another macro's halo, had
its M1-M4 pads 0.02-0.03 um from the macro pins); row pieces and rail
pieces shorter than 1 um (e.g. in a 0.22 um gap between two macros) are
removed, so no rail stub needs such a stack. The last M1 patches (jpeg,
swerv, tinyRocket: OR3_X1 pins off the grid) went with VIA1's on-grid rule.

## Not ported (yet)

Xplace global placement (`PLACER=xplace`) and the pre-route pin-access flip
(`PA_FLIP=1`) of the Innovus flow; `MACRO_PLACE=columns`; `PG_STYLE=pillar`.
