# i3dPDK_NS3K: Cadence Innovus enablement

Settings, generators, generated collateral and the synthesis / PnR flow for
running i3dPDK_NS3K through Yosys and Innovus. Nothing here is part of the
original PDK.

The flow (`syn/`, `pnr/`, `xplace/`) started as a copy of i3dPDK_A16K's
and runs on its own; this checkout does not need i3dPDK_A16K. NS3K can still
be plugged into A16K's flow as a sibling checkout (`pdk_config.{tcl,sh}` are
read by both), but the two copies are now maintained separately.

| File | Purpose |
|---|---|
| `pdk_config.tcl` | Read by `pnr/flow.tcl`: site `i3d_nsfet3nm`, rails on M0 (no BPR), liberty, collateral dir, CTS slew target (0.06 ns; CCOpt's minimum is 0.046), `ROUTE_UNIDIR` default 1 |
| `pdk_config.sh` | Read by `syn/run_syn.sh`: liberty |
| `syn/run_syn.sh`, `syn.tcl`, `sta.tcl` | Yosys synthesis + OpenSTA (docker `ariane-syn:asap7`) -> `syn/out/<design>/NS3K_5T/` |
| `syn/designs/<design>.tcl` | Per-design settings (RTL, top, clock, utilization, macros) |
| `pnr/run_pnr.sh`, `flow.tcl`, `flow_fast.tcl` | Innovus flow (on an Innovus host) -> `pnr/out/<design>/NS3K_5T/<tag>/` |
| `pnr/xplace_place.tcl` | `PLACER=xplace`: hand-off to Xplace on the GPU host |
| `pnr/pa_flip.tcl` | `PA_FLIP=1`: x-mirrors (and with `PA_SHIFT=1` shifts) of the cells next to the PDN before routing, chosen by Xplace's `pinaccess/flip.py` (rule-based with `--rule track`); `PA_SHIFT_CELLS=auto` moves the pin-access critical types (`lef_x4/NS3K_5T_cells.pin_scarcity.txt`, z >= 1) out of the M3 strap bands |
| `pnr/summarize.sh` | One line per finished run |
| `xplace/run_xplace_flow.sh`, `run_xplace_gp.sh`, `xplace_def.py` | Drive a run from the GPU host (Xplace GP, flip) |
| `scripts/gen_lef.py [--scale 4]` | `lef[_x4]/i3dPDK_NS3K_5T_tech.lef`, `..._tech_unidir.lef`, `NS3K_5T_cells.lef`, `i3dPDK_NS3K_streamOut.map` |
| `scripts/gen_macros.sh [--pg-m6]` | Abstract SRAMs in NS3K geometry (`scripts/gen_fakeram.py`): `macros/*.lib`, `lef[_x4]/fakeram*.lef`; `--pg-m6`: the same with horizontal M6 PG straps on the M6 tracks, `lef[_x4]_pgm6/` (for `MACRO_LEF_DIR=lef_x4_pgm6`) |
| `sync_to_server.sh` | Pushes the PDK files the flow reads and this directory (minus `pnr/out/`) to the server, and stamps `.flow_version` |
| `pinaccess/pa_pg_v1.pt` | Per-pin signal-to-PG pin-access risk model for Xplace and the pre-route flip; training and accuracy in `pinaccess/README.md` |

Generated and committed: `lef/`, `lef_x4/`, `lef_pgm6/`, `lef_x4_pgm6/`, `macros/`, the stream map.

PG-clean PDN under the strictly unidirectional tech LEF (`lef_x4/..._tech_unidir_dir.lef`; VDD/VSS
connectivity and PDN DRCs 0 after the floorplan on all designs): `PG_RING_LAYERS="M4 M5" PG_RING_ONGRID=1
PG_STRAP_ONGRID=1`, with macros also `PG_HALO_ONGRID=1 MACRO_LEF_DIR=lef_x4_pgm6` (no PG shape above M6,
every M5 / M6 one on a track). `POST_CTS_LEGALIZE=1` legalizes again after CTS and before routing (the
post-CTS optimization leaves cells overlapping or misoriented now and then; on a legal placement it moves
nothing). `PDN_ONLY=1 PG_CHECK_ABORT=0` stops after the PDN with `rpt/drc_pdn.rpt` and the standard-cell
density of the rows.
Not committed: `syn/out/` (netlists) and `pnr/out/` (runs, on the server).

## Use

```bash
syn/run_syn.sh <design> NS3K_5T            # -> syn/out/<design>/NS3K_5T/
./sync_to_server.sh                        # -> nthucad:i3dPDK_NS3K/
# on an Innovus host, in ~/i3dPDK_NS3K/innovus_enablement/pnr:
env FLOW=fast OUT_TAG=ns3k_uni_fast ./run_pnr.sh <design> NS3K_5T
# runs: pnr/out/<design>/NS3K_5T/<tag>/
```

`ROUTE_UNIDIR=1` (M2-M4 unidirectional) is the default; `PLACE_OPT=0`
replaces `place_opt_design` by bare `place_design` (no pre-CTS optimization).

## Xplace global placement and the pre-route flip

Run from the GPU host, in this directory. Innovus does the floorplan, macro
placement and PDN, Xplace (GPU, `~/Xplace`) places the standard cells, and
Innovus legalizes, runs CTS and routes:

```bash
env FLOW=fast OUT_TAG=<tag> PNR_ENV="ROUTE_UNIDIR=1 XPLACE_PRESERVE=1" PA_FLIP=1 \
    XPLACE_TD=0.85 XPLACE_ARGS="<Xplace main.py options>" \
    xplace/run_xplace_flow.sh <design> NS3K_5T
# Innovus placement instead of Xplace (the flip step still runs here):
env FLOW=fast OUT_TAG=<tag> PLACER=innovus PNR_ENV="ROUTE_UNIDIR=1 PLACE_OPT=0" PA_FLIP=1 \
    xplace/run_xplace_flow.sh <design> NS3K_5T
```

- `XPLACE_PRESERVE=1` skips `optDesign -preCTS`, whose incremental placement
  re-places most cells and undoes the Xplace placement.
- `PA_FLIP=1`: before `routeDesign`, `~/Xplace/pinaccess/flip.py` chooses
  each cell's x-mirror with the pin-access model and Innovus applies it.
- The run goes to `pnr/out/<design>/NS3K_5T/<tag>/`, on the server and
  (reports and `xplace/`, no database) here. Xplace works in
  `~/Xplace/xplace_work/ns3k/`.
- `xplace/` holds the placements `<top>.in.def` (floorplan, cells
  unplaced), `<top>.gp.def` (Xplace), `<top>.lg.def` (after `refinePlace`),
  `<top>.opt.def` (after `optDesign`, or the same placement when it is
  skipped) and `<top>.preroute.def` (with `PA_FLIP=1`), and `flip.log`.
- Methodology and results: `~/Xplace/README_pdn_pin_access.md`.

## Notes on the PDK data

- Tech LEF from `TECH/i3dPDK_NS3K_5T_mw.tf`. The tech section in
  `BE/i3dPDK_NS3K_5T_0V7_27C.lef` is not used: its pitches disagree with
  the tf (M2 0.032 vs 0.024, M3 0.032 vs 0.022, M1 offset 0.016 while the
  pins are centred at 0.022).
- Cell LEF: `NAND2_X1` repeats its VDD rail in its M0 OBS (one M0 short
  with the followpin per instance); OBS inside a cell's own PG pin is
  dropped. `INV_X16_2`, `INV_X32_2`, `INV_X32_3` (no timing; the last is 4
  rows high) are left out.
- Signal pins are full-height vertical M1 bars crossed by 3-4 M2 tracks.
  The tf allows both directions on every layer; NanoRoute routes 16-29% of
  the M2 length the wrong way. NS3K runs therefore default to `ROUTE_UNIDIR=1`
  (set in `pdk_config.tcl`; `ROUTE_UNIDIR=0` brings the bidirectional
  routing back), which uses
  `i3dPDK_NS3K_5T_tech_unidir.lef`: M2-M4 (pitch <= 0.024) take
  `LEF58_RIGHTWAYONGRIDONLY` + `LEF58_RECTONLY` and tracks at offset 0, so
  they carry no wrong-way or off-track wire.
- Strictly unidirectional variants (experiments, `TECH_LEF=<path>`; made from
  `..._tech_unidir.lef` by adding the layer properties, not by `gen_lef.py`):
  - `lef_x4/i3dPDK_NS3K_5T_tech_unidir_dir.lef`: every metal from M5 up also
    takes `LEF58_RIGHTWAYONGRIDONLY` (preferred direction only, on track), the
    rules of the ICC2 flow, whose tf has no rect-only rule; M2-M4 as in
    `_unidir.lef`. The Innovus vs ICC2 comparisons route under this one.
  - `lef_x4/` and `lef/` `i3dPDK_NS3K_5T_tech_unidir_all.lef`: M5+ also take
    `LEF58_RECTONLY`. That rule is not in the ICC2 tf: it adds M7 rect-only
    violations, and the detours it forces add real ones (swerv: 89 violations
    vs 3 under `_dir`).
  The macro PDN cannot be built under either (M5+ on grid): build it under
  `_unidir.lef` and route in a second session under these.
