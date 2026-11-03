#!/bin/bash
# PnR with Xplace as the global placer, driven from the GPU host (where the
# Xplace docker container runs). Innovus does everything else on the Innovus
# host: floorplan, macro placement and PDN as usual, then waits in
# xplace_place.tcl while this script runs the Xplace GP, then legalization,
# detailed placement, CTS and routing.
#
# Usage: [env ...] run_xplace_flow.sh <design> <LIB e.g. NS3K_5T>
# Env: OUT_TAG     run name (default xplace) -> pnr/out/<design>/<LIB>/<tag>/ on the server
#      FLOW        full | fast (default full), as for run_pnr.sh
#      PNR_ENV     extra flow parameters for run_pnr.sh, e.g. "UTIL=0.5 ECO_ROUTE=1"
#      XPLACE_ARGS extra Xplace main.py options (see run_xplace_gp.sh)
#      GP_ENGINE   xplace (default) | dreamplace | replace: the global placer of PLACER=xplace,
#                  run_<engine>_gp.sh (same input and output; DREAMPLACE_ARGS / REPLACE_ARGS)
#      HOST        Innovus host (default ic51)
#      REMOTE      <login host>:<repo path under $HOME> (default nthucad:i3dPDK_NS3K)
#      NO_SYNC=1   skip innovus_enablement/sync_to_server.sh;  NO_WAIT=1  return once the GP is uploaded
#      PLACER=innovus  no Xplace: Innovus places the cells itself (only the PA_FLIP
#                  step runs here; e.g. PNR_ENV="PLACE_OPT=0" for bare place_design)
#      PA_FLIP=1   before routing, x-mirror the cells near the PDN where the pin-access
#                  model (~/Xplace/pinaccess/flip.py, PA_FLIP_MODEL) predicts less risk
#                  (pnr/pa_flip.tcl waits for it); PA_FLIP_ARGS: extra flip.py options,
#                  PA_FLIP_SCRIPT: another script with flip.py's interface (pinaccess/dp_refine.py),
#                  e.g. "--rule block --rule_w 0" for the rule-based baseline
# The run directory is copied back to pnr/out/<design>/<LIB>/<tag>/ here
# (reports and the xplace/ exchange files; not the database).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
design=$1 lib=$2
tag=${OUT_TAG:-xplace}; tag=${tag#_}
host=${HOST:-ic51}
remote=${REMOTE:-nthucad:i3dPDK_NS3K}
gw=${remote%%:*} rrepo=${remote#*:}
lout=$repo/innovus_enablement/pnr/out
rout=$rrepo/innovus_enablement/pnr/out
rrun=$rout/$design/$lib/$tag    # relative to the remote $HOME
lrun=$lout/$design/$lib/$tag
ssh_o=(-o BatchMode=yes -o ServerAliveInterval=30)
on_gw()   { ssh "${ssh_o[@]}" "$gw" bash -s; }                          # script on stdin
on_host() { ssh "${ssh_o[@]}" "$gw" "ssh ${ssh_o[*]} $host bash -s"; }
log() { echo "[$(date +%H:%M:%S)] $*"; }
# The run directory is on NFS: a file Innovus just wrote on $host can take a
# few seconds to show up on $gw (rsync then fails with "No such file").
retry() { local i; for i in 1 2 3 4 5 6; do "$@" && return 0; sleep 10; done; return 1; }

gp_engine=${GP_ENGINE:-xplace}
[ -x "$here/run_${gp_engine}_gp.sh" ] || { log "GP_ENGINE=$gp_engine: no $here/run_${gp_engine}_gp.sh"; exit 1; }

[ -n "${NO_SYNC:-}" ] || "$repo/innovus_enablement/sync_to_server.sh" "$gw:$rrepo/"

log "starting Innovus on $host: $design $lib -> $rrun"
on_host <<EOF
set -e
cd ~/$rrepo/innovus_enablement/pnr
if pgrep -u \$(id -u) -f "$design/$lib/$tag/innovus.log" >/dev/null; then
  echo "an Innovus run is still using ~/$rrun; stop it or pick another OUT_TAG" >&2; exit 1
fi
# A just-killed Innovus can leave NFS .nfs* files behind for a few seconds.
for i in 1 2 3 4 5 6; do rm -rf ~/$rrun 2>/dev/null && break; sleep 10; done
[ ! -e ~/$rrun ] || { echo "cannot remove ~/$rrun" >&2; exit 1; }
env PLACER=${PLACER:-xplace} OUT_TAG=$tag FLOW=${FLOW:-full} ${PNR_ENV:-} ${PA_FLIP:+PA_FLIP=$PA_FLIP} \
  setsid nohup bash run_pnr.sh $design $lib </dev/null >/dev/null 2>&1 &
EOF

t0=$(date +%s)
if [ "${PLACER:-xplace}" = xplace ]; then
# state of the remote run: ready (floorplan DEF written) | failed | running | gone
remote_state() {
  on_host <<EOF
cd ~/$rrun 2>/dev/null || { echo running; exit; }
if ls xplace/*.in.ready >/dev/null 2>&1; then echo ready
elif grep -q IMPSYT-6692 innovus.log 2>/dev/null; then echo failed
elif pgrep -u \$(id -u) -f "$design/$lib/$tag/innovus.log" >/dev/null; then echo running
else echo gone; fi
EOF
}
gone=0
while :; do
  st=$(remote_state) || st=running   # a failed ssh is retried
  # "gone" twice in a row: the process may not show up right at the start
  if [ "$st" = gone ]; then [ $((++gone)) -lt 2 ] && st=running; else gone=0; fi
  case $st in
    ready) break ;;
    running) sleep 30 ;;
    *) log "Innovus stopped before the global placement ($st); see $gw:$rrun/innovus.log"
       on_gw <<<"grep -A2 IMPSYT-6693 ~/$rrun/innovus.log | head; tail -5 ~/$rrun/stdout.log" || true
       exit 1 ;;
  esac
done
log "floorplan ready after $(( ($(date +%s) - t0) / 60 )) min"

mkdir -p "$lrun/xplace"
retry rsync -a "$gw:$rrun/xplace/" "$lrun/xplace/"
top=$(basename "$(ls "$lrun"/xplace/*.in.def)" .in.def)
log "global placement: $gp_engine"
if ! "$here/run_${gp_engine}_gp.sh" "$lrun/xplace"; then
  on_gw <<<"echo '$gp_engine failed on $(hostname), see $lrun/xplace/xplace.log' > ~/$rrun/xplace/$top.gp.failed"
  exit 1
fi
retry rsync -a "$lrun/xplace/$top.gp.def" "$lrun/xplace/xplace.log" "$gw:$rrun/xplace/"
retry ssh "${ssh_o[@]}" "$gw" "touch ~/$rrun/xplace/$top.gp.ready"
log "global placement uploaded; Innovus continues on $host"
[ -z "${NO_WAIT:-}" ] || exit 0
else
  log "PLACER=${PLACER}: no Xplace; Innovus places the cells on $host"
fi

if [ -n "${PA_FLIP:-}" ]; then
  # wait for the placement before routing, choose the flips, send them back
  # (with PLACER=innovus the design's top name is known only from these files)
  # ("gone" twice in a row: right after the start, with PLACER=innovus, the
  # Innovus process may not show up yet, and the flip would be skipped)
  gone=0
  while :; do
    st=$(on_host <<<"if ls ~/$rrun/xplace/*.preroute.ready >/dev/null 2>&1; then echo ready; elif pgrep -u \$(id -u) -f '$design/$lib/$tag/innovus.log' >/dev/null; then echo running; else echo gone; fi") || st=running
    if [ "$st" = gone ]; then [ $((++gone)) -lt 2 ] && st=running; else gone=0; fi
    [ "$st" != running ] && break
    sleep 30
  done
  if [ "$st" = ready ]; then
    mkdir -p "$lrun/xplace"
    retry rsync -a "$gw:$rrun/xplace/" "$lrun/xplace/"
    top=$(basename "$(ls "$lrun"/xplace/*.preroute.def)" .preroute.def)
    xdir=${XPLACE_DIR:-$HOME/Xplace}; ctr=${XPLACE_CONTAINER:-compassionate_pascal}
    fw=xplace_work/ns3k/$(echo "${lrun##*/pnr/out/}" | tr / _)_flip
    mkdir -p "$xdir/$fw"
    cells=$(grep cells "$lrun/xplace/$top.in.lefs" | head -1)
    for src in "$repo/../$cells" "$repo/$cells" "$cells"; do [ -f "$src" ] && break; done
    cp "$src" "$lrun/xplace/$top.in.def" "$lrun/xplace/$top.preroute.def" "$xdir/$fw/"
    # on this run's GPU, under run_xplace_gp.sh's per-GPU lock (next to a GP of
    # ariane133 there, flip.py ran the card out of memory)
    if ( exec 8>"${XPLACE_LOCK_DIR:-/tmp}/xplace_gpu${XPLACE_GPU:-0}.lock"; flock 8
         docker exec -e CUDA_VISIBLE_DEVICES=${XPLACE_GPU:-0} "$ctr" bash -c "cd /workspace && python3 ${PA_FLIP_SCRIPT:-pinaccess/flip.py} ${PA_FLIP_MODEL:-pinaccess/runs/grid/mlp_both_pg_nopin.pt} \
         $fw/$(basename "$src") $fw/$top.in.def $fw/$top.preroute.def $fw/$top.flip ${PA_FLIP_ARGS:-}" ) > "$lrun/xplace/flip.log" 2>&1; then
      log "$(tail -1 "$lrun/xplace/flip.log")"
      cp "$xdir/$fw/$top.flip" "$lrun/xplace/"
      retry rsync -a "$lrun/xplace/$top.flip" "$gw:$rrun/xplace/"
      retry ssh "${ssh_o[@]}" "$gw" "touch ~/$rrun/xplace/$top.flip.ready"
    else
      tail -5 "$lrun/xplace/flip.log" >&2
      on_gw <<<"echo 'flip.py failed on $(hostname), see $lrun/xplace/flip.log' > ~/$rrun/xplace/$top.flip.failed"
      exit 1
    fi
  fi
fi

# until the Innovus process is gone (a failed ssh counts as still running)
until st=$(on_host <<<"pgrep -u \$(id -u) -f '$design/$lib/$tag/innovus.log' >/dev/null && echo running || echo gone") \
      && [ "$st" = gone ]; do
  sleep 60
done
retry rsync -a --exclude db --exclude '*.gds' --exclude '*.spef' "$gw:$rrun/" "$lrun/"
if grep -q IMPSYT-6692 "$lrun/innovus.log"; then
  log "Innovus failed after the global placement; see $lrun/innovus.log"
  grep -A1 IMPSYT-6693 "$lrun/innovus.log" | head >&2
  exit 1
fi
log "done after $(( ($(date +%s) - t0) / 60 )) min"
bash "$repo/innovus_enablement/pnr/summarize.sh" "$lrun"
