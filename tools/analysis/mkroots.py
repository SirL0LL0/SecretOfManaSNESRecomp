import json, glob, os, collections, sys
r, sc = sys.argv[1], sys.argv[2]
m = json.load(open(os.path.join(r, 'generated', 'program_manifest.json')))
names = {}
for f in glob.glob(os.path.join(sc, 'cfg_it20', 'bank*.cfg')):
    bank = int(os.path.basename(f)[4:6], 16)
    for line in open(f):
        t = line.split()
        if len(t) >= 3 and t[0] == 'func':
            a = int(t[2], 16); pc = a if a > 0xFFFF else (bank << 16 | a)
            names.setdefault(pc, t[1])
by = collections.OrderedDict()
for x in m['roots']:
    by.setdefault(x['pc24'], []).append((x['m'], x['x']))
out = ['# AOT roots of the program generated from the Italian v2.0 image',
       '# (generated/program_manifest.json), so a regeneration compiles the same set.', '']
skipped = []
for pc, mx in by.items():
    if len(mx) != 1 or pc not in names:
        skipped.append('%06X' % pc); continue
    mm, xx = mx[0]
    out += ['[[func]]', 'name = "%s"' % names[pc], 'bank = 0x%02X' % (pc >> 16),
            'addr = "%04X"' % (pc & 0xFFFF), 'emit = true',
            'entry_m = %d' % mm, 'entry_x = %d' % xx, '']
open(os.path.join(sc, 'aot_roots.toml'), 'w').write('\n'.join(out))
print(out.count('[[func]]'), 'funcs; skipped', skipped)
ram = [pc for pc in by if (pc >> 16) == 0 and (pc & 0xFFFF) < 0x8000]
print('WRAM roots', len(ram), ['%06X' % p for p in ram][:12])
