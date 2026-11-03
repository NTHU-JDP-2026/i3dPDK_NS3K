#!/bin/bash
# DREAMPlace global placement of one run, on the GPU host, in place of run_xplace_gp.sh
# (GP_ENGINE=dreamplace in run_xplace_flow.sh): same input and output, so Innovus
# legalizes and continues as after Xplace.
# Usage: [env ...] run_dreamplace_gp.sh <run_xplace_dir>
#   <run_xplace_dir> holds <top>.in.def and <top>.in.lefs from xplace_place.tcl;
#   writes <top>.gp.def (for defIn) and xplace.log (the GP log) next to them.
# Env: DREAMPLACE_DIR    DREAMPlace checkout with its install/ (default ~/DREAMPlace)
#      DREAMPLACE_IMAGE  docker image it runs in (default dreamplace-pa:cu110, docker/dreamplace.Dockerfile)
#      XPLACE_GPU        GPU id (default 0); XPLACE_TD target density (default 0.8), as for Xplace
#      DREAMPLACE_ARGS   extra members of DREAMPlace's JSON (they win over the ones below),
#                        e.g. '"iteration": 2000, "routability_opt_flag": 1'
# GP only (legalize_flag / detailed_place_flag 0), DREAMPlace's defaults otherwise (weighted-average
# wirelength, Nesterov); stop_overflow 0.07 and seed 1, deterministic, as the Xplace runs.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
ddir=${DREAMPLACE_DIR:-$HOME/DREAMPlace}
img=${DREAMPLACE_IMAGE:-dreamplace-pa:cu110}
run=$(cd "$1" && pwd)
in_def=$(ls "$run"/*.in.def)
top=$(basename "$in_def" .in.def)

work=$run/dreamplace
rm -rf "$work"; mkdir -p "$work/lef"
lefs=()
while read -r f; do
  [ -n "$f" ] || continue
  for src in "$repo/../$f" "$repo/$f" "$f"; do [ -f "$src" ] && break; done
  [ -f "$src" ] || { echo "run_dreamplace_gp: LEF $f not found next to $repo" >&2; exit 1; }
  cp "$src" "$work/lef/"
  lefs+=("\"/work/lef/$(basename "$f")\"")
done < "$run/$top.in.lefs"
# the row-free areas as placement blockages, as for Xplace
python3 "$here/xplace_def.py" prep "$in_def" "$work/$top.def"
cat > "$work/$top.json" <<EOF
{
    "lef_input": [$(IFS=,; echo "${lefs[*]}")],
    "def_input": "/work/$top.def",
    "gpu": 1, "num_threads": 8,
    "target_density": ${XPLACE_TD:-0.8},
    "stop_overflow": 0.07,
    "random_seed": 1, "deterministic_flag": 1,
    "global_place_flag": 1, "legalize_flag": 0, "detailed_place_flag": 0,
    "plot_flag": 0,
    "result_dir": "/work/out"${DREAMPLACE_ARGS:+,
    $DREAMPLACE_ARGS}
}
EOF

# one GP per GPU at a time, under the lock run_xplace_gp.sh takes
exec 8>"${XPLACE_LOCK_DIR:-/tmp}/xplace_gpu${XPLACE_GPU:-0}.lock"
flock 8
start=$(date +%s)
docker run --rm --gpus "device=${XPLACE_GPU:-0}" -u "$(id -u):$(id -g)" \
  -v "$ddir:/DREAMPlace/DREAMPlace" -v "$work:/work" -w /DREAMPlace/DREAMPlace/install \
  "$img" python dreamplace/Placer.py "/work/$top.json" > "$run/xplace.log" 2>&1 || {
  tail -20 "$run/xplace.log" >&2; echo "run_dreamplace_gp: DREAMPlace failed, see $run/xplace.log" >&2; exit 1; }
gp_def=$work/out/$top/$top.gp.def
[ -f "$gp_def" ] || { echo "run_dreamplace_gp: no $gp_def (see $run/xplace.log)" >&2; exit 1; }
python3 "$here/xplace_def.py" gp "$in_def" "$gp_def" "$run/$top.gp.def"
echo "run_dreamplace_gp: $top done in $(( $(date +%s) - start )) s"
