# i3dPDK_NS3K settings for the ICC2 flow (pnr/flow.tcl sources this file; it
# sees $trk, e.g. 5T). Native geometry: the PDK's tf, cell data and TLU+, no scaling
# (the 4x LEFs of innovus_enablement/ are an Innovus licensing workaround).
# The cell NDM is rebuilt from the PDK data (ndm/build_ndm.sh), see there.
set ns3k_root  [file normalize [file join [file dirname [info script]] ..]]
set pdk_name   i3dPDK_NS3K
set enab       $ns3k_root/icc2_enablement
# Netlists and per-design settings are shared with the Innovus flow.
set syn_dir    $ns3k_root/innovus_enablement/syn
set cell_ndm   $enab/ndm/out/NS3K_${trk}.ndm
# tf with the via definitions on the 1 nm grid (scripts/fix_tf.py)
set tech_tf    $enab/tech/i3dPDK_NS3K_${trk}.tf
set tluplus    $ns3k_root/TECH/i3dPDK_NS3K_${trk}_0V7_27C.tluplus
set tlu_map    $ns3k_root/TECH/i3dPDK_NS3K_map_file
# Cell and macro (abstract SRAM) NDMs, built by ndm/build_ndm.sh
set macro_ndm_dir $enab/ndm/out
set site_name  i3d_nsfet3nm
# Rails on M0, 12nm wide; the M1 signal pins are full-height bars.
set rail_layer M0
set rail_w     0.012
set cts_trans  0.06
# The tf has no preferred directions: even layers horizontal, odd vertical
# (as in the Innovus tech LEF).
set layer_dirs {}
for {set i 0} {$i <= 16} {incr i} { lappend layer_dirs M$i [expr {$i % 2 ? "vertical" : "horizontal"}] }
# M2-M4 unidirectional, on track (ROUTE_UNIDIR=1, default): the layers whose
# pitch is <= 0.024um. Their tracks start at offset 0 (a track on every row
# boundary, rows hold tracks 1-4), the others at pitch/2, as in the Innovus LEFs.
set unidir_layers {M2 M3 M4}
set route_unidir [design_param ROUTE_UNIDIR 1]
# Cells in the NDM without timing or never to be used
set dont_use   {SDFF_X1 SDFF_X2}
set cts_bufs   {BUF_X1 BUF_X2 BUF_X4 BUF_X8 BUF_X16}
set cts_invs   {INV_X1 INV_X2 INV_X4 INV_X8 INV_X16}
