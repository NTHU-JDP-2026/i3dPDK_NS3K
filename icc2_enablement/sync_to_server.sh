#!/bin/bash
# Push what the ICC2 flow reads to the server: the PDK's NDM, tf, TLU+ and
# layer map, this icc2_enablement/ (minus the run outputs), and the netlists
# and design settings it shares with the Innovus flow
# (innovus_enablement/syn/{designs,out}). Stamps icc2_enablement/.flow_version
# with the current commit so every run records which flow produced it.
# Usage: sync_to_server.sh [user@host:path/i3dPDK_NS3K/]   (default: nthucad:i3dPDK_NS3K/)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dest=${1:-nthucad:i3dPDK_NS3K/}
dest=${dest%/}/
cd "$root"
rev=$(git rev-parse --short HEAD)
git diff --quiet HEAD -- icc2_enablement 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard icc2_enablement)" ] || rev="$rev+dirty"
echo "$rev $(date +%Y-%m-%dT%H:%M:%S)" > icc2_enablement/.flow_version
# No --delete: innovus_enablement/sync_to_server.sh owns the rest of the tree.
rsync -az -m \
  --exclude 'icc2_enablement/pnr/out' --exclude 'icc2_enablement/ndm/out' --exclude 'icc2_enablement/ndm/work' --exclude 'innovus_enablement/syn/out/*/*/yosys.log' \
  --include 'BE/' --include 'BE/*.ndm/***' --include 'FE/' --include 'FE/*.lib' --include 'FE/*.db' \
  --include 'TECH/' --include 'TECH/*.tf' --include 'TECH/*.tluplus' --include 'TECH/*map_file' \
  --include 'icc2_enablement/***' \
  --include 'innovus_enablement/' --include 'innovus_enablement/syn/' \
  --include 'innovus_enablement/syn/designs/***' --include 'innovus_enablement/syn/out/***' \
  --include 'innovus_enablement/lef/' --include 'innovus_enablement/lef/fakeram*.lef' \
  --include 'innovus_enablement/macros/***' \
  --exclude '*' \
  "$root/" "$dest"
echo "synced i3dPDK_NS3K (ICC2) $rev -> $dest"
