#!/bin/bash
# Run on an ICC2 host (ic21/ic51/ic53).
# Usage: [env VAR=... OUT_TAG=<tag> FLOW=fast|full] run_pnr.sh <design> <LIB e.g. NS3K_5T> [clk_period_ns]
# Output: out/<design>/<LIB>/<tag>/  (tag defaults to "base"; a leading "_" is dropped).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export PDK_ROOT=$(cd "$here/../.." && pwd)
export DESIGN=$1 LIB=$2
[ $# -ge 3 ] && export CLK_PERIOD_NS=$3
tag=${OUT_TAG:-base}; tag=${tag#_}
export OUT_DIR=$here/out/$DESIGN/$LIB/$tag
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
# stdin from /dev/null: on a script error icc2_shell drops to its prompt and
# would wait there forever
# ICC2_CSHRC / ICC2_SHELL: the tool setup and shell (default: the CIC ICC2 2023.12 of
# the NTHU servers; on tcdl5, /cad/synopsys/CIC/fc.cshrc and fc_shell, Fusion Compiler)
tcsh -c "source ${ICC2_CSHRC:-/usr/cad/synopsys/CIC/icc2.cshrc} >& /dev/null; \
  ${ICC2_SHELL:-icc2_shell} -f $here/flow.tcl -output_log_file $OUT_DIR/icc2.log" < /dev/null > "$OUT_DIR/stdout.log" 2>&1 || true
if ! grep -q '"finished"' "$OUT_DIR/run_params.json" && [ -z "${STOP_AFTER:-}" ]; then
  echo "run_pnr.sh: $DESIGN $tag did not finish:" >&2
  grep -v 'script has expired' "$OUT_DIR/icc2.log" | grep -B2 -A6 -m3 -E '^Error|stopped at line' >&2 || true
  exit 1
fi
