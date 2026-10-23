"""Simulate msu1's track gain + limiter on a .pcm; report peaks per 6 s and clipped samples."""
import array
import sys

gain, limit, rate = float(sys.argv[2]), 28000.0, 44100
data = open(sys.argv[1], 'rb').read()[8:]
s = array.array('h', data[:len(data) // 4 * 4])
release = 1.0 - 1.0 / (0.5 * rate)
env = 0.0
win_peak = 0
clipped = 0
win = rate * 6
for i in range(0, len(s), 2):
    l, r = s[i], s[i + 1]
    peak = max(abs(l), abs(r))
    env = peak if peak > env else env * release
    g = gain if env * gain <= limit else limit / env
    ol, orr = int(l * g), int(r * g)
    m = max(abs(ol), abs(orr))
    clipped += m > 32767
    win_peak = max(win_peak, m)
    if (i // 2 + 1) % win == 0:
        print(f'{(i // 2) // rate:4d}s out_peak={win_peak}')
        win_peak = 0
print('clipped samples:', clipped)
