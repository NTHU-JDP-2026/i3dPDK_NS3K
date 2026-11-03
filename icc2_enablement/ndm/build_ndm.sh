#!/bin/bash
# Build the NDMs the ICC2 flow links, on an ICC2 host (ic21/ic51/ic53):
#   out/NS3K_<N>T.ndm   standard cells: tech/*.tf (TECH/*.tf with the vias
#                       on grid, scripts/fix_tf.py) + FE/*.db + the PDK cell LEF
#                       fixed by scripts/fix_cell_lef.py
#   out/<macro>.ndm     abstract SRAMs (innovus_enablement/lef/fakeram*.lef,
#                       1x, and innovus_enablement/macros/<macro>.lib)
# The PDK's own BE/*.ndm is not used: it carries the NAND2_X1 rail in its
# OBS (an M0 short at every instance in check_lvs).
# Usage: build_ndm.sh [NS3K_5T] [macro ...]   (default: the cells and every macro)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
lib=${1:-NS3K_5T}; shift || true
trk=${lib#NS3K_}
macros=("$@")
[ $# -gt 0 ] || macros=($(cd "$root/innovus_enablement/macros" && ls *.lib | sed 's/\.lib$//'))
mkdir -p "$here/out" "$here/work"
export TECH_TF=$here/../tech/i3dPDK_NS3K_${trk}.tf   # scripts/fix_tf.py
# Each NDM is committed to work/ and then renamed into out/: runs that still
# have the old one open keep it (on NFS its directory cannot be removed while
# open, and commit_workspace -force then leaves the new one aside).
lm() {  # <name> <out.ndm> <cell lef> <logic libs...>
  local dst=$2
  local w=$here/work/$1; rm -rf "$w"; mkdir -p "$w"
  export NDM_NAME=$1 OUT_NDM=$w/$1.ndm CELL_LEF=$3; shift 3; export LOGIC_LIBS="$*"
  (cd "$w" && tcsh -c "source /usr/cad/synopsys/CIC/icc2.cshrc >& /dev/null; \
     icc2_lm_shell -f $here/build_ndm.tcl -output_log_file $w/lm.log" < /dev/null > "$w/stdout.log" 2>&1) || true
  if ! grep -q '^Workspace check succeeded' "$w/lm.log" || [ ! -d "$OUT_NDM" ] || [ -z "$(ls -A "$OUT_NDM")" ]; then
    echo "build_ndm.sh: $NDM_NAME failed (see $w/lm.log)" >&2
    grep -v 'script has expired' "$w/lm.log" | grep -m5 -A3 '^Error' >&2 || true
    exit 1
  fi
  rm -rf "$dst.old" 2>/dev/null || true
  [ -e "$dst" ] && mv "$dst" "$dst.old.$$"
  mv "$OUT_NDM" "$dst"
  rm -rf "$dst".old.* "$dst"@* 2>/dev/null || true
  echo "built $dst"
}
python3 "$here/../scripts/fix_cell_lef.py" "$root/BE/i3dPDK_NS3K_${trk}_0V7_27C.lef" "$here/work/${lib}_cells.lef"
lm "$lib" "$here/out/$lib.ndm" "$here/work/${lib}_cells.lef" "$root/FE/i3dPDK_NS3K_${trk}_0V7_27C.db"
# .lib -> .db with Library Compiler (icc2_lm_shell's read_lib needs an LC
# install inside the ICC2 tree, which this server does not have).
lc_db() {  # <lib file> <out.db>
  local w=$here/work/lc_$(basename "$1" .lib); rm -rf "$w"; mkdir -p "$w"
  local name; name=$(sed -n 's/^ *library *( *\([^ )]*\) *).*/\1/p' "$1" | head -1)
  printf 'read_lib %s\nwrite_lib %s -format db -output %s\nexit\n' "$1" "$name" "$2" > "$w/lc.tcl"
  (cd "$w" && tcsh -c "source /usr/cad/synopsys/CIC/license.csh >& /dev/null; \
     /usr/cad/synopsys/lc/cur/bin/lc_shell -f $w/lc.tcl" < /dev/null > "$w/lc.log" 2>&1) || true
  [ -f "$2" ] || { echo "build_ndm.sh: lc_shell failed on $1 (see $w/lc.log)" >&2; grep -m5 -A2 '^Error' "$w/lc.log" >&2; exit 1; }
}
for m in "${macros[@]}"; do
  [ "$m" = none ] && continue
  lc_db "$root/innovus_enablement/macros/$m.lib" "$here/work/$m.db"
  lm "$m" "$here/out/$m.ndm" "$root/innovus_enablement/lef/$m.lef" "$here/work/$m.db"
done
