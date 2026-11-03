# icc2_lm_shell script (run by build_ndm.sh): one NDM from a tf, logic
# libraries (.db or .lib) and a cell LEF.
# Env: NDM_NAME TECH_TF LOGIC_LIBS (space separated) CELL_LEF OUT_NDM
set name $env(NDM_NAME)
create_workspace $name -technology $env(TECH_TF) -flow normal
foreach f $env(LOGIC_LIBS) {
    if {[file extension $f] eq ".db"} { read_db $f } else { read_lib $f }
}
read_lef $env(CELL_LEF)
check_workspace
commit_workspace -force -output $env(OUT_NDM)
exit
