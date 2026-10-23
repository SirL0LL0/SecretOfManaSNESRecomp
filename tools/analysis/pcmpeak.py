"""Peak per 3-second window of an MSU-1 .pcm (8-byte header, 44.1 kHz s16 stereo)."""
import array
import sys

data = open(sys.argv[1], 'rb').read()
print('header', data[:8], 'loop', int.from_bytes(data[4:8], 'little'))
s = array.array('h', data[8:8 + (len(data) - 8) // 2 * 2])
win = 44100 * 2 * 3
for i in range(0, min(len(s), win * int(sys.argv[2])), win):
    chunk = s[i:i + win]
    print(f'{i // (44100 * 2):4d}s peak={max(abs(x) for x in chunk)}')
