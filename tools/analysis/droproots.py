import re, sys
p = sys.argv[1]; t = open(p).read()
blocks = t.split('[[func]]'); head, rest = blocks[0], blocks[1:]
keep, drop = [], []
for b in rest:
    bank = int(re.search(r'bank = 0x([0-9A-F]+)', b).group(1), 16)
    addr = int(re.search(r'addr = "([0-9A-F]+)"', b).group(1), 16)
    (drop if bank in (0, 0x7E, 0x7F) and addr < 0x8000 else keep).append(b)
head = head.rstrip('\n') + '\n# ROM roots only: the WRAM routines among them run in the interpreter.\n\n'
open(p, 'w').write(head + ''.join('[[func]]' + b for b in keep))
print('kept', len(keep), 'dropped WRAM', len(drop))
