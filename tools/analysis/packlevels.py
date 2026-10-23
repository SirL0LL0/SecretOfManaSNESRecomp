"""Peak and RMS (dBFS) of every track of an MSU-1 pack."""
import array
import glob
import math
import os
import re
import sys

rows = []
for path in glob.glob(os.path.join(sys.argv[1], '*.pcm')):
    n = int(re.search(r'-(\d+)\.pcm$', path).group(1))
    data = open(path, 'rb').read()[8:]
    s = array.array('h', data[:len(data) // 2 * 2])
    if not s:
        continue
    peak = max(max(s), -min(s))
    step = 7
    sq = sum(x * x for x in s[::step]) / len(s[::step])
    rms = math.sqrt(sq)
    rows.append((n, peak, 20 * math.log10(max(rms, 1) / 32768), len(s) / 2 / 44100))
for n, peak, rms_db, secs in sorted(rows):
    print(f'{n:3d} peak={peak:5d} rms={rms_db:6.1f} dB len={secs:6.1f}s')
