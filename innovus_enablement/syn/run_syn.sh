#!/bin/bash
# Usage: run_syn.sh <design> <LIB e.g. NS3K_5T> [clk_period_ns]
# Liberty from ../pdk_config.sh (it sees $lib); macros read from ../macros,
# netlists written to out/<design>/<LIB>/ (where pnr/flow.tcl reads them).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
design=$1; lib=$2
[ "${lib%%_*}" = NS3K ] || { echo "run_syn.sh: LIB must be NS3K_<N>T, not $lib" >&2; exit 1; }
export DESIGN_CFG=$here/designs/$design.tcl
. "$here/../pdk_config.sh"
export LIB_FILE
export MACRO_DIR=$here/../macros
export OUT_DIR=$here/out/$design/$lib
[ $# -ge 3 ] && export CLK_PERIOD_NS=$3
mkdir -p "$OUT_DIR"
run() { docker run --rm -u "$(id -u):$(id -g)" -v "$HOME:$HOME" -w "$here" \
          -e LIB_FILE -e DESIGN_CFG -e OUT_DIR -e MACRO_DIR ${CLK_PERIOD_NS:+-e CLK_PERIOD_NS} \
          ariane-syn:asap7 "$@"; }
run yosys -c "$here/syn.tcl" > "$OUT_DIR/yosys.log" 2>&1 || { tail -30 "$OUT_DIR/yosys.log"; exit 1; }
run sta -no_splash -exit "$here/sta.tcl" 2>&1 | tee "$OUT_DIR/sta.log"
