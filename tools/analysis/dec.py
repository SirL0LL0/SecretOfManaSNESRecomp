import sys
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
it=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
def dec(d,a,b):
    out=[]
    for x in d[a:b]:
        if 0x81<=x<=0x9A: out.append(chr(ord('a')+x-0x81))
        elif 0x9B<=x<=0xB4: out.append(chr(ord('A')+x-0x9B))
        elif x==0x80: out.append(' ')
        elif x==0x7F: out.append('/')
        elif x==0xC5: out.append(':')
        elif x==0xC8: out.append('!')
        elif x==0xBF: out.append('.')
        elif x==0xC2: out.append("'")
        else: out.append('[%02X]'%x)
    return ''.join(out)
print('US:', dec(us,0x092900,0x092AB0))
print()
print('IT:', dec(it,0x092600,0x092850))
