#!/bin/bash
# Xplace global placement of one run, on the GPU host (standard cells only;
# macros, IO pins and the PDN are fixed by the Innovus floorplan).
# Usage: [env XPLACE_ARGS="..." ...] run_xplace_gp.sh <run_xplace_dir>
#   <run_xplace_dir> holds <top>.in.def and <top>.in.lefs from xplace_place.tcl;
#   writes <top>.gp.def (for defIn) and xplace.log next to them.
# Env: XPLACE_DIR        Xplace checkout (default ~/Xplace), mounted at /workspace in
#      XPLACE_CONTAINER  the docker container that runs it (required)
#      XPLACE_GPU        GPU id (default 0)
#      XPLACE_TD         target density (default 0.8; Xplace's own default 1.0 packs
#                        regions solid and refinePlace then moves cells ~40x farther,
#                        riscv32i: mean displacement 5.6 vs 0.57 um at 4x)
#      XPLACE_ARGS       extra main.py options (they win over the above), e.g. "--use_cell_inflate True"
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xdir=${XPLACE_DIR:-$HOME/Xplace}
ctr=${XPLACE_CONTAINER:?set XPLACE_CONTAINER to the docker container that mounts ~/Xplace at /workspace}
run=$(cd "$1" && pwd)
in_def=$(ls "$run"/*.in.def)
top=$(basename "$in_def" .in.def)

# Xplace only sees $xdir (the container mount): stage the inputs there.
# (<design>_<LIB>_<tag>_xplace)
name=$(echo "${run##*/pnr/out/}" | tr / _)
work=xplace_work/ns3k/$name
# (files Xplace wrote there before belong to the container's root)
docker exec "$ctr" rm -rf "/workspace/$work"
mkdir -p "$xdir/$work/lef"
lefs=()
# <pdk name>/innovus_enablement/... next to this checkout (runs from before the
# NS3K plugin: innovus_enablement/... inside it; or an absolute path)
while read -r f; do
  [ -n "$f" ] || continue
  for src in "$repo/../$f" "$repo/$f" "$f"; do [ -f "$src" ] && break; done
  [ -f "$src" ] || { echo "run_xplace_gp: LEF $f not found next to $repo" >&2; exit 1; }
  cp "$src" "$xdir/$work/lef/"
  lefs+=("\"/workspace/$work/lef/$(basename "$f")\"")
done < "$run/$top.in.lefs"
python3 "$here/xplace_def.py" prep "$in_def" "$xdir/$work/$top.def"
# Xplace numbers special-net layers by routing-layer index and takes M2/M3
# as indices 1/2 (ASAP7); give it the index of M1 in this tech LEF (the
# first one listed): 1 with an M0 below M1 (NS3K), 2 with BPR and M0 (A16K).
m1r=$(awk '$1 == "LAYER" {l = $2} /TYPE ROUTING/ {if (l == "M1") {print n; exit}; n++}' \
      "$xdir/$work/lef/$(basename "$(head -1 "$run/$top.in.lefs")")")
[ -n "$m1r" ] || { echo "run_xplace_gp: no routing layer M1 in the tech LEF" >&2; exit 1; }
cat > "$xdir/$work/design.json" <<EOF
{
    "benchmark": "ns3k",
    "design_name": "$top",
    "lefs": [$(IFS=,; echo "${lefs[*]}")],
    "def": "/workspace/$work/$top.def"
}
EOF

# GP only: Innovus legalizes and detail-places (refinePlace). XPLACE_DP=1: Xplace's own legalization and
# wirelength-driven detailed placement too (its default engine, after ABCDPlace), and its DP result is used
# (Innovus' refinePlace then only fixes what is left illegal).
dp_args=; [ "${XPLACE_DP:-0}" = 1 ] && dp_args="--legalization True --detail_placement True --write_placement True"
# One GP per GPU at a time (XPLACE_LOCK_DIR, default /tmp): several large
# designs at once ran the 12 GB cards out of memory (ariane133 alone ~5 GB).
exec 8>"${XPLACE_LOCK_DIR:-/tmp}/xplace_gpu${XPLACE_GPU:-0}.lock"
flock 8
start=$(date +%s)
docker exec "$ctr" bash -c "cd /workspace && python3 main.py \
  --custom_json $work/design.json --load_from_raw True --gpu ${XPLACE_GPU:-0} \
  --legalization False --detail_placement False --write_global_placement True \
  --result_dir $work --output_dir gp --log_dir log --target_density ${XPLACE_TD:-0.8} \
  --m1_rindex $m1r ${XPLACE_ARGS:-} $dp_args" > "$run/xplace.log" 2>&1 || {
  tail -20 "$run/xplace.log" >&2; echo "run_xplace_gp: Xplace failed, see $run/xplace.log" >&2; exit 1; }
gp_def=$xdir/$work/gp/placement_${top}_gp.def
[ -n "$dp_args" ] && [ -f "$xdir/$work/gp/placement_${top}_dp.def" ] && gp_def=$xdir/$work/gp/placement_${top}_dp.def
[ -f "$gp_def" ] || { echo "run_xplace_gp: no $gp_def (see $run/xplace.log)" >&2; exit 1; }
python3 "$here/xplace_def.py" gp "$in_def" "$gp_def" "$run/$top.gp.def"
echo "run_xplace_gp: $top done in $(( $(date +%s) - start )) s"
