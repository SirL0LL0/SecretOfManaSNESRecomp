"""Base image + only the title-restoration bytes taken from a SoMPlus image."""
import sys

base = bytearray(open(sys.argv[1], 'rb').read())
donor = open(sys.argv[2], 'rb').read()
out = sys.argv[3]
RANGES = [(0x014CF7, 0x014CFA), (0x2FC000, 0x2FF8A0)]
if len(base) < 0x300000:
    base.extend(b'\0' * (0x300000 - len(base)))
for a, b in RANGES:
    base[a:b] = donor[a:b]
base[0xFFD7] = donor[0xFFD7]
open(out, 'wb').write(base)
print(out, len(base), f'header size byte {donor[0xFFD7]:#x}')
