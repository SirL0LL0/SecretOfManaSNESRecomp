"""Minimal 65816 disassembler: dis65.py rom.sfc C1:4CE0 [count] [m=1] [x=1]  (HiROM)."""
import sys

# mode codes: imp, imm8, immM, immX, dp, dpx, dpy, dpi, dpix, dpiy, dpil, dpily, abs, absx, absy,
# absl, abslx, absi, absix, absil, rel, rell, sr, sriy, mv, acc
T = {}
def op(code, name, mode):
    T[code] = (name, mode)

ALU = ['ORA', 'AND', 'EOR', 'ADC', 'STA', 'LDA', 'CMP', 'SBC']
for i, n in enumerate(ALU):
    b = i * 0x20
    op(b + 0x01, n, 'dpix'); op(b + 0x03, n, 'sr'); op(b + 0x05, n, 'dp'); op(b + 0x07, n, 'dpil')
    if n != 'STA':
        op(b + 0x09, n, 'immM')
    op(b + 0x0D, n, 'abs'); op(b + 0x0F, n, 'absl'); op(b + 0x11, n, 'dpiy'); op(b + 0x12, n, 'dpi')
    op(b + 0x13, n, 'sriy'); op(b + 0x15, n, 'dpx'); op(b + 0x17, n, 'dpily'); op(b + 0x19, n, 'absy')
    op(b + 0x1D, n, 'absx'); op(b + 0x1F, n, 'abslx')
op(0x89, 'BIT', 'immM')
extra = {
    0x00: ('BRK', 'imm8'), 0x02: ('COP', 'imm8'), 0x04: ('TSB', 'dp'), 0x06: ('ASL', 'dp'), 0x08: ('PHP', 'imp'),
    0x0A: ('ASL', 'acc'), 0x0B: ('PHD', 'imp'), 0x0C: ('TSB', 'abs'), 0x0E: ('ASL', 'abs'), 0x10: ('BPL', 'rel'),
    0x14: ('TRB', 'dp'), 0x16: ('ASL', 'dpx'), 0x18: ('CLC', 'imp'), 0x1A: ('INC', 'acc'), 0x1B: ('TCS', 'imp'),
    0x1C: ('TRB', 'abs'), 0x1E: ('ASL', 'absx'), 0x20: ('JSR', 'abs'), 0x22: ('JSL', 'absl'), 0x24: ('BIT', 'dp'),
    0x26: ('ROL', 'dp'), 0x28: ('PLP', 'imp'), 0x2A: ('ROL', 'acc'), 0x2B: ('PLD', 'imp'), 0x2C: ('BIT', 'abs'),
    0x2E: ('ROL', 'abs'), 0x30: ('BMI', 'rel'), 0x34: ('BIT', 'dpx'), 0x36: ('ROL', 'dpx'), 0x38: ('SEC', 'imp'),
    0x3A: ('DEC', 'acc'), 0x3B: ('TSC', 'imp'), 0x3C: ('BIT', 'absx'), 0x3E: ('ROL', 'absx'), 0x40: ('RTI', 'imp'),
    0x42: ('WDM', 'imm8'), 0x44: ('MVP', 'mv'), 0x46: ('LSR', 'dp'), 0x48: ('PHA', 'imp'), 0x4A: ('LSR', 'acc'),
    0x4B: ('PHK', 'imp'), 0x4C: ('JMP', 'abs'), 0x4E: ('LSR', 'abs'), 0x50: ('BVC', 'rel'), 0x54: ('MVN', 'mv'),
    0x56: ('LSR', 'dpx'), 0x58: ('CLI', 'imp'), 0x5A: ('PHY', 'imp'), 0x5B: ('TCD', 'imp'), 0x5C: ('JML', 'absl'),
    0x5E: ('LSR', 'absx'), 0x60: ('RTS', 'imp'), 0x62: ('PER', 'rell'), 0x64: ('STZ', 'dp'), 0x66: ('ROR', 'dp'),
    0x68: ('PLA', 'imp'), 0x6A: ('ROR', 'acc'), 0x6B: ('RTL', 'imp'), 0x6C: ('JMP', 'absi'), 0x6E: ('ROR', 'abs'),
    0x70: ('BVS', 'rel'), 0x74: ('STZ', 'dpx'), 0x76: ('ROR', 'dpx'), 0x78: ('SEI', 'imp'), 0x7A: ('PLY', 'imp'),
    0x7B: ('TDC', 'imp'), 0x7C: ('JMP', 'absix'), 0x7E: ('ROR', 'absx'), 0x80: ('BRA', 'rel'), 0x82: ('BRL', 'rell'),
    0x84: ('STY', 'dp'), 0x86: ('STX', 'dp'), 0x88: ('DEY', 'imp'), 0x8A: ('TXA', 'imp'), 0x8B: ('PHB', 'imp'),
    0x8C: ('STY', 'abs'), 0x8E: ('STX', 'abs'), 0x90: ('BCC', 'rel'), 0x94: ('STY', 'dpx'), 0x96: ('STX', 'dpy'),
    0x98: ('TYA', 'imp'), 0x9A: ('TXS', 'imp'), 0x9B: ('TXY', 'imp'), 0x9C: ('STZ', 'abs'), 0x9E: ('STZ', 'absx'),
    0xA0: ('LDY', 'immX'), 0xA2: ('LDX', 'immX'), 0xA4: ('LDY', 'dp'), 0xA6: ('LDX', 'dp'), 0xA8: ('TAY', 'imp'),
    0xAA: ('TAX', 'imp'), 0xAB: ('PLB', 'imp'), 0xAC: ('LDY', 'abs'), 0xAE: ('LDX', 'abs'), 0xB0: ('BCS', 'rel'),
    0xB4: ('LDY', 'dpx'), 0xB6: ('LDX', 'dpy'), 0xB8: ('CLV', 'imp'), 0xBA: ('TSX', 'imp'), 0xBB: ('TYX', 'imp'),
    0xBC: ('LDY', 'absx'), 0xBE: ('LDX', 'absy'), 0xC0: ('CPY', 'immX'), 0xC2: ('REP', 'imm8'), 0xC4: ('CPY', 'dp'),
    0xC6: ('DEC', 'dp'), 0xC8: ('INY', 'imp'), 0xCA: ('DEX', 'imp'), 0xCB: ('WAI', 'imp'), 0xCC: ('CPY', 'abs'),
    0xCE: ('DEC', 'abs'), 0xD0: ('BNE', 'rel'), 0xD4: ('PEI', 'dp'), 0xD6: ('DEC', 'dpx'), 0xD8: ('CLD', 'imp'),
    0xDA: ('PHX', 'imp'), 0xDB: ('STP', 'imp'), 0xDC: ('JML', 'absil'), 0xDE: ('DEC', 'absx'), 0xE0: ('CPX', 'immX'),
    0xE2: ('SEP', 'imm8'), 0xE4: ('CPX', 'dp'), 0xE6: ('INC', 'dp'), 0xE8: ('INX', 'imp'), 0xEA: ('NOP', 'imp'),
    0xEB: ('XBA', 'imp'), 0xEC: ('CPX', 'abs'), 0xEE: ('INC', 'abs'), 0xF0: ('BEQ', 'rel'), 0xF4: ('PEA', 'abs'),
    0xF6: ('INC', 'dpx'), 0xF8: ('SED', 'imp'), 0xFA: ('PLX', 'imp'), 0xFB: ('XCE', 'imp'), 0xFC: ('JSR', 'absix'),
    0xFE: ('INC', 'absx'),
}
for k, v in extra.items():
    T[k] = v
SIZE = {'imp': 0, 'acc': 0, 'imm8': 1, 'dp': 1, 'dpx': 1, 'dpy': 1, 'dpi': 1, 'dpix': 1, 'dpiy': 1, 'dpil': 1,
        'dpily': 1, 'sr': 1, 'sriy': 1, 'rel': 1, 'abs': 2, 'absx': 2, 'absy': 2, 'absi': 2, 'absix': 2,
        'absil': 2, 'rell': 2, 'mv': 2, 'absl': 3, 'abslx': 3}
FMT = {'imp': '', 'acc': 'A', 'dp': '${:02X}', 'dpx': '${:02X},X', 'dpy': '${:02X},Y', 'dpi': '(${:02X})',
       'dpix': '(${:02X},X)', 'dpiy': '(${:02X}),Y', 'dpil': '[${:02X}]', 'dpily': '[${:02X}],Y', 'sr': '${:02X},S',
       'sriy': '(${:02X},S),Y', 'abs': '${:04X}', 'absx': '${:04X},X', 'absy': '${:04X},Y', 'absi': '(${:04X})',
       'absix': '(${:04X},X)', 'absil': '[${:04X}]', 'absl': '${:06X}', 'abslx': '${:06X},X'}

def main():
    rom = open(sys.argv[1], 'rb').read()
    bank, addr = sys.argv[2].split(':')
    pc = (int(bank, 16) << 16) | int(addr, 16)
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    m = x = 1
    for a in sys.argv[4:]:
        k, v = a.split('=')
        if k == 'm': m = int(v)
        if k == 'x': x = int(v)
    for _ in range(count):
        off = pc & 0x3FFFFF
        o = rom[off]
        name, mode = T.get(o, ('???', 'imp'))
        if mode == 'immM':
            size = 1 if m else 2
        elif mode == 'immX':
            size = 1 if x else 2
        else:
            size = SIZE[mode]
        raw = rom[off:off + 1 + size]
        val = int.from_bytes(raw[1:], 'little') if size else 0
        if mode in ('immM', 'immX', 'imm8'):
            arg = f'#${val:0{size * 2}X}'
        elif mode == 'rel':
            arg = f'${(pc + 2 + (val - 256 if val > 127 else val)) & 0xFFFF:04X}'
        elif mode == 'rell':
            arg = f'${(pc + 3 + (val - 65536 if val > 32767 else val)) & 0xFFFF:04X}'
        elif mode == 'mv':
            arg = f'${raw[1]:02X},${raw[2]:02X}'
        else:
            arg = FMT[mode].format(val) if FMT[mode] else ''
        if name == 'REP':
            if val & 0x20: m = 0
            if val & 0x10: x = 0
        if name == 'SEP':
            if val & 0x20: m = 1
            if val & 0x10: x = 1
        print(f'{pc >> 16:02X}:{pc & 0xFFFF:04X}  {raw.hex(" "):12} {name} {arg}')
        pc = (pc & 0xFF0000) | ((pc + 1 + size) & 0xFFFF)

main()
