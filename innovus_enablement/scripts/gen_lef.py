#!/usr/bin/env python3
"""Innovus LEFs and stream map for i3dPDK_NS3K, with the writers of
../../../i3dPDK_A16K/innovus_enablement/scripts/gen_innovus_lef.py.

    gen_lef.py [--scale N] [--dbu 2000]

Writes, under innovus_enablement/:
  lef[_x<N>]/i3dPDK_NS3K_5T_tech.lef         tech LEF from TECH/i3dPDK_NS3K_5T_mw.tf
  lef[_x<N>]/i3dPDK_NS3K_5T_tech_unidir.lef  same, M2-M4 preferred direction only,
                                              on track (flow ROUTE_UNIDIR=1)
  lef[_x<N>]/NS3K_5T_cells.lef               cell LEF with SITE lines, snapped
  i3dPDK_NS3K_streamOut.map

The tech section that BE/i3dPDK_NS3K_5T_0V7_27C.lef carries is not used:
its pitches disagree with the tf (M2 0.032 vs 0.024, M3 0.032 vs 0.022, M1
offset 0.016 with the pins centred at 0.022), and the tf is what the NDM is
built from. Cell-LEF fixes (in the A16K writer): NAND2_X1 repeats its VDD
rail in its M0 OBS (3142 M0 shorts with the followpins on tinyRocket), so
OBS inside a cell's own PG pin is dropped; the POLYGON pins/OBS are kept.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENAB = os.path.dirname(HERE)
ROOT = os.path.dirname(ENAB)
sys.path.insert(0, os.path.join(ROOT, "..", "i3dPDK_A16K", "innovus_enablement", "scripts"))
import gen_innovus_lef as g  # noqa: E402

# In the cell LEF but not in the liberty (no timing; INV_X32_3 is 4 rows
# high): left out.
EXCLUDE = {"INV_X16_2", "INV_X32_2", "INV_X32_3"}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dbu", type=int, default=2000)
    ap.add_argument("--scale", type=int, default=1,
                    help="geometry scale; output goes to lef_x<N>/ when N>1 (the flow uses 4)")
    args = ap.parse_args()
    g.S = args.scale
    g.PDK_NAME = "i3dPDK_NS3K v1.1"
    lefdir = os.path.join(ENAB, "lef" if g.S == 1 else f"lef_x{g.S}")
    os.makedirs(lefdir, exist_ok=True)
    rel = lambda p: os.path.relpath(p, ROOT)

    tf = os.path.join(ROOT, "TECH", "i3dPDK_NS3K_5T_mw.tf")
    dst = os.path.join(lefdir, "i3dPDK_NS3K_5T_tech.lef")
    site, layers = g.write_tech_lef(dst, tf, 5, args.dbu)
    print(f"wrote {rel(dst)}")
    dst = os.path.join(lefdir, "i3dPDK_NS3K_5T_tech_unidir.lef")
    g.write_tech_lef(dst, tf, 5, args.dbu, unidir=True)
    print(f"wrote {rel(dst)}  (unidirectional: {' '.join(g.unidir_layers(layers))})")
    src = os.path.join(ROOT, "BE", "i3dPDK_NS3K_5T_0V7_27C.lef")
    dst = os.path.join(lefdir, "NS3K_5T_cells.lef")
    k, t, u = g.write_cell_lef(src, dst, site, args.dbu, float(g.parse_tf(tf)[0]["height"]), EXCLUDE)
    print(f"wrote {rel(dst)}  ({k} RECTs snapped)")
    mp = os.path.join(ENAB, "i3dPDK_NS3K_streamOut.map")
    g.write_map(mp, layers)
    print(f"wrote {rel(mp)}")


if __name__ == "__main__":
    main()
