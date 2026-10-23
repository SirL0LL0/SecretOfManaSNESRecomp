"""hexat.py name=rom ... -- off:len ...   (HiROM: C0:0000 = file 0; pass file offsets in hex)"""
import sys

sep = sys.argv.index('--')
roms = [(a.split('=', 1)[0], open(a.split('=', 1)[1], 'rb').read()) for a in sys.argv[1:sep]]
for spec in sys.argv[sep + 1:]:
    off, n = spec.split(':')
    off, n = int(off, 16), int(n)
    print(f'== {0xC0 + (off >> 16):02X}:{off & 0xFFFF:04X} ({off:06X})')
    for name, rom in roms:
        print(f'{name:3} {rom[off:off + n].hex(" ")}')
