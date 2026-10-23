"""Bytes where two SoMPlus difficulty images differ (both applied to the US ROM)."""
import sys
from ipsdump import read_ips

def image(us, path):
    img = bytearray(us)
    for off, data, _ in read_ips(path)[0]:
        end = off + len(data)
        if end > len(img):
            img.extend(b'\0' * (end - len(img)))
        img[off:end] = data
    return img

us = open(sys.argv[1], 'rb').read()
a = image(us, sys.argv[2])
b = image(us, sys.argv[3])
n = min(len(a), len(b))
regions = []
for i in range(n):
    if a[i] != b[i]:
        if regions and i - regions[-1][1] <= 4:
            regions[-1][1] = i + 1
        else:
            regions.append([i, i + 1])
print(f'{len(regions)} regions')
for s, e in regions[:int(sys.argv[4]) if len(sys.argv) > 4 else 80]:
    lo = max(0, s - 4)
    print(f'{0xC0 + (s >> 16):02X}:{s & 0xFFFF:04X} len={e - s:3d} US={us[lo:e + 2].hex() if e + 2 <= len(us) else "-"} '
          f'A={a[lo:e + 2].hex()} B={b[lo:e + 2].hex()}')
