import sys
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
j=open(r'C:\Users\lollo\Downloads\SOM\sources\Seiken Densetsu 2 (J).smc','rb').read()
if len(j)%0x8000==512: j=j[512:]
print(len(us),len(j))
def o(a): b=a>>16; return ((((b&0x3F)<<16)|(a&0xFFFF))&(len(j)-1))
for c in sys.argv[1:]:
    a=int(c[:6],16); t=o(a)
    print(c, '%06X'%t, 'J:', j[t-4:t+5].hex(' '), ' US:', us[t-4:t+5].hex(' '))
