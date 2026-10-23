import json, sys
it=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
aot=set(json.load(open(sys.argv[2]))); itp=set(json.load(open(sys.argv[3])))
def target(a):
    b=a>>16; o=a&0xFFFF
    if b in (0x7E,0x7F): return ('wram',a&0x1FFFF)
    if (b<0x40 or 0x80<=b<0xC0):
        if o<0x2000: return ('wram',o)
        if o<0x8000: return ('io',a)
    return ('rom',(((b&0x3F)<<16)|o)&0x1FFFFF)
for line in open(sys.argv[1],encoding='utf-8-sig'):
    line=line.strip()
    if not line: continue
    n,c=line.split('|'); a=int(c[:6],16); v=int(c[6:],16)
    k,t=target(a)
    if k=='wram': print('%-44s %s  WRAM $%05X = %02X'%(n[:44],c,t,v)); continue
    if k=='io': print('%-44s %s  IO %06X ?'%(n[:44],c,t)); continue
    same = it[t-6:t+7]==us[t-6:t+7]
    cls = 'AOT-CODE' if t in aot else 'INTERP-CODE' if t in itp else ('near-code' if any((t+d) in aot or (t+d) in itp for d in range(-4,5)) else 'data?')
    print('%-44s %s  ROM %06X it=%02X us=%02X ctx=%s %s'%(n[:44],c,t,it[t],us[t],'same' if same else 'DIFF',cls))
