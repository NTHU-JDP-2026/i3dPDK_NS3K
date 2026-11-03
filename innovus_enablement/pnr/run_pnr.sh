#!/bin/bash
# Run on an Innovus host (ic51/ic21/ic53).
# Usage: [env VAR=... OUT_TAG=<tag> FLOW=full|fast] run_pnr.sh <design> <LIB e.g. NS3K_5T> [clk_period_ns]
# FLOW=fast runs flow_fast.tcl (DRC/DRV + routed wirelength only, no timing/power closure).
# Output: out/<design>/<ARCH_NT>/<tag>/  (tag defaults to "base"; a leading "_" is dropped).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export PDK_ROOT=$(cd "$here/../.." && pwd)
export DESIGN=$1 LIB=$2
[ $# -ge 3 ] && export CLK_PERIOD_NS=$3
tag=${OUT_TAG:-base}; tag=${tag#_}
export OUT_DIR=$here/out/$DESIGN/$LIB/$tag
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"
case ${FLOW:-full} in
  full) script=$here/flow.tcl ;;
  fast) script=$here/flow_fast.tcl ;;
  *) echo "FLOW must be full or fast" >&2; exit 1 ;;
esac
cd "$OUT_DIR"
# INNOVUS_CSHRC: the tool setup to source (default: the CIC Innovus 21.13 of the
# NTHU servers; on tcdl5, /cad/cadence/CIC/ddi.cshrc gives Innovus 23.32)
tcsh -c "source ${INNOVUS_CSHRC:-/usr/cad/cadence/CIC/innovus.cshrc} >& /dev/null; \
  innovus -no_gui -batch -files $script -log $OUT_DIR/innovus.log" > "$OUT_DIR/stdout.log" 2>&1
# innovus -batch exits 0 even when the script aborts
if grep -q 'IMPSYT-6692' "$OUT_DIR/innovus.log"; then
  grep -A1 'IMPSYT-6693' "$OUT_DIR/innovus.log" >&2; exit 1
fi
