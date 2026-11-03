#!/bin/bash
# Standalone RePlAce global placement of one run, on the GPU host (CPU only), in place of
# run_xplace_gp.sh (GP_ENGINE=replace in run_xplace_flow.sh): same input and output, so
# Innovus legalizes and continues as after Xplace.
# Usage: [env ...] run_replace_gp.sh <run_xplace_dir>
#   <run_xplace_dir> holds <top>.in.def and <top>.in.lefs from xplace_place.tcl;
#   writes <top>.gp.def (for defIn) and xplace.log (the GP log) next to them.
# Env: REPLACE_DIR    RePlAce checkout, branch standalone, built in build/ (default ~/RePlAce)
#      REPLACE_IMAGE  docker image it was built in and runs in (default replace-build:u18,
#                     docker/replace.Dockerfile, which also has the build steps)
#      XPLACE_TD      target density (default 0.8), as for Xplace
#      REPLACE_ARGS   extra RePlAce Tcl commands before init_replace, ";"-separated,
#                     e.g. "set_bin_grid_count 256"
# Input: the floorplan DEF with only the single-height rows (xplace_def.py rows1h), without the
# row-free blockages Xplace gets: RePlAce fills the core outside the rows with dummy terminals itself,
# which needs replace_dummy_terms.patch (docker/; the standalone branch writes them past the end of
# its terminal array: segfault on every design with macros). The double-height cells are movable
# macros to RePlAce (mixed-size GP; no macro legalization through LEF/DEF). RePlAce leaves the clock
# net out of the wirelength itself. BiCGSTAB initial placement, then Nesterov to overflow 0.07, as
# the Xplace runs.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
rdir=${REPLACE_DIR:-$HOME/RePlAce}
img=${REPLACE_IMAGE:-replace-build:u18}
run=$(cd "$1" && pwd)
in_def=$(ls "$run"/*.in.def)
top=$(basename "$in_def" .in.def)

work=$run/replace
rm -rf "$work"; mkdir -p "$work/lef"
imports=
while read -r f; do
  [ -n "$f" ] || continue
  for src in "$repo/../$f" "$repo/$f" "$f"; do [ -f "$src" ] && break; done
  [ -f "$src" ] || { echo "run_replace_gp: LEF $f not found next to $repo" >&2; exit 1; }
  cp "$src" "$work/lef/"
  imports+="rep import_lef /work/lef/$(basename "$f")"$'\n'
done < "$run/$top.in.lefs"
python3 "$here/xplace_def.py" rows1h "$in_def" "$work/$top.def"
extra=
if [ -n "${REPLACE_ARGS:-}" ]; then
  IFS=';' read -ra cmds <<< "$REPLACE_ARGS"
  for c in "${cmds[@]}"; do [ -n "${c// }" ] && extra+="rep $c"$'\n'; done
fi
cat > "$work/$top.tcl" <<EOF
replace_external rep
${imports}rep import_def /work/$top.def
rep set_output /work/output/
rep set_density ${XPLACE_TD:-0.8}
rep set_target_overflow 0.07
rep set_verbose_level 1
${extra}rep init_replace
rep place_cell_init_place
rep place_cell_nesterov_place
rep export_def /work/$top.gp.def
puts "Final HPWL: [rep get_hpwl]"
EOF

start=$(date +%s)
rp() {  # <tcl> <log>; nonzero if RePlAce failed or reported an error and went on
        # (e.g. cells of the wrong height, a negative HPWL)
  docker run --rm -u "$(id -u):$(id -g)" -v "$rdir:/RePlAce" -v "$work:/work" -w /work \
    "$img" bash -c "/RePlAce/build/replace < /work/$1" > "$2" 2>&1 &&
  ! grep -qE 'height ERROR|NEGATIVE HPWL|DEFPARS-|LEFPARS-' "$2"
}
# The BiCGSTAB initial placement leaves NaN coordinates on some designs (serv: 170 single-pin nets);
# Nesterov then never moves a cell and ends on a negative HPWL. Those run again from RePlAce's
# random-centre start, without the initial placement (the log says so; the first log: xplace_ip.log).
if ! rp "$top.tcl" "$run/xplace.log" && grep -q 'NEGATIVE HPWL' "$run/xplace.log"; then
  mv "$run/xplace.log" "$run/xplace_ip.log"; rm -f "$work/$top.gp.def"
  sed '/place_cell_init_place/d' "$work/$top.tcl" > "$work/${top}_noip.tcl"
  echo "run_replace_gp: initial placement failed (see xplace_ip.log); Nesterov without it" | tee "$run/xplace.log"
  rp "${top}_noip.tcl" "$run/xplace.log.tmp" || true
  cat "$run/xplace.log.tmp" >> "$run/xplace.log"; rm "$run/xplace.log.tmp"
fi
if grep -qE 'height ERROR|NEGATIVE HPWL|DEFPARS-|LEFPARS-' "$run/xplace.log" || [ ! -f "$work/$top.gp.def" ]; then
  grep -m5 -E 'height ERROR|NEGATIVE HPWL|DEFPARS-|LEFPARS-' "$run/xplace.log" >&2
  echo "run_replace_gp: RePlAce reported errors, see $run/xplace.log" >&2; exit 1
fi
[ -f "$work/$top.gp.def" ] || { echo "run_replace_gp: no $work/$top.gp.def (see $run/xplace.log)" >&2; exit 1; }
python3 "$here/xplace_def.py" gp "$in_def" "$work/$top.gp.def" "$run/$top.gp.def"
echo "run_replace_gp: $top done in $(( $(date +%s) - start )) s"
