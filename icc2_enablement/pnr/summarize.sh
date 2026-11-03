#!/bin/bash
# One line per run: pnr/summarize.sh [tag-glob] [design-glob]
# status: done / running (last stage) / failed; DRC = check_routes total
# violations; WL = routed wire length (um); shorts/opens = check_lvs;
# wrong-way = detail-route shapes running across their layer's preferred
# direction, M1 to the top routing layer (rpt/wrong_way.rpt); PG = floating PDN objects/pins (check_pg_connectivity) +
# VDD/VSS opens and shorts (check_lvs on the PG nets), "-" before the run
# ends; min = wall-clock minutes.
here=$(cd "$(dirname "$0")" && pwd)
tg=${1:-*}; dg=${2:-*}
printf "%-14s %-18s %-22s %8s %10s %7s %6s %4s %18s %6s\n" design tag status DRC WL shorts opens PG "wrong-way" min
for d in $here/out/$dg/*/$tg; do
  [ -f "$d/run_params.json" ] || continue
  des=$(basename "$(dirname "$(dirname "$d")")"); tag=$(basename "$d")
  log=$d/icc2.log
  if grep -q '"finished"' "$d/run_params.json"; then st=done
  elif (for p in $(pgrep -u "$(id -u)" icc2_exec); do [ "$(readlink /proc/$p/cwd)" = "$d" ] && exit 0; done; exit 1); then
    st="running:$(grep -oE '^ *(place_opt|create_placement|clock_opt|route_auto|route_opt|compile_pg|check_routes)( |$)' "$log" | tail -1 | tr -d ' ')"
  else st="failed:$(grep -v 'script has expired' "$log" 2>/dev/null | grep -m1 -oE '^Error: .{0,14}' | tr ' ' _)"; fi
  drc=$(grep -m1 'TOTAL VIOLATIONS' "$d/rpt/check_routes.rpt" 2>/dev/null | awk '{print $NF}')
  wl=$(grep -m1 'Total Wire Length' "$d/rpt/check_routes.rpt" 2>/dev/null | awk '{print $(NF-1)}')
  sh=$(grep -m1 'Total number of short' "$d/rpt/check_lvs.rpt" 2>/dev/null | awk '{print $NF}' | tr -d .)
  op=$(grep -m1 'Total number of open nets' "$d/rpt/check_lvs.rpt" 2>/dev/null | awk '{print $NF}' | tr -d .)
  pg=-
  if [ -f "$d/rpt/check_lvs_pg.rpt" ]; then
    pg=$(( $(grep -E 'Number of floating' "$d/rpt/pg_final.rpt" | awk -F: '{s+=$2} END{print s+0}') \
         + $(grep -E 'Total number of (open nets|short violations)' "$d/rpt/check_lvs_pg.rpt" | awk '{s+=$NF} END{print s+0}') ))
  fi
  ww=$(awk 'NR>1{n+=$5} END{if (NR>1) print n+0}' "$d/rpt/wrong_way.rpt" 2>/dev/null)
  t0=$(grep -oE '"started": "[^"]+"' "$d/run_params.json" | cut -d'"' -f4)
  t1=$(grep -oE '"finished": "[^"]+"' "$d/run_params.json" | cut -d'"' -f4)
  [ -n "$t1" ] || t1=$(date -r "$log" +%Y-%m-%dT%H:%M:%S 2>/dev/null)
  min=$(( ($(date -d "$t1" +%s) - $(date -d "$t0" +%s)) / 60 ))
  printf "%-14s %-18s %-22s %8s %10s %7s %6s %4s %18s %6s\n" "$des" "$tag" "$st" "${drc:--}" "${wl:--}" "${sh:--}" "${op:--}" "$pg" "${ww:--}" "$min"
done
