#!/usr/bin/env python3
"""Cell LEF for the ICC2 cell library (macros/build_ndm.sh), from the PDK's
BE/i3dPDK_NS3K_<N>T_0V7_27C.lef at its native geometry.

    fix_cell_lef.py <src.lef> <dst.lef>

Keeps the header and the MACROs only (the technology comes from the tf), and
fixes what the PDK's own NDM inherits from this LEF:
  - OBS shapes inside one of the cell's own PG pins on the same layer are
    dropped: NAND2_X1 repeats its VDD rail in its M0 OBS, which check_lvs
    reports as a short with the followpin and both neighbours at every
    instance (the same fix as innovus_enablement's cell LEF).
  - Cells without timing in the liberty are left out (INV_X16_2, INV_X32_2,
    INV_X32_3; the last is 4 rows high).
"""
import re
import sys

EXCLUDE = {"INV_X16_2", "INV_X32_2", "INV_X32_3"}
RECT = re.compile(r"\s*RECT\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*;")


def inside(r, pins):
    return any(p[0] <= r[0] + 1e-9 and p[1] <= r[1] + 1e-9 and
               r[2] <= p[2] + 1e-9 and r[3] <= p[3] + 1e-9 for p in pins)


def main():
    src, dst = sys.argv[1:3]
    lines = open(src).read().splitlines()
    out = []
    i = 0
    # header up to the first LAYER/SITE (tech section dropped)
    while i < len(lines) and not re.match(r"(LAYER|VIA|SITE|MACRO)\b", lines[i]):
        out.append(lines[i])
        i += 1
    dropped = kept = 0
    while i < len(lines):
        m = re.match(r"MACRO\s+(\S+)", lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        j = i
        while not re.match(rf"END\s+{re.escape(name)}\s*$", lines[j]):
            j += 1
        body = lines[i:j + 1]
        i = j + 1
        if name in EXCLUDE:
            continue
        # PG pin rects per layer
        pg = {}
        pin_use = None
        layer = None
        for ln in body:
            if re.match(r"\s*PIN\s", ln):
                pin_use = None
            u = re.match(r"\s*USE\s+(POWER|GROUND)\s*;", ln)
            if u:
                pin_use = u.group(1)
            lm = re.match(r"\s*LAYER\s+(\S+)", ln)
            if lm:
                layer = lm.group(1)
            if re.match(r"\s*OBS\b", ln):
                break
            r = RECT.match(ln)
            if r and pin_use:
                pg.setdefault(layer, []).append(tuple(float(v) for v in r.groups()))
        in_obs = False
        layer = None
        for ln in body:
            if re.match(r"\s*OBS\b", ln):
                in_obs = True
            elif in_obs and re.match(r"\s*END\s*$", ln):
                in_obs = False
            lm = re.match(r"\s*LAYER\s+(\S+)", ln)
            if lm:
                layer = lm.group(1)
            r = RECT.match(ln)
            if in_obs and r and inside(tuple(float(v) for v in r.groups()), pg.get(layer, [])):
                dropped += 1
                continue
            out.append(ln)
        out.append("")
        kept += 1
    out.append("END LIBRARY")
    open(dst, "w").write("\n".join(out) + "\n")
    print(f"{dst}: {kept} cells, {dropped} OBS rects inside PG pins dropped")


if __name__ == "__main__":
    main()
