# i3dPDK_NS3K settings for synthesis: sourced by this checkout's
# syn/run_syn.sh, and by i3dPDK_A16K's syn/run_syn.sh when NS3K is plugged in
# there (LIB NS3K_<N>T). It sees $lib. Macros are read from and netlists
# written to this innovus_enablement/.
ns3k_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LIB_FILE=$ns3k_root/FE/i3dPDK_NS3K_${lib#NS3K_}_0V7_27C.lib
