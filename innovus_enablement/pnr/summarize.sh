#!/bin/bash
# Summarize finished PnR runs (one line each), in 1x units.
# Usage: summarize.sh [out/<design>/<LIB>/<tag> ...]   (default: every run under out/)
# Env:   LEF_SCALE (default 4) -- must match the scale the runs used.
here=$(cd "$(dirname "$0")" && pwd)
scale=${LEF_SCALE:-4}
[ $# -eq 0 ] && set -- "$here"/out/*/*/*/
printf '%-32s %6s %9s %13s %8s %8s %7s %6s %4s %4s %7s %s\n' \
  run cells area_um2 die_um setupWNS holdWNS wl_um mW DRC DRV PGconn signalConn
for d in "$@"; do
  d=${d%/}; r=$d/rpt; [ -f "$r/area.rpt" ] || continue
  # first row after the dashed header: <top> [module] <inst count> <area>
  read -r cells area < <(awk -v s=$scale 'f {printf "%d %.2f", $(NF-1), $NF/s/s; exit} /^---/ {f=1}' "$r/area.rpt")
  die=$(awk -v s=$scale '/^DIEAREA/ {printf "%.2fx%.2f", ($7-$3)/2000/s, ($8-$4)/2000/s; exit}' "$d"/*.def 2>/dev/null)
  setup=$(zcat "$r/final/final.summary.gz" | awk -F'|' '/WNS \(ns\)/ {gsub(/ /,"",$3); print $3; exit}')
  hold=$(zcat "$r/final/final_hold.summary.gz" | awk -F'|' '/WNS \(ns\)/ {gsub(/ /,"",$3); print $3; exit}')
  drv=$(zcat "$r/final/final.summary.gz" | awk -F'|' '/max_cap|max_tran|max_fanout/ {split($3,a," "); n+=a[1]} END {print n+0}')
  wl=$(grep '#Total wire length =' "$d/innovus.log" | tail -1 | awk -v s=$scale '{printf "%.0f", $5/s}')
  pwr=$(awk '/Total Power:/ {printf "%.2f", $3}' "$r/power.rpt")
  drc=$(grep -oE 'Total Violations : [0-9]+' "$r/drc.rpt" | awk '{print $4}'); drc=${drc:-0}
  # PG connectivity comes from the special-net problems; signal from the rest.
  pg=$(grep -cE '^Net (VDD|VSS):' "$r/conn.rpt"); sig=$(grep -E '^Net ' "$r/conn.rpt" | grep -vcE '^Net (VDD|VSS):')
  printf '%-32s %6s %9s %13s %8s %8s %7s %6s %4s %4s %7s %s\n' \
    "$(echo "$d" | awk -F/ '{print $(NF-2)"/"$(NF-1)"/"$NF}')" "$cells" "$area" "$die" "$setup" "$hold" "$wl" "$pwr" "$drc" "$drv" \
    "$([ "$pg" -eq 0 ] && echo clean || echo "$pg")" "$([ "$sig" -eq 0 ] && echo clean || echo "$sig")"
done
