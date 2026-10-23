import sys, hashlib

def read_ips(path):
    d = open(path, 'rb').read()
    assert d[:5] == b'PATCH', 'not IPS'
    i = 5
    recs = []
    while True:
        off = int.from_bytes(d[i:i+3], 'big'); i += 3
        if d[i-3:i] == b'EOF':
            break
        size = int.from_bytes(d[i:i+2], 'big'); i += 2
        if size == 0:
            rle = int.from_bytes(d[i:i+2], 'big'); i += 2
            recs.append((off, bytes([d[i]]) * rle, True)); i += 1
        else:
            recs.append((off, d[i:i+size], False)); i += size
    trunc = int.from_bytes(d[i:i+3], 'big') if len(d) >= i + 3 else None
    return recs, trunc

if __name__ == '__main__':
    recs, trunc = read_ips(sys.argv[1])
    rom = open(sys.argv[2], 'rb').read() if len(sys.argv) > 2 else None
    total = sum(len(r[1]) for r in recs)
    print(f'{len(recs)} records, {total} bytes, truncate={trunc}')
    for off, data, rle in recs:
        bank = 0xC0 + (off >> 16)
        orig = rom[off:off+len(data)] if rom and off + len(data) <= len(rom) else b''
        print(f'{off:06X} {bank:02X}:{off & 0xFFFF:04X} len={len(data):5d}{" RLE" if rle else ""} '
              f'new={data[:12].hex()} old={orig[:12].hex()}')
