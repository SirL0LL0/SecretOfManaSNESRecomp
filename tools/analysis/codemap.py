import re, glob, os, sys, json
gen=r'C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp\generated'
rom=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
S=[2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   3,2,4,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   1,2,2,2,3,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,4,3,3,4,
   1,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   2,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4,
   2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,3,3,3,4]
MIMM={0x09,0x29,0x49,0x69,0x89,0xA9,0xC9,0xE9}; XIMM={0xA0,0xA2,0xC0,0xE0}
TERM={0x40,0x60,0x6B,0x4C,0x5C,0x6C,0x7C,0xDC,0x80,0x82,0xDB}
def off(bank,addr):
    if bank>=0xC0: return ((bank-0xC0)<<16)|addr
    return (bank<<16)|addr
labels=[]
lab=re.compile(r'^\s*L_([0-9A-F]{4})_M([01])X([01]):')
for f in glob.glob(gen+r'\bank*_v2.c'):
    bank=int(os.path.basename(f)[4:6],16)
    for line in open(f,encoding='utf-8',errors='replace'):
        m=lab.match(line)
        if m: labels.append((bank,int(m.group(1),16),int(m.group(2)),int(m.group(3))))
starts={off(b,a) for b,a,_,_ in labels}
code=set()
for b,a,mm,xx in labels:
    o=off(b,a); n=0
    while n<400:
        op=rom[o]; ln=S[op]
        if op in MIMM and mm==0: ln+=1
        if op in XIMM and xx==0: ln+=1
        for k in range(ln): code.add(o+k)
        if op==0xC2: v=rom[o+1]; mm=0 if v&0x20 else mm; xx=0 if v&0x10 else xx
        if op==0xE2: v=rom[o+1]; mm=1 if v&0x20 else mm; xx=1 if v&0x10 else xx
        if op in TERM: break
        o+=ln; n+=1
        if o in starts: break
print(len(labels),'labels',len(code),'code bytes')
json.dump(sorted(code),open(sys.argv[1],'w'))
