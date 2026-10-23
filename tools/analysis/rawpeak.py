"""Peak per 5 s window of raw s16 stereo audio at the given rate; also write a WAV."""
import array
import sys
import wave

path, rate = sys.argv[1], int(sys.argv[2])
data = open(path, 'rb').read()
s = array.array('h', data[:len(data) // 4 * 4])
win = rate * 2 * 5
for i in range(0, len(s), win):
    chunk = s[i:i + win]
    print(f'{i // (rate * 2):4d}s peak={max(abs(x) for x in chunk)}')
w = wave.open(sys.argv[3], 'wb')
w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
w.writeframes(data[:len(data) // 4 * 4])
w.close()
