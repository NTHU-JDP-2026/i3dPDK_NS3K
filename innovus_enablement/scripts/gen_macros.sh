#!/bin/bash
# Abstract SRAM macros (LEF + lib) for the designs of i3dPDK_A16K's flow, in
# i3dPDK_NS3K geometry, with scripts/gen_fakeram.py (a copy of i3dPDK_A16K's).
# Writes innovus_enablement/macros/*.lib and lef/, lef_x4/*.lef.
#   CPP 0.044, macro height in whole row pairs (0.24) for the row parity,
#   M4 pitch/width 0.024/0.012 (pins one per M4 track), no BPR.
set -euo pipefail
enab=$(cd "$(dirname "$0")/.." && pwd)
gen=$enab/scripts/gen_fakeram.py
geo=(--site-w 0.044 --row-lcm 0.24 --m4-pitch 0.024 --m4-width 0.012 --no-bpr --out "$enab")
# --pg-m6: the same macros with their PG straps horizontal on M6 (pitch 1.008 = 21 M6 tracks, width
# 0.12), centred half an M4 pitch off the M4 grid, into lef_x4_pgm6/ and lef_pgm6/ (their .lib in macros/ as they are): with
# the M4/M5 ring and M5 halo stripes (PG_RING_LAYERS "M4 M5" MACRO_LEF_DIR=lef_x4_pgm6) the PDN has no
# shape above M6 and every M5/M6 one on a track (RIGHTWAYONGRIDONLY).
if [ "${1:-}" = --pg-m6 ]; then
  tmp=$(mktemp -d)
  geo=(--site-w 0.044 --row-lcm 0.24 --m4-pitch 0.024 --m4-width 0.012 --no-bpr --out "$tmp"
       --pg-layer M6 --pg-dir horizontal --pg-pitch 1.008 --pg-width 0.12)
  python3 "$gen" 256x32 --name-prefix fakeram7_ "${geo[@]}"
  python3 "$gen" 64x32 64x7 64x15 64x21 64x96 256x16 256x34 512x64 2048x39 \
      256x95 256x96 32x64 256x48 32x32 64x124 64x62 128x116 \
      --name-prefix fakeram45_ --wmask "${geo[@]}"
  mkdir -p "$enab/lef_pgm6" "$enab/lef_x4_pgm6"
  cp "$tmp"/lef/*.lef "$enab/lef_pgm6/"; cp "$tmp"/lef_x4/*.lef "$enab/lef_x4_pgm6/"
  rm -rf "$tmp"
  exit 0
fi
python3 "$gen" 256x32 --name-prefix fakeram7_ "${geo[@]}"
python3 "$gen" 64x32 64x7 64x15 64x21 64x96 256x16 256x34 512x64 2048x39 \
    256x95 256x96 32x64 256x48 32x32 64x124 64x62 128x116 \
    --name-prefix fakeram45_ --wmask "${geo[@]}"
