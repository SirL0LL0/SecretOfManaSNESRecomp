"""Per-bank changed bytes of an IPS against a base ROM, and changed regions."""
import sys
from ipsdump import read_ips

base = open(sys.argv[1], 'rb').read()
recs = read_ips(sys.argv[2])[0]
out = bytearray(base)
for off, data, _ in recs:
    end = off + len(data)
    if end > len(out):
        out.extend(b'\0' * (end - len(out)))
    out[off:end] = data
min_len = int(sys.argv[3]) if len(sys.argv) > 3 else 64
changed = [i for i in range(len(out)) if i >= len(base) or out[i] != base[i]]
banks = {}
for i in changed:
    banks[i >> 16] = banks.get(i >> 16, 0) + 1
print(f'size {len(base)} -> {len(out)}, changed {len(changed)}')
for b in sorted(banks):
    print(f'  bank {0xC0 + b:02X}: {banks[b]}')
regions = []
for i in changed:
    if regions and i - regions[-1][1] <= 32:
        regions[-1][1] = i + 1
    else:
        regions.append([i, i + 1])
for s, e in regions:
    if e - s >= min_len:
        print(f'{s:06X}-{e:06X} {0xC0 + (s >> 16):02X}:{s & 0xFFFF:04X} len={e - s}')
