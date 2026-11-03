#!/usr/bin/env python3
"""ICC2 technology file for i3dPDK_NS3K: TECH/i3dPDK_NS3K_<N>T_mw.tf with its
via definitions put on the 1 nm grid.

    fix_tf.py <src.tf> <dst.tf>

At the native geometry (1 nm grid) a via whose cut or landing pad is an odd
number of nm wide, centred on a track (whole nm), has its edges on half nm:
check_routes flags every such via "Off minimum grid" (dynamic_node: 103 on
M7, from VIA78's 0.031 cut + 0.001 enclosure). Some cuts also disagree with
their cut layer (VIA78 0.031 vs VIA7 width 0.030, VIA1112 0.053 vs VIA11
0.054). The Innovus flow never saw this: at 4x every size is on the grid.

For every ContactCode the cut becomes its cut layer's defaultWidth rounded up
to an even nm (VIA78 0.030: an M7 pad of 0.032 keeps the 0.032 spacing at the
0.064 pitch), and each enclosure is raised where needed so the pad is at least
the metal's minWidth; odd cut-layer defaultWidths are rounded up to even nm
(minWidth is left as is). Everything else is copied unchanged.
"""
import math
import re
import sys


def nm(v):
    return int(round(float(v) * 1000))


def um(n):
    return f"{n / 1000:.3f}"


def main():
    src, dst = sys.argv[1:3]
    text = open(src).read()
    blocks = list(re.finditer(r'^(Layer|ContactCode)\s+"([^"]+)"\s*\{(.*?)^\}', text, re.S | re.M))
    attr = lambda body, k: (re.search(rf"^\s*{k}\s*=\s*(\S+)", body, re.M) or [None, None])[1]
    layers = {m.group(2): m.group(3) for m in blocks if m.group(1) == "Layer"}
    lw = {n: nm(attr(b, "minWidth")) for n, b in layers.items() if attr(b, "minWidth")}
    ldw = {n: nm(attr(b, "defaultWidth")) for n, b in layers.items() if attr(b, "defaultWidth")}
    out = []
    pos = 0
    log = []
    for m in blocks:
        kind, name, body = m.groups()
        new = body
        if kind == "Layer" and name.upper().startswith("VIA") and name in ldw and ldw[name] % 2:
            new = re.sub(r"(^\s*defaultWidth\s*=\s*)\S+", lambda x: x.group(1) + um(ldw[name] + 1), new, flags=re.M)
            log.append(f"Layer {name}: defaultWidth {um(ldw[name])} -> {um(ldw[name] + 1)}")
        if kind == "ContactCode":
            cut_l, lo_l, up_l = (attr(body, k).strip('"') for k in ("cutLayer", "lowerLayer", "upperLayer"))
            cw = ldw.get(cut_l) or nm(attr(body, "cutWidth"))
            ch = ldw.get(cut_l) or nm(attr(body, "cutHeight"))
            cw += cw % 2
            ch += ch % 2
            vals = {"cutWidth": cw, "cutHeight": ch}
            for side, ml in (("lower", lo_l), ("upper", up_l)):
                for d, c in (("Width", cw), ("Height", ch)):
                    k = f"{side}LayerEnc{d}"
                    e = nm(attr(body, k))
                    e = max(e, math.ceil((lw.get(ml, 0) - c) / 2))
                    vals[k] = e
            for k, v in vals.items():
                old = nm(attr(body, k))
                if old != v:
                    new = re.sub(rf"(^\s*{k}\s*=\s*)\S+", lambda x: x.group(1) + um(v), new, flags=re.M)
                    log.append(f"ContactCode {name}: {k} {um(old)} -> {um(v)}")
        out.append(text[pos:m.start(3)])
        out.append(new)
        pos = m.end(3)
    out.append(text[pos:])
    open(dst, "w").write("".join(out))
    print("\n".join(log))
    print(f"wrote {dst} ({len(log)} changes)")


if __name__ == "__main__":
    main()
