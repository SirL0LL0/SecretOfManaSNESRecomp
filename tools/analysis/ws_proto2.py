import struct, sys, json
from PIL import Image
d=sys.argv[1]; tag=sys.argv[2]; E=int(sys.argv[3])
v=open(d+'/'+tag+'.vram.bin','rb').read(); w=open(d+'/'+tag+'.wram.bin','rb').read()
cg=open(d+'/'+tag+'.cgram.bin','rb').read()
regs=json.load(open(d+'/'+tag+'.regs.json'))
hs=regs['hscroll']; vs=regs['vscroll']; tiles=regs['bg_tile_adr']
def vw(word): a=(word&0x7fff)*2; return v[a]|v[a+1]<<8
def color(i):
    c=cg[i*2]|cg[i*2+1]<<8; r=c&31; g=c>>5&31; b=c>>10&31
    return ((r<<3)|(r>>2),(g<<3)|(g>>2),(b<<3)|(b>>2))
OX,OY=int(sys.argv[4]),int(sys.argv[5])
L=[dict(map=0x10000,table=0x1C000,H=hs[0],V=vs[0],chr=((tiles>>0)&15)<<12),
   dict(map=0x14000,table=0x1C800,H=hs[1],V=vs[1],chr=((tiles>>4)&15)<<12)]
def pixel(l,sx,y):
    # sx relative to screen left; returns (prio, colorindex) or None
    wx=(sx+(l['H']&15)); wy=(y+(l['V']&15))
    cx=OX+(wx>>4)+((l['H']>>4)-(L[0]['H']>>4)); cy=OY+(wy>>4)+((l['V']>>4)-(L[0]['V']>>4))
    if not(0<=cx<128 and 0<=cy<128): return None
    m=w[l['map']+cy*128+cx]
    q=((wy>>3)&1)*2+((wx>>3)&1)
    t=struct.unpack_from('<H',w,l['table']+m*8+q*2)[0]
    tile=t&0x3ff; pal=(t>>10)&7; pr=(t>>13)&1; hf=t&0x4000; vf=t&0x8000
    px=wx&7; py=wy&7
    if hf: px=7-px
    if vf: py=7-py
    base=l['chr']+tile*16
    p0=vw(base+py); p1=vw(base+8+py)
    bit=7-px
    ci=((p0>>bit)&1)|((p0>>(8+bit))&1)<<1|((p1>>bit)&1)<<2|((p1>>(8+bit))&1)<<3
    if ci==0: return None
    return (pr, pal*16+ci)
W=256+2*E
img=Image.new('RGB',(W,224))
fb=Image.open(d+'/'+tag+'.fb.bmp').convert('RGB')
bd=color(0)
for y in range(224):
    for x in range(W):
        sx=x-E
        p1=pixel(L[0],sx,y); p2=pixel(L[1],sx,y)
        c=bd
        # mode1: BG1H > BG2H > BG1L > BG2L
        order=[(p1,1),(p2,1),(p1,0),(p2,0)]
        for p,pr in order:
            if p and p[0]==pr: c=color(p[1]); break
        img.putpixel((x,y),c)
out=Image.new('RGB',(W,224*2+4),(255,0,255))
out.paste(img,(0,0)); out.paste(fb,(E,228))
out.save(d+'/'+tag+'_wide.png')
