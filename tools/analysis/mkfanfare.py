import sys, hashlib
rom_path, out = sys.argv[1], sys.argv[2]
rom = bytearray(open(rom_path, 'rb').read())
recs = [(0x09A6BD, b'\x2F', b'\x30'), (0x09B6D1, b'\x27\xC0', b'\x24\x01'),
        (0x0A0DE2, b'\x00' * 6, b'\x40\x01\x21\x0A\xFF\x02')]
ips = bytearray(b'PATCH')
for off, old, new in recs:
    assert rom[off:off+len(old)] == old, hex(off)
    rom[off:off+len(new)] = new
    ips += off.to_bytes(3, 'big') + len(new).to_bytes(2, 'big') + new
ips += b'EOF'
open(out, 'wb').write(ips)
print(len(rom), hashlib.sha256(rom).hexdigest())
