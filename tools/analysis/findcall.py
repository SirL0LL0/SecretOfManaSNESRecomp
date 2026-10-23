"""Find JSR/JMP abs (same bank) and JSL/JML long to a target (HiROM, C0-FF)."""
import sys

rom = open(sys.argv[1], 'rb').read()
t = int(sys.argv[2], 16)
bank, addr = t >> 16, t & 0xFFFF
lo, hi = addr & 0xFF, addr >> 8
for i in range(len(rom) - 3):
    op = rom[i]
    if op in (0x20, 0x4C) and rom[i + 1] == lo and rom[i + 2] == hi and (0xC0 + (i >> 16)) == bank:
        print(f'{0xC0 + (i >> 16):02X}:{i & 0xFFFF:04X} {"JSR" if op == 0x20 else "JMP"}')
    if op in (0x22, 0x5C) and rom[i + 1] == lo and rom[i + 2] == hi and rom[i + 3] in (bank, bank & 0x3F):
        print(f'{0xC0 + (i >> 16):02X}:{i & 0xFFFF:04X} {"JSL" if op == 0x22 else "JML"}')
for i in range(len(rom) - 1):  # pointer tables (16-bit) in the same bank
    pass
