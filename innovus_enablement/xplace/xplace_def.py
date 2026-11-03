#!/usr/bin/env python3
"""DEF glue between the Innovus flow and Xplace (standard library only).

  xplace_def.py prep <in.def> <out.def>
      Xplace input: the floorplan + netlist DEF that xplace_place.tcl writes,
      plus a hard placement blockage wherever the core has no single-height
      row. The flow cuts the rows under every macro halo, in pockets narrower
      than MACRO_CHANNEL_UM and under the halo M9 stripes; Innovus never puts
      a cell there, but Xplace's density model only knows the core box, fixed
      cells and placement blockages, so without these it spreads cells into
      the halos. (Blockages over a macro are harmless: fixed density is
      clamped to 1 per bin.) Also the input of DREAMPlace (run_dreamplace_gp.sh).

  xplace_def.py rows1h <in.def> <out.def>
      <in.def> without the multi-height rows (<site>_<N>H_<VDD|VSS>), for the
      standalone RePlAce (run_replace_gp.sh), which takes the site of one of
      them for the row height and rejects every single-height cell. No
      blockages: RePlAce fills the row-free core itself (dummy terminals), and
      adds blockages to the fixed area without taking out their overlap with
      the macros.

  xplace_def.py gp <in.def> <xplace.def> <out.def>
      The COMPONENTS-only DEF that xplace_place.tcl loads with defIn: every
      component that is unplaced in <in.def> (the standard cells) PLACED at
      its location in Xplace's global placement <xplace.def>. Orientation is
      N throughout: Xplace places orientation-free, and refinePlace flips each
      cell to its row.
"""
import re
import sys


def statements(lines):
    """Yield DEF statements (tokens up to ';') of a section body."""
    buf = []
    for line in lines:
        for tok in line.split():
            if tok == ';':
                if buf:
                    yield buf
                buf = []
            else:
                buf.append(tok)
    if buf:
        yield buf


def read_def(path):
    with open(path) as fh:
        return fh.read().splitlines()


def section(lines, name):
    """(start, end) line indexes of '<name> n ;' .. 'END <name>', or None."""
    start = None
    for i, line in enumerate(lines):
        t = line.split()
        if not t:
            continue
        if start is None and t[0] == name:
            start = i
        elif start is not None and t[0] == 'END' and len(t) > 1 and t[1] == name:
            return start, i
    return None


def components(lines):
    """name -> (master, status, x, y) for every component."""
    sec = section(lines, 'COMPONENTS')
    if sec is None:
        raise SystemExit('no COMPONENTS section')
    s, e = sec
    comps = {}
    for st in statements(lines[s + 1:e]):
        if st[0] != '-':
            continue
        name, master = st[1], st[2]
        status, x, y = 'UNPLACED', None, None
        for i, tok in enumerate(st):
            if tok in ('PLACED', 'FIXED', 'COVER') and i + 4 < len(st) and st[i + 1] == '(':
                status, x, y = tok, int(st[i + 2]), int(st[i + 3])
            elif tok == 'UNPLACED':
                status = 'UNPLACED'
        comps[name] = (master, status, x, y)
    return comps


def row_gaps(lines):
    """Rectangles of the row area that no single-height row covers."""
    rows = []
    for line in lines:
        t = line.split()
        if not t or t[0] != 'ROW':
            continue
        # ROW name site x y orient DO nx BY ny STEP sx sy ;
        site, x, y = t[2], int(t[3]), int(t[4])
        nx, ny = int(t[7]), int(t[9])
        sx = int(t[11]) if len(t) > 11 else 0
        rows.append((site, x, y, nx, ny, sx))
    if not rows:
        raise SystemExit('no ROW statements')
    # Multi-height rows (<site>_<N>H_<VDD|VSS>) lie on top of the single-height
    # ones and add no area.
    single = [r for r in rows if not re.search(r'_\d+H_(VDD|VSS)$', r[0])]
    ys = sorted({r[2] for r in single})
    h = min(b - a for a, b in zip(ys, ys[1:])) if len(ys) > 1 else None
    if h is None:
        raise SystemExit('cannot infer the row height from a single row')
    x_lo = min(r[1] for r in rows)
    x_hi = max(r[1] + r[3] * r[5] for r in rows)
    y_lo = min(r[2] for r in rows)
    y_hi = max(r[2] for r in single) + h
    bands = {}
    for site, x, y, nx, ny, sx in single:
        if ny != 1:
            raise SystemExit('ROW %s: only horizontal rows (BY 1) are supported' % site)
        bands.setdefault(y, []).append((x, x + nx * sx))
    rects = []
    open_ = {}  # (gx1, gx2) -> start y of a gap that continues upwards
    for y in range(y_lo, y_hi, h):
        cov = sorted(bands.get(y, []))
        gaps = []
        cur = x_lo
        for a, b in cov:
            if a > cur:
                gaps.append((cur, a))
            cur = max(cur, b)
        if cur < x_hi:
            gaps.append((cur, x_hi))
        gaps = set(gaps)
        for g in list(open_):
            if g not in gaps:
                rects.append((g[0], open_.pop(g), g[1], y))
        for g in gaps:
            open_.setdefault(g, y)
    for g, y0 in open_.items():
        rects.append((g[0], y0, g[1], y_hi))
    return sorted(rects, key=lambda r: (r[1], r[0]))


def drop_multi_rows(lines):
    """lines without the multi-height ROW statements (a ROW statement can end on a later line)."""
    out, skip = [], False
    for line in lines:
        t = line.split()
        if not skip and t[:1] == ['ROW'] and len(t) > 2 and re.search(r'_\d+H_(VDD|VSS)$', t[2]):
            skip = True
        if skip:
            skip = ';' not in t
            continue
        out.append(line)
    return out


def rows1h(in_def, out_def):
    lines = read_def(in_def)
    out = drop_multi_rows(lines)
    with open(out_def, 'w') as fh:
        fh.write('\n'.join(out) + '\n')
    print('xplace_def rows1h: %d of %d ROWs kept -> %s'
          % (sum(l.split()[:1] == ['ROW'] for l in out), sum(l.split()[:1] == ['ROW'] for l in lines), out_def))


def prep(in_def, out_def):
    lines = read_def(in_def)
    rects = row_gaps(lines)
    new = ['   - PLACEMENT RECT ( %d %d ) ( %d %d ) ;' % r for r in rects]
    sec = section(lines, 'BLOCKAGES')
    if sec is not None:
        s, e = sec
        n = int(lines[s].split()[1]) + len(new)
        out = lines[:s] + ['BLOCKAGES %d ;' % n] + lines[s + 1:e] + new + lines[e:]
    else:
        at = next((i for i, l in enumerate(lines)
                   if l.split()[:1] in (['SPECIALNETS'], ['NETS'], ['END'])
                   and (l.split()[:1] != ['END'] or l.split()[1:2] == ['DESIGN'])), None)
        if at is None:
            raise SystemExit('no place for a BLOCKAGES section')
        out = lines[:at] + ['BLOCKAGES %d ;' % len(new)] + new + ['END BLOCKAGES', ''] + lines[at:]
    with open(out_def, 'w') as fh:
        fh.write('\n'.join(out) + '\n')
    area = sum((r[2] - r[0]) * (r[3] - r[1]) for r in rects)
    print('xplace_def prep: %d row-free blockages (%.4g um^2 at DEF scale) -> %s'
          % (len(rects), area / float(dbu(lines)) ** 2, out_def))


def dbu(lines):
    for line in lines:
        t = line.split()
        if t[:3] == ['UNITS', 'DISTANCE', 'MICRONS']:
            return int(t[3])
    raise SystemExit('no UNITS DISTANCE MICRONS')


def gp(in_def, xplace_def, out_def):
    lines = read_def(in_def)
    orig = components(lines)
    placed = components(read_def(xplace_def))
    todo = [n for n, c in orig.items() if c[1] == 'UNPLACED']
    missing = [n for n in todo if n not in placed or placed[n][1] != 'PLACED']
    if missing:
        raise SystemExit('xplace_def gp: %d of %d cells not placed by Xplace (e.g. %s)'
                         % (len(missing), len(todo), missing[0]))
    design = next(l.split()[1] for l in lines if l.split()[:1] == ['DESIGN'])
    out = ['VERSION 5.8 ;', 'DIVIDERCHAR "/" ;', 'BUSBITCHARS "[]" ;',
           'DESIGN %s ;' % design, 'UNITS DISTANCE MICRONS %d ;' % dbu(lines), '',
           'COMPONENTS %d ;' % len(todo)]
    for n in todo:
        _, _, x, y = placed[n]
        out.append('- %s %s + PLACED ( %d %d ) N ;' % (n, orig[n][0], x, y))
    out += ['END COMPONENTS', '', 'END DESIGN']
    with open(out_def, 'w') as fh:
        fh.write('\n'.join(out) + '\n')
    print('xplace_def gp: %d standard cells -> %s' % (len(todo), out_def))


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == 'prep':
        prep(*sys.argv[2:])
    elif len(sys.argv) == 4 and sys.argv[1] == 'rows1h':
        rows1h(*sys.argv[2:])
    elif len(sys.argv) == 5 and sys.argv[1] == 'gp':
        gp(*sys.argv[2:])
    else:
        sys.exit(__doc__)
