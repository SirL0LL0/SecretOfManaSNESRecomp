"""Write base+IPS to an output file (tests only, in the scratchpad)."""
import sys
from ipsdump import read_ips

base = bytearray(open(sys.argv[1], 'rb').read())
for off, data, _ in read_ips(sys.argv[2])[0]:
    end = off + len(data)
    if end > len(base):
        base.extend(b'\0' * (end - len(base)))
    base[off:end] = data
open(sys.argv[3], 'wb').write(base)
print(len(base))
