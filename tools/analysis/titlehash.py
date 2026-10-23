"""SHA-256 of the title-restoration ranges of US+IPS, for each IPS given."""
import hashlib
import sys
from ipsdump import read_ips

RANGES = [(0x014CF7, 0x014CFA), (0x2FC000, 0x2FF8A0)]
us = open(sys.argv[1], 'rb').read()
for path in sys.argv[2:]:
    img = bytearray(us)
    for off, data, _ in read_ips(path)[0]:
        end = off + len(data)
        if end > len(img):
            img.extend(b'\0' * (end - len(img)))
        img[off:end] = data
    h = hashlib.sha256()
    for a, b in RANGES:
        h.update(bytes(img[a:b]))
    fh = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    print(h.hexdigest(), f'size={len(img):#x} hdr={img[0xFFD7]:#x}', path.split('\\')[-1], fh)
