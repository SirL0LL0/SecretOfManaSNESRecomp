import json, re, glob, os, sys
rom=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
proj=r'C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp'
S=[2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 3,2,4,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 1,2,2,2,3,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,4,3,3,4, 1,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,3,3,3,4]
MIMM={0x09,0x29,0x49,0x69,0x89,0xA9,0xC9,0xE9}; XIMM={0xA0,0xA2,0xC0,0xE0}
STOP={0x40,0x60,0x6B,0x6C,0x7C,0xDC,0xDB,0x00,0x02,0xFC}
COND={0x10,0x30,0x50,0x70,0x90,0xB0,0xD0,0xF0}
def off(pc):
    b=pc>>16; a=pc&0xFFFF
    if b in (0x7E,0x7F): return None
    if b>=0xC0 or 0x40<=b<0x7E: o=((b&0x3F)<<16)|a
    elif a>=0x8000: o=((b&0x3F)<<16)|a
    else: return None
    return o if o<len(rom) else None
work=[]
for f in glob.glob(proj+r'\config\bank*.cfg'):
    bank=int(os.path.basename(f)[4:6],16)
    for line in open(f,errors='replace'):
        m=re.match(r'\s*func\s+\S+\s+([0-9A-Fa-f]{4,6})\s+entry_mx:(\d),(\d)',line)
        if m:
            a=int(m.group(1),16); pc=a if a>0xFFFF else (bank<<16|a)
            work.append((pc,int(m.group(2)),int(m.group(3))))
lab=re.compile(r'^\s*L_([0-9A-F]{4})_M([01])X([01]):')
for f in glob.glob(proj+r'\generated\bank*_v2.c'):
    bank=int(os.path.basename(f)[4:6],16)
    for line in open(f,encoding='utf-8',errors='replace'):
        m=lab.match(line)
        if m: work.append((bank<<16|int(m.group(1),16),int(m.group(2)),int(m.group(3))))
for f in glob.glob(proj+r'\build\coverage\secret-of-mana\*.json')+glob.glob(proj+r'\coverage\runs\**\*.json',recursive=True):
    try: j=json.load(open(f))
    except Exception: continue
    for c in j.get('costs',[]):
        mx=c.get('entry_mx','M1X1')
        work.append((int(c['target_pc24'],16),int(mx[1]),int(mx[3])))
seen=set(); code=set()
while work:
    pc,m,x=work.pop()
    while True:
        o=off(pc)
        if o is None or (o,m,x) in seen: break
        seen.add((o,m,x))
        op=rom[o]; ln=S[op]+((op in MIMM and m==0) or (op in XIMM and x==0))
        if o+ln>len(rom): break
        for k in range(ln): code.add(o+k)
        bank=pc&0xFF0000; nxt=bank|((pc+ln)&0xFFFF)
        if op==0xC2: v=rom[o+1]; m=0 if v&0x20 else m; x=0 if v&0x10 else x
        if op==0xE2: v=rom[o+1]; m=1 if v&0x20 else m; x=1 if v&0x10 else x
        if op in COND or op==0x80:
            d=rom[o+1]; d=d-256 if d>127 else d
            work.append((bank|((pc+2+d)&0xFFFF),m,x))
            if op==0x80: break
        elif op==0x82:
            d=rom[o+1]|rom[o+2]<<8; d=d-65536 if d>32767 else d
            work.append((bank|((pc+3+d)&0xFFFF),m,x)); break
        elif op==0x4C:
            work.append((bank|rom[o+1]|rom[o+2]<<8,m,x)); break
        elif op==0x5C:
            work.append((rom[o+1]|rom[o+2]<<8|rom[o+3]<<16,m,x)); break
        elif op==0x20:
            work.append((bank|rom[o+1]|rom[o+2]<<8,m,x))
        elif op==0x22:
            work.append((rom[o+1]|rom[o+2]<<8|rom[o+3]<<16,m,x))
        if op in STOP: break
        pc=nxt
print(len(code),'code bytes (recursive)')
json.dump(sorted(code),open(sys.argv[1],'w'))
