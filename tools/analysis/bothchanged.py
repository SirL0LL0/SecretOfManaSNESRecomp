"""Regions of the base ROM that two patched images both change (values may differ)."""
import sys

base = open(sys.argv[1], 'rb').read()
a = open(sys.argv[2], 'rb').read()
b = open(sys.argv[3], 'rb').read()
skip_banks = {int(x, 16) for x in sys.argv[4].split(',')} if len(sys.argv) > 4 else set()
regions = []
for i in range(len(base)):
    if (0xC0 + (i >> 16)) in skip_banks:
        continue
    if a[i] != base[i] and b[i] != base[i]:
        if regions and i - regions[-1][1] <= 8:
            regions[-1][1] = i + 1
        else:
            regions.append([i, i + 1])
for s, e in regions:
    same = sum(1 for i in range(s, e) if a[i] == b[i])
    print(f'{0xC0 + (s >> 16):02X}:{s & 0xFFFF:04X} len={e - s:4d} same={same:4d} '
          f'US={base[s:min(e, s + 10)].hex()} A={a[s:min(e, s + 10)].hex()} B={b[s:min(e, s + 10)].hex()}')
