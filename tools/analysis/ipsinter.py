"""Bytes that two IPS patches change identically on the same base ROM, grouped in runs."""
import sys
from ipsdump import read_ips

def apply(rom, recs):
    out = bytearray(rom)
    for off, data, _ in recs:
        end = off + len(data)
        if end > len(out):
            out.extend(b'\0' * (end - len(out)))
        out[off:end] = data
    return bytes(out)

base = open(sys.argv[1], 'rb').read()
a = apply(base, read_ips(sys.argv[2])[0])
b = apply(base, read_ips(sys.argv[3])[0])
n = min(len(base), len(a), len(b))
runs = []
start = None
for i in range(n):
    same = a[i] != base[i] and a[i] == b[i]
    if same and start is None:
        start = i
    elif not same and start is not None:
        runs.append((start, i)); start = None
if start is not None:
    runs.append((start, n))
# merge runs closer than 16 bytes
merged = []
for s, e in runs:
    if merged and s - merged[-1][1] < 16:
        merged[-1] = (merged[-1][0], e)
    else:
        merged.append((s, e))
total = sum(e - s for s, e in runs)
print(f'{len(runs)} runs, {total} identical changed bytes, {len(merged)} regions')
for s, e in merged:
    print(f'{s:06X}-{e:06X} {0xC0 + (s >> 16):02X}:{s & 0xFFFF:04X} len={e - s}')
