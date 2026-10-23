import sys
sc=sys.argv[1]
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
it=open(sc+r'\rom_it201.sfc','rb').read()
def find(o, w, src=us, dst=it):
    pat=src[o-w:o+w+1]; hits=[]; s=0
    while True:
        k=dst.find(pat,s)
        if k<0: break
        hits.append(k+w); s=k+1
    return hits
# original fanfare patch (US)
ips=open(sc+r'\fanfare_zip\Secret of Mana Restore Unused Fanfares 1.2.ips','rb').read()
i=5; recs=[]
while ips[i:i+3]!=b'EOF':
    off=int.from_bytes(ips[i:i+3],'big'); n=int.from_bytes(ips[i+3:i+5],'big'); i+=5
    recs.append((off,ips[i:i+n])); i+=n
for off,data in recs:
    print('fanfare US %06X len %d US-orig %s -> %s'%(off,len(data),us[off:off+len(data)].hex(),data.hex()))
    for w in (16,12,8,6):
        h=find(off,w)
        if h: print('   v2.01 w=%d hits %s orig %s'%(w,['%06X'%x for x in h[:4]], it[h[0]:h[0]+len(data)].hex() if h else '')); break
    else: print('   v2.01: not found')
# cheats ROM data (US offsets from the cheat lists)
for name,o in (('candy price',0x18FB9C),('overalls',0x18FBE0),('bandanna',0x18FBB6),('wristband',0x18FC30),('level16 stats',0x10428B),('neko inn',0x09CF9D),('elder chest gold',0x0A8E9F),('elder repeat',0x0A8EAF)):
    same = us[o]==it[o] and us[o-8:o+8]==it[o-8:o+8]
    if same: print('%-16s US %06X=%02X  v2.01 same offset'%(name,o,us[o])); continue
    for w in (12,8,6,4):
        h=find(o,w)
        if h: print('%-16s US %06X=%02X  v2.01 w=%d %s'%(name,o,us[o],w,['%06X'%x for x in h[:4]])); break
    else: print('%-16s US %06X=%02X  v2.01 NOT FOUND'%(name,o,us[o]))
