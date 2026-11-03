#!/bin/bash
# Push what synthesis and PnR read (liberty, cell LEF, tf, and this
# innovus_enablement/ minus the run outputs) to the Innovus server, stamping
# innovus_enablement/.flow_version with the current commit so every run
# records which flow produced it (see run_params.json).
# Usage: sync_to_server.sh [user@host:path/i3dPDK_NS3K/]   (default: nthucad:i3dPDK_NS3K/)
# i3dPDK_A16K's pnr/sync_to_server.sh also calls it with its own destination
# (.../i3dPDK_A16K/); the checkout then goes next to it.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dest=${1:-nthucad:i3dPDK_NS3K/}
dest=${dest%/}
case $dest in *i3dPDK_A16K) dest=${dest%i3dPDK_A16K}i3dPDK_NS3K ;; esac
dest=$dest/
cd "$root"
rev=$(git rev-parse --short HEAD)
git diff --quiet HEAD -- innovus_enablement || rev="$rev+dirty"
echo "$rev $(date +%Y-%m-%dT%H:%M:%S)" > innovus_enablement/.flow_version
# (pnr/out: the runs on the server, never overwritten or deleted from here)
rsync -az --delete -m \
  --exclude nthucad.md --exclude '*.ndm' --exclude '*.db' --exclude .git \
  --exclude 'innovus_enablement/pnr/out' --exclude 'innovus_enablement/syn/out/*/*/yosys.log' \
  --include README.txt --include 'FE/' --include 'FE/*.lib' --include 'BE/' --include 'BE/*.lef' \
  --include 'TECH/' --include 'TECH/*.tf' --include 'innovus_enablement/***' --exclude '*' \
  "$root/" "$dest"
echo "synced i3dPDK_NS3K $rev -> $dest"
