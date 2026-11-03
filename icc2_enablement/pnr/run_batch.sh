#!/bin/bash
# Start run_pnr.sh for several designs in parallel, detached (survives the
# ssh session). Settings come from the environment as for run_pnr.sh.
# Usage: [env VAR=...] run_batch.sh <tag> <LIB> <design>...
# Logs: out/batch/<tag>.<design>.log; pnr/summarize.sh reads the runs.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tag=$1 lib=$2; shift 2
mkdir -p "$here/out/batch"
for d in "$@"; do
  OUT_TAG=$tag nohup "$here/run_pnr.sh" "$d" "$lib" > "$here/out/batch/$tag.$d.log" 2>&1 < /dev/null &
  echo "started $d ($tag) pid $!"
done
