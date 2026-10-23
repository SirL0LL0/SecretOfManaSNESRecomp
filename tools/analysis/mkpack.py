import sys, struct, math, os
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
rate = 44100; secs = 2.0
for n in range(59):
    if n == 5: continue   # leave one track missing to exercise the SPC fallback
    f = 220.0 * 2 ** (n / 12.0)
    frames = int(rate * secs)
    body = bytearray()
    for i in range(frames):
        s = int(6000 * math.sin(2 * math.pi * f * i / rate))
        body += struct.pack('<hh', s, s)
    open(os.path.join(out, 'som_msu1-%d.pcm' % n), 'wb').write(b'MSU1' + struct.pack('<I', 0) + body)
print('ok')
