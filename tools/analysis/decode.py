import sys
it=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
GG="DF4709156BC8A23E"
def gg(code):
    t=''.join('%X'%GG.index(c) for c in code.upper())
    v=int(t[0:2],16); a=int(t[2:8],16)
    a=(((a&0x003C00)<<10)|((a&0x00003C)<<14)|((a&0xF00000)>>8)|((a&0x000003)<<10)|((a&0x00C000)>>6)|((a&0x0F0000)>>12)|((a&0x0003C0)>>6))
    return a,v
def off(a):
    b=a>>16; o=a&0xFFFF
    if 0x7E<=b<=0x7F: return None
    if b>=0xC0: return ((b-0xC0)<<16)|o
    if 0x40<=b<0x7E: return ((b-0x40)<<16)|o
    if b<0x40 or 0x80<=b<0xC0:
        if o<0x8000: return None
        return ((b&0x3F)<<16)|o
def desc(a,v):
    o=off(a)
    if (a>>16) in (0x7E,0x7F): return '%06X=%02X WRAM'%(a,v)
    if o is None: return '%06X=%02X (not ROM)'%(a,v)
    i=it[o] if o<len(it) else None; u=us[o] if o<len(us) else None
    return '%06X=%02X rom@%06X it=%s us=%s%s'%(a,v,o,'%02X'%i if i is not None else '--','%02X'%u if u is not None else '--',' DIFF' if i!=u else '')
for line in open(sys.argv[1],encoding='utf-8-sig'):
    line=line.strip()
    if not line: continue
    n,c=line.split('|'); a=int(c[:6],16); v=int(c[6:],16)
    print('%-42s %s'%(n[:42],c)); print('   PAR', desc(a,v)); ga,gv=gg(c); print('   GG ', desc(ga,gv))
