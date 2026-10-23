"""Compare a file-offset block across ROMs; report the common prefix and where it ends."""
import sys

off = int(sys.argv[1], 16)
n = int(sys.argv[2], 16)
roms = [(p.split('=', 1)[0], open(p.split('=', 1)[1], 'rb').read()) for p in sys.argv[3:]]
blocks = [(name, rom[off:off + n]) for name, rom in roms]
for name, b in blocks:
    nz = len(b.rstrip(b'\xff').rstrip(b'\x00'))
    print(f'{name}: len={len(b)} used~{nz} head={b[:16].hex(" ")}')
ref = blocks[0][1]
for name, b in blocks[1:]:
    same = 0
    while same < min(len(ref), len(b)) and ref[same] == b[same]:
        same += 1
    print(f'{blocks[0][0]} vs {name}: identical first {same:#x} bytes')
