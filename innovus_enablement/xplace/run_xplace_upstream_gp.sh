#!/bin/bash
# Unmodified upstream Xplace (TCAD'24, github e370422) with its own PDN handling, as a baseline:
# routability mode (--use_cell_inflate, its README setting), whose PG stripe density in GP considers
# the stripes of one routing layer. Upstream hard-codes routing-layer index 1 (M2 in ISPD2015/ASAP7);
# the only change is --pdn_rindex (~/Xplace/.wt_upstream, branch upstream-pdn-m3), set here to the
# index of XPLACE_PDN_LAYER (default M3, the stripe layer of NS3K) in the tech LEF.
# GP only, as run_xplace_gp.sh (GP_ENGINE=xplace_upstream): Innovus legalizes. (Its own legalization
# aborts on the NS3K multi-height cells in Abacus, so its PA-refine, which runs after it, is not used.)
# Usage: [env XPLACE_ARGS="..." ...] run_xplace_upstream_gp.sh <run_xplace_dir>
# Env: XPLACE_DIR, XPLACE_CONTAINER, XPLACE_GPU, XPLACE_TD, XPLACE_ARGS as in run_xplace_gp.sh;
#      XPLACE_UPSTREAM  the upstream checkout under XPLACE_DIR (default .wt_upstream)
#      XPLACE_PDN_LAYER the stripe layer for --pdn_rindex (default M3)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xdir=${XPLACE_DIR:-$HOME/Xplace}
up=${XPLACE_UPSTREAM:-.wt_upstream}
ctr=${XPLACE_CONTAINER:?set XPLACE_CONTAINER to the docker container that mounts ~/Xplace at /workspace}
run=$(cd "$1" && pwd)
in_def=$(ls "$run"/*.in.def)
top=$(basename "$in_def" .in.def)

name=$(echo "${run##*/pnr/out/}" | tr / _)
work=xplace_work/ns3k_upstream/$name
docker exec "$ctr" rm -rf "/workspace/$work"
mkdir -p "$xdir/$work/lef"
lefs=()
while read -r f; do
  [ -n "$f" ] || continue
  for src in "$repo/../$f" "$repo/$f" "$f"; do [ -f "$src" ] && break; done
  [ -f "$src" ] || { echo "run_xplace_upstream_gp: LEF $f not found next to $repo" >&2; exit 1; }
  cp "$src" "$xdir/$work/lef/"
  lefs+=("\"/workspace/$work/lef/$(basename "$f")\"")
done < "$run/$top.in.lefs"
python3 "$here/xplace_def.py" prep "$in_def" "$xdir/$work/$top.def"
# routing-layer index of the stripe layer in the tech LEF (the first one listed)
pdn_layer=${XPLACE_PDN_LAYER:-M3}
rindex=$(awk -v L="$pdn_layer" '$1 == "LAYER" {l = $2} /TYPE ROUTING/ {if (l == L) {print n; exit}; n++}' \
      "$xdir/$work/lef/$(basename "$(head -1 "$run/$top.in.lefs")")")
[ -n "$rindex" ] || { echo "run_xplace_upstream_gp: no routing layer $pdn_layer in the tech LEF" >&2; exit 1; }
cat > "$xdir/$work/design.json" <<EOF
{
    "benchmark": "ns3k",
    "design_name": "$top",
    "lefs": [$(IFS=,; echo "${lefs[*]}")],
    "def": "/workspace/$work/$top.def"
}
EOF

exec 8>"${XPLACE_LOCK_DIR:-/tmp}/xplace_gpu${XPLACE_GPU:-0}.lock"
flock 8
start=$(date +%s)
docker exec "$ctr" bash -c "cd /workspace/$up && python3 main.py \
  --custom_json /workspace/$work/design.json --load_from_raw True --gpu ${XPLACE_GPU:-0} \
  --use_cell_inflate True --pdn_rindex $rindex \
  --legalization False --detail_placement False --write_global_placement True \
  --exp_id run --result_dir /workspace/$work --output_dir gp --log_dir log --target_density ${XPLACE_TD:-0.8} \
  ${XPLACE_ARGS:-}" > "$run/xplace.log" 2>&1 || {
  tail -20 "$run/xplace.log" >&2; echo "run_xplace_upstream_gp: Xplace failed, see $run/xplace.log" >&2; exit 1; }
# (upstream puts a time stamp in front of --exp_id: <date>run_<default design>/gp/)
gp_def=$(ls -t "$xdir/$work"/*run_*/gp/placement_${top}_gp.def 2>/dev/null | head -1)
[ -n "$gp_def" ] && [ -f "$gp_def" ] || { echo "run_xplace_upstream_gp: no $gp_def (see $run/xplace.log)" >&2; exit 1; }
python3 "$here/xplace_def.py" gp "$in_def" "$gp_def" "$run/$top.gp.def"
echo "run_xplace_upstream_gp: $top done in $(( $(date +%s) - start )) s (stripe layer $pdn_layer = rindex $rindex)"
