import struct, sys, json
d=sys.argv[1]; tag=sys.argv[2]
v=open(d+'/'+tag+'.vram.bin','rb').read(); w=open(d+'/'+tag+'.wram.bin','rb').read()
regs=json.load(open(d+'/'+tag+'.regs.json'))
def vw(word): a=(word&0x7fff)*2; return v[a]|v[a+1]<<8
bgsc=regs['bgsc']; hs=regs['hscroll']; vs=regs['vscroll']
def ring_word(layer,tx,ty):
    base=(bgsc[layer]&0xfc)<<8; wide=bgsc[layer]&1; high=bgsc[layer]&2
    tx&= 63 if wide else 31; ty&= 63 if high else 31
    a=base+(ty&31)*32+(tx&31)
    if tx>=32: a+=0x400
    if ty>=32: a+=0x800 if wide else 0x400
    return vw(a)
def cell_words(layer,cx,cy):
    return tuple(ring_word(layer,2*cx+dx,2*cy+dy) for dy in (0,1) for dx in (0,1))
# reverse tables: try every 0x800 region of 7F:8000-7F:FFFF as a metatile table
def find_table(layer):
    H,V=hs[layer],vs[layer]
    cells=[cell_words(layer,(H>>4)+i,(V>>4)+j) for j in range(14) for i in range(16)]
    best=None
    for base in range(0x10000,0x20000,0x800):
        tb=w[base:base+0x800]
        rev={}
        for k in range(256):
            rev.setdefault(struct.unpack_from('<4H',tb,k*8),k)
        hit=sum(1 for c in cells if c in rev)
        if best is None or hit>best[0]: best=(hit,base,rev)
    return best
for layer in (0,1):
    hit,base,rev=find_table(layer)
    print('BG%d table 7F:%04X hits %d/224'%(layer+1,base-0x10000,hit))
    H,V=hs[layer],vs[layer]
    idx=[[rev.get(cell_words(layer,(H>>4)+i,(V>>4)+j)) for i in range(16)] for j in range(14)]
    # search map: base in 7F, stride 0x80, rows 128
    best=None
    for mbase in range(0x10000,0x20000,0x1000):
        for oy in range(0,32):
            for ox in range(0,128-16):
                score=0;tot=0
                for j in range(0,14,2):
                    rowa=mbase+(oy+j)*0x80+ox
                    if rowa+16>0x20000: break
                    for i in range(0,16,2):
                        t=idx[j][i]
                        if t is None: continue
                        tot+=1; score+= (w[rowa+i]==t)
                if tot and (best is None or score>best[0]): best=(score,tot,mbase,ox,oy)
    print('  map best', best[0],'/',best[1],'base 7F:%04X ox %d oy %d'%(best[2]-0x10000,best[3],best[4]))
