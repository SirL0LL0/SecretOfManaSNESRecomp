"""Per-tile (32-byte, 4bpp) diff of a VRAM word range; and search the reference tiles in the other dump."""
import sys

a = open(sys.argv[1], 'rb').read()  # reference (Mesen)
b = open(sys.argv[2], 'rb').read()  # recomp
lo, hi = int(sys.argv[3], 16) * 2, int(sys.argv[4], 16) * 2
zero_a = zero_b = 0
moved = 0
rows = []
for t in range(lo, hi, 32):
    ta, tb = a[t:t + 32], b[t:t + 32]
    if ta == tb:
        continue
    zero_a += ta == bytes(32)
    zero_b += tb == bytes(32)
    where = b.find(ta) if ta != bytes(32) else -1
    moved += where >= 0
    rows.append(f'tile@{t // 2:04X} ref={ta[:8].hex()} rec={tb[:8].hex()} ref-found-in-rec@{where // 2 if where >= 0 else -1:X}')
print(f'{len(rows)} tiles differ; ref zero={zero_a} rec zero={zero_b}; ref tile present elsewhere in rec={moved}')
print('\n'.join(rows[:25]))
