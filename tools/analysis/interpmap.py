import json, glob, sys
rom=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
exec(open(sys.argv[2]).read().split('def off')[0].split('import re, glob, os, sys, json')[1].split("gen=")[0]) if False else None
S=[2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 3,2,4,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 1,2,2,2,3,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,4,3,3,4, 1,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,3,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,3,3,3,4, 2,2,2,2,2,2,2,2,1,2,1,1,3,3,3,4, 2,2,2,2,3,2,2,2,1,3,1,1,3,3,3,4]
MIMM={0x09,0x29,0x49,0x69,0x89,0xA9,0xC9,0xE9}; XIMM={0xA0,0xA2,0xC0,0xE0}
def off(pc):
    b=pc>>16; a=pc&0xFFFF
    if b in (0x7E,0x7F): return None
    if b>=0xC0 or 0x40<=b<0x7E: return ((b&0x3F)<<16)|a
    if a<0x8000: return None
    return ((b&0x3F)<<16)|a
interp=set(); n=0
for f in glob.glob(r'C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp\build\coverage\secret-of-mana\*.json')+glob.glob(r'C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp\coverage\runs\**\*.json',recursive=True):
    try: j=json.load(open(f))
    except Exception: continue
    for c in j.get('costs',[]):
        if c.get('record_kind')!='instruction': continue
        pc=int(c['target_pc24'],16); o=off(pc)
        if o is None or o>=len(rom): continue
        mx=c.get('entry_mx','M1X1'); m=mx[1]=='1'; x=mx[3]=='1'
        op=rom[o]; ln=S[op]+((op in MIMM and not m) or (op in XIMM and not x))
        for k in range(ln): interp.add(o+k)
    n+=1
print(n,'files',len(interp),'interpreted code bytes')
json.dump(sorted(interp),open(sys.argv[1],'w'))
