"""Find store instructions to an absolute address (STA/STX/STY/STZ abs and long)."""
import sys

rom = open(sys.argv[1], 'rb').read()
target = int(sys.argv[2], 16)
lo, hi = target & 0xFF, target >> 8
for i in range(len(rom) - 3):
    op = rom[i]
    if op in (0x8D, 0x8E, 0x8C, 0x9C, 0x9D, 0x99, 0x9E) and rom[i + 1] == lo and rom[i + 2] == hi:
        print(f'{0xC0 + (i >> 16):02X}:{i & 0xFFFF:04X} {rom[i:i + 3].hex()}')
    if op in (0x8F, 0x9F) and rom[i + 1] == lo and rom[i + 2] == hi and rom[i + 3] in (0x00, 0x80):
        print(f'{0xC0 + (i >> 16):02X}:{i & 0xFFFF:04X} {rom[i:i + 4].hex()} (long)')
