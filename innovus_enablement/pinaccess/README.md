# Pin-access risk model for i3dPDK_NS3K

`pa_pg_v1.pt` predicts, for one signal pin of a placed standard cell, the
probability that its M2 access wire ends up in a **signal-to-PG** spacing or
short violation after routing (against a PG via-stack pad or stripe). It is the
`--pa_model` of Xplace's pin-access penalty and of the pre-route flip
(`~/Xplace` branch `pin-access`: `src/pin_access.py`, `pinaccess/flip.py`).

## Model

| | |
|---|---|
| Inputs (318) | the pin's access: number of M2 tracks a via can land on it, which of the row's tracks 1-4 (after orientation), pin width (6); PDN occupancy around the pin: coverage of 13 half-site bins (-3..+3 sites) x 6 track levels on M2, M3, M4 (234); a pin-competition grid, all zero in this model (78) |
| PDN | read from the DEF only (rails, stripe/strap wires, rail via-stack pads); no PDN type is an input, so M3 stripes, M5 straps with via pillars or a mix use the same model |
| Network | MLP 318 -> 256 -> 128 -> 1, ReLU; 114,689 parameters |
| Output | `sigmoid(logit - log(pos_weight))`, pos_weight 150.98 (the class weight used in training) |
| Checkpoint keys | `state`, `mu`/`sd` (normalisation of the 6 access features), `acols`, `grid` (4, 6, 13), `pos_weight`, `no_pin_grid` true, `target` pg |

## Training

- Data: 52 routed runs of the fast flow, unidirectional M2-M4
  (`ROUTE_UNIDIR=1`), 13 designs x 4 setups: Innovus GP with M3 stripes
  (`ns3k_uni3_fast`), Xplace GP with M3 stripes, two parameter sets
  (`ns3k_xp_uni_fast`, `ns3k_xpdrv_fast`), Innovus GP with M5 straps + via pillars
  (`ns3k_pillar_fast`).
- Samples: every signal pin with a PDN shape within its window (~2.0 M pins);
  label 1 when a `verify_drc` signal-to-PG marker lies on the pin's access
  region (~12.5 k positive pins).
- Split by design: trained on gcd, serv, riscv32i, dynamic_node, bp_fe_top,
  bp_be_top, jpeg, swerv, ariane133; tested on tinyRocket, ethmac,
  swerv_wrapper, aes (never seen).
- Scripts: `~/Xplace/pinaccess/extract_grid.py`, `extract_extra.py`
  (labels by violation type), `train_grid.py --model mlp --train_pdn both
  --target pg --no_pin_grid` (12 epochs, Adam 1e-3, batch 4096).

## Accuracy (held-out designs, `pa_pg_v1.metrics.json`)

| Metric | Value |
|---|---|
| Average precision, signal-to-PG, all | 0.895 (M3 stripe 0.898, pillar 0.912) |
| ROC-AUC | 0.998 |
| Per-run predicted vs actual violating pins, correlation | 0.962 |
| On real placements with their real orientations (tinyRocket) | AP 1.00 |

It does not predict signal-to-signal violations (track competition under M3
stripes; AP 0.04): those are most of what is left on the stripe PDN.

## Use so far

Xplace GP with the penalty plus the pre-route flip (fast flow, unidirectional,
Innovus GP floorplans), 13 designs: pillar PDN 0 DRC on 12 designs (2 on
bp_be_top; Innovus GP 2533 in total), M3 stripe PDN signal-to-PG violations
5329 -> 565, total DRC below Innovus GP on every design.
