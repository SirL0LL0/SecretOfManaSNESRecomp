"""Small image helpers for recomp vs Mesen comparisons.

  tools.py sheet <dir> <out.png> [cols] [start] [end]   contact sheet of *.fb.bmp
  tools.py diff <ref_dir> <dir> [<dir>...]               % differing pixels, i####.fb.bmp vs r####.png
  tools.py band <glob_fmt> <first> <count> <y0> <y1> <out.png>   zoomed rows of consecutive frames
"""
import sys, os, glob
from PIL import Image, ImageDraw, ImageChops


def load(p):
    return Image.open(p).convert('RGB').resize((256, 224))


def sheet(d, out, cols=6, a=None, b=None):
    files = sorted(glob.glob(os.path.join(d, '*.fb.bmp')))[a:b]
    rows = (len(files) + cols - 1) // cols
    s = Image.new('RGB', (cols * 256, rows * 236), (40, 40, 40))
    dr = ImageDraw.Draw(s)
    for i, f in enumerate(files):
        x, y = (i % cols) * 256, (i // cols) * 236
        s.paste(load(f), (x, y + 12))
        dr.text((x + 2, y), os.path.basename(f).split('.')[0], fill=(255, 255, 0))
    s.save(out)
    print(len(files), s.size)


def pct(a, b):
    d = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > 8 else 0)
    return 100.0 * sum(1 for v in d.getdata() if v) / (256 * 224)


def diff(ref, dirs):
    tot = [0.0] * len(dirs)
    n = 0
    for f in range(50, 3001, 50):
        r = os.path.join(ref, 'r%04d.png' % f)
        if not os.path.exists(r):
            continue
        b = load(r)
        n += 1
        for i, d in enumerate(dirs):
            tot[i] += pct(load(os.path.join(d, 'i%04d.fb.bmp' % f)), b)
    print('mean ' + ' '.join('%s=%.2f%%' % (os.path.basename(d), t / n) for d, t in zip(dirs, tot)))


def band(fmt, first, count, y0, y1, out):
    z = 3
    h = (y1 - y0) * z
    s = Image.new('RGB', (256 * z + 60, count * (h + 2)), (60, 0, 60))
    dr = ImageDraw.Draw(s)
    for i in range(count):
        im = load(fmt % (first + i)).crop((0, y0, 256, y1))
        s.paste(im.resize((256 * z, h), Image.NEAREST), (60, i * (h + 2)))
        dr.text((2, i * (h + 2) + 2), str(first + i), fill=(255, 255, 0))
    s.save(out)


def blink(pattern):
    """Rows whose content changes for exactly one frame (A -> B -> A)."""
    import hashlib
    files = sorted(glob.glob(pattern))
    prev2 = prev1 = None
    hits = {}
    for i, f in enumerate(files):
        raw = load(f).tobytes()
        rows = [hashlib.md5(raw[y * 768:(y + 1) * 768]).digest() for y in range(224)]
        if prev2 is not None:
            for y in range(224):
                if prev1[y] != prev2[y] and rows[y] == prev2[y]:
                    hits.setdefault(os.path.basename(files[i - 1]), []).append(y)
        prev2, prev1 = prev1, rows
    print(len(files), 'frames;', len(hits), 'with one-frame blinks')
    for k, ys in sorted(hits.items()):
        print(' ', k, 'rows %d-%d (%d)' % (ys[0], ys[-1], len(ys)))


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == 'sheet':
        sheet(args[0], args[1], int(args[2]) if len(args) > 2 else 6,
              int(args[3]) if len(args) > 3 else None, int(args[4]) if len(args) > 4 else None)
    elif cmd == 'diff':
        diff(args[0], args[1:])
    elif cmd == 'blink':
        blink(args[0])
    elif cmd == 'band':
        band(args[0], int(args[1]), int(args[2]), int(args[3]), int(args[4]), args[5])
