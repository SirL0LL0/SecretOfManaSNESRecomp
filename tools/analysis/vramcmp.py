"""Compare two VRAM dumps by 1 KB region, and BG tilemaps entry by entry."""
import sys

a = open(sys.argv[1], 'rb').read()
b = open(sys.argv[2], 'rb').read()
print('1KB regions with differences (word address):')
for r in range(0, 0x10000, 0x400):
    d = sum(1 for i in range(r, r + 0x400) if a[i] != b[i])
    if d:
        print(f'  word {r // 2:04X}-{(r + 0x400) // 2 - 1:04X}: {d} bytes differ')
# tilemaps: BG1 at word 5000, BG2 at word 3800 (64x32 each = 2 KB*2)
for name, word in (('BG1', 0x5000), ('BG2', 0x3800), ('BG3', 0x5800)):
    base = word * 2
    diff = [(i // 2) for i in range(base, base + 0x1000, 2) if a[i:i + 2] != b[i:i + 2]]
    print(f'{name} map @{word:04X}: {len(diff)} entries differ', [f'{(base // 2 + k):04X}' for k in diff[:12]])
