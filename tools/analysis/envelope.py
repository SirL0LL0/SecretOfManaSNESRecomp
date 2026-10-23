"""envelope.py <pcm_s16_stereo> <rate> <out.png> [start_s] [len_s]
RMS envelope (20 ms windows) of a raw s16 stereo stream, drawn as a strip."""
import sys, struct, math
from PIL import Image, ImageDraw

path, rate, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
start = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
length = float(sys.argv[5]) if len(sys.argv) > 5 else 1e9
data = open(path, 'rb').read()
n = len(data) // 4
s0 = int(start * rate)
s1 = min(n, s0 + int(length * rate))
win = int(rate * 0.02)
env = []
for w in range(s0, s1 - win, win):
    acc = 0
    for i in range(w, w + win):
        l, r = struct.unpack_from('<hh', data, i * 4)
        acc += l * l + r * r
    env.append(math.sqrt(acc / (2 * win)))
print('samples', n, 'seconds', n / rate, 'windows', len(env))
if env:
    m = max(env) or 1
    # jumps between consecutive windows, in dB
    jumps = []
    for a, b in zip(env, env[1:]):
        if a > m * 0.05 and b > m * 0.05:
            jumps.append(20 * math.log10(b / a))
    big = [j for j in jumps if abs(j) > 3]
    print('max rms %.0f; windows with |step|>3dB: %d of %d' % (m, len(big), len(jumps)))
    H = 200
    img = Image.new('RGB', (len(env), H), (20, 20, 20))
    d = ImageDraw.Draw(img)
    for x, v in enumerate(env):
        d.line([(x, H - 1), (x, H - 1 - int(v / m * (H - 1)))], fill=(90, 200, 120))
    for t in range(0, int(len(env) * 0.02) + 1):
        d.line([(t * 50, 0), (t * 50, 6)], fill=(255, 255, 0))
    img.save(out)
