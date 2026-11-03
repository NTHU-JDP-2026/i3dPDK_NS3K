#!/bin/bash
# route2.sh <tag> <design>...: second session of the ROUTE_SPLIT=1 runs (flow_fast.tcl): routes
# out/<design>/NS3K_5T/<tag>/preroute_full.def with NanoRoute under a strictly unidirectional tech LEF
# (R2_TECH, default _unidir_dir: M5+ preferred direction on track as in the ICC2 flow; _unidir_all also
# puts RECTONLY on M5+) into <run>/route2/ (drc.rpt, conn.rpt, routed.def). Waits for each run's first session.
tag=$1; shift
N=~/i3dPDK_NS3K/innovus_enablement/pnr/out; E=~/i3dPDK_NS3K/innovus_enablement/lef_x4
tech=${R2_TECH:-_unidir_dir}
pending="$*"; hs=(ic55 ic53 ic22); k=0
while [ -n "$pending" ]; do
  left=
  for d in $pending; do R=$N/$d/NS3K_5T/$tag
    if [ -f $R/preroute_full.def ] && grep -q 'Ending "Innovus"' $R/innovus.log 2>/dev/null; then
      top=$(grep -o '"top": "[^"]*"' $R/run_params.json | cut -d'"' -f4)
      mlefs=$(grep -o '"macros": "[^"]*"' $R/run_params.json | cut -d'"' -f4 | tr ' ' '\n' | grep . | sed "s|^|$E/|; s|\$|.lef|" | tr '\n' ' ')
      W=$R/route2; rm -rf $W; mkdir -p $W
      cat > $W/run.tcl <<T
set init_lef_file   [list $E/i3dPDK_NS3K_5T_tech${tech}.lef $E/NS3K_5T_cells.lef $mlefs]
set init_verilog    $R/preroute.v
set init_top_cell   $top
set init_pwr_net    VDD
set init_gnd_net    VSS
init_design
setDesignMode -bottomRoutingLayer M2 -topRoutingLayer M11
defIn $R/preroute_full.def
setNanoRouteMode -routeWithTimingDriven false -routeWithSiDriven false
routeDesign
verify_drc -report drc.rpt -limit 100000
verifyConnectivity -type all -report conn.rpt
defOut -routing routed.def
exit
T
      h=${hs[$((k % 3))]}; k=$((k+1))
      ssh -o BatchMode=yes $h "bash -s" <<X &
cd $W && tcsh -c "source /usr/cad/cadence/CIC/innovus.cshrc >& /dev/null; innovus -no_gui -batch -files run.tcl -log innovus.log" > stdout.txt 2>&1 < /dev/null
X
      echo "$(date +%H:%M) $d $tag route2 -> $h"
    elif grep -q 'IMPSYT-6692' $R/innovus.log 2>/dev/null; then echo "$(date +%H:%M) $d $tag first session failed"
    else left="$left $d"; fi
  done
  pending=$left; [ -n "$pending" ] && sleep 120
done
wait
for d in $*; do W=$N/$d/NS3K_5T/$tag/route2; echo "$d $tag $(python3 ~/drc_split.py $W/drc.rpt 2>/dev/null) wl=$(grep '#Total wire length =' $W/innovus.log 2>/dev/null | tail -1 | awk '{printf "%.0f", $5/4}')"; done
