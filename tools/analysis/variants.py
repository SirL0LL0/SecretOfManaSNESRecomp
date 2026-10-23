"""US ROM + only the bytes of a donor image that fall in the given banks."""
import sys

us = open(sys.argv[1], 'rb').read()
donor = open(sys.argv[2], 'rb').read()
outdir = sys.argv[3]
for spec in sys.argv[4:]:
    banks = {int(b, 16) - 0xC0 for b in spec.split('+')}
    out = bytearray(us)
    n = 0
    for i in range(len(us)):
        if (i >> 16) in banks and donor[i] != us[i]:
            out[i] = donor[i]
            n += 1
    open(f'{outdir}/v_{spec.replace("+", "_")}.sfc', 'wb').write(out)
    print(spec, n)
