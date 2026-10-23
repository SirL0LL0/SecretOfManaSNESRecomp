"""US ROM + donor's expanded area + donor header + donor bytes in the given banks.

Optional address ranges instead of banks: 0x12000-0x13000 (file offsets).
"""
import sys

us = open(sys.argv[1], 'rb').read()
donor = open(sys.argv[2], 'rb').read()
outdir = sys.argv[3]
for spec in sys.argv[4:]:
    out = bytearray(donor[:len(donor)])
    out[:len(us)] = us
    out[0xFFC0:0xFFE0] = donor[0xFFC0:0xFFE0]
    ranges = []
    for part in spec.split('+'):
        if '-' in part:
            a, b = part.split('-')
            ranges.append((int(a, 16), int(b, 16)))
        else:
            bank = int(part, 16) - 0xC0
            ranges.append((bank << 16, (bank + 1) << 16))
    n = 0
    for a, b in ranges:
        for i in range(a, min(b, len(us))):
            if donor[i] != us[i]:
                out[i] = donor[i]
                n += 1
    name = spec.replace('+', '_')
    open(f'{outdir}/w_{name}.sfc', 'wb').write(out)
    print(name, n)
