#!/usr/bin/env python3
"""Synthetic netlist of N copies of one standard cell, without IO ports, for placement/routing experiments.

Every input pin is driven by the output of another instance (random, fixed seed), each output drives as
many inputs as a cell has (so every net has 1 driver + k loads; the netlist has combinational loops, no
clock). Writes the netlist where both P&R flows read it and a design config:
    syn/out/<design>/<LIB>/<design>.v,  syn/designs/<design>.tcl (CLK_PORT "", UTIL)

    gen_cell_array.py [--cell AOI21_X1] [--n 300] [--util 0.8] [--seed 1] [--lib NS3K_5T] [--design aoi300]
"""
import argparse
import os
import random
import re

enab = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
ap = argparse.ArgumentParser()
ap.add_argument('--cell', default='AOI21_X1')
ap.add_argument('--n', type=int, default=300)
ap.add_argument('--util', type=float, default=0.8)
ap.add_argument('--seed', type=int, default=1)
ap.add_argument('--lib', default='NS3K_5T')
ap.add_argument('--design')
a = ap.parse_args()
design = a.design or '%s_n%d' % (a.cell.lower(), a.n)

# signal pins of the cell from the 1x cell LEF: output = DIRECTION OUTPUT
lef = open(os.path.join(enab, 'lef', '%s_cells.lef' % a.lib)).read()
body = re.search(r'\nMACRO %s\b(.*?)\nEND %s' % (a.cell, a.cell), lef, re.S).group(1)
ins, outs = [], []
for p in re.finditer(r'\n\s*PIN (\S+)(.*?)\n\s*END \1', body, re.S):
    if re.search(r'USE (POWER|GROUND)', p.group(2)):
        continue
    (outs if 'DIRECTION OUTPUT' in p.group(2) else ins).append(p.group(1))
assert len(outs) == 1, (a.cell, outs)
out, k = outs[0], len(ins)

# input slot (i, pin) -> driving instance: each instance drives exactly k slots, never its own
rnd = random.Random(a.seed)
drv = [j for j in range(a.n) for _ in range(k)]
while True:
    rnd.shuffle(drv)
    if all(drv[s] != s // k for s in range(len(drv))):
        break
    # repair self-loops by swapping with a random other slot
    for s in range(len(drv)):
        if drv[s] == s // k:
            t = rnd.randrange(len(drv))
            drv[s], drv[t] = drv[t], drv[s]
    if all(drv[s] != s // k for s in range(len(drv))):
        break

od = os.path.join(enab, 'syn', 'out', design, a.lib)
os.makedirs(od, exist_ok=True)
with open(os.path.join(od, design + '.v'), 'w') as f:
    f.write('// %d x %s, no IO (gen_cell_array.py --cell %s --n %d --seed %d)\n' % (a.n, a.cell, a.cell, a.n, a.seed))
    f.write('module %s ();\n' % design)
    f.write('  wire %s;\n' % ', '.join('n%d' % i for i in range(a.n)))
    for i in range(a.n):
        conns = ['.%s(n%d)' % (p, drv[i * k + q]) for q, p in enumerate(ins)] + ['.%s(n%d)' % (out, i)]
        f.write('  %s u%d (%s);\n' % (a.cell, i, ', '.join(conns)))
    f.write('endmodule\n')
with open(os.path.join(enab, 'syn', 'designs', design + '.tcl'), 'w') as f:
    f.write('# %d x %s without IO (scripts/gen_cell_array.py; no RTL, no synthesis: the netlist is written directly)\n'
            % (a.n, a.cell))
    f.write('set DESIGN_TOP    %s\nset RTL_FILES     {}\nset CLK_PORT      ""\nset CLK_PERIOD_NS 1.0\nset UTIL          %g\n'
            % (design, a.util))
print('%s: %d x %s (inputs %s, output %s) -> %s' % (design, a.n, a.cell, ' '.join(ins), out, od))
