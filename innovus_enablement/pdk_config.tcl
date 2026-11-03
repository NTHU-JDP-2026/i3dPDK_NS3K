# i3dPDK_NS3K settings for the Innovus flow: this checkout's pnr/flow.tcl
# sources it, and so does i3dPDK_A16K's flow.tcl when NS3K is plugged in there
# as a sibling checkout (LIB NS3K_<N>T). It sees $arch and $trk.
set ns3k_root  [file normalize [file join [file dirname [info script]] ..]]
set pdk_name   i3dPDK_NS3K
# generated LEFs, macros, netlists, stream map; runs go to $enab/pnr/out
set enab       $ns3k_root/innovus_enablement
set site_name  i3d_nsfet3nm
# Rails on M0 (no BPR), 12nm wide; the M1 signal pins are full-height bars.
set rail_layer M0
set rail_hw1   0.006
# CCOpt: minimum achievable clock slew 0.046ns (A16K: ~0.029ns)
set cts_trans  0.06
set lib_file   $ns3k_root/FE/i3dPDK_NS3K_${trk}_0V7_27C.lib
# M2-M4 unidirectional (i3dPDK_NS3K_5T_tech_unidir.lef) by default: at these
# pitches the lower metals are printed in one direction only. ROUTE_UNIDIR=0
# in the environment brings back the bidirectional tf behaviour.
set route_unidir [design_param ROUTE_UNIDIR 1]
