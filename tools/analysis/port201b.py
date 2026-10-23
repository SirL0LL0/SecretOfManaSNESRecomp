import sys
sc=sys.argv[1]
it20=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
it=open(sc+r'\rom_it201.sfc','rb').read()
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
def find(src,o,w,dst=it,after=0):
    pat=src[o+after:o+w] if after else src[o-w:o+w+1]
    hits=[];s=0
    while True:
        k=dst.find(pat,s)
        if k<0: break
        hits.append(k); s=k+1
    return hits
for name,o,n in (('fanfare1',0x09A6BD,1),('fanfare2',0x09B6D1,2),('elder gold',0x0A85F1-0x0,1)):
    for w in (16,12,8,6,5,4):
        h=find(it20,o,w)
        if h:
            print(name,'v2.0 %06X'%o,'w=%d'%w,['%06X'%(x+w) for x in h[:5]], 'bytes', it[h[0]+w:h[0]+w+n].hex(),'v20', it20[o:o+n].hex()); break
    else: print(name,'not found')
# elder chest gold relative to repeat: US gold=0A8E9F, repeat=0A8EAF (16 apart)
print('elder gold guess v2.01 0A85E1:', it[0x0A85E1-4:0x0A85E1+5].hex(), ' US ctx', us[0x0A8E9F-4:0x0A8E9F+5].hex(),' repeat v2.01', it[0x0A85F1-3:0x0A85F1+3].hex())
print('neko v2.01 09BBBF:', it[0x09BBBF-5:0x09BBBF+5].hex(), ' US', us[0x09CF9D-5:0x09CF9D+5].hex())
