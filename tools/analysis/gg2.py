import json, sys
it=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
code=set(json.load(open(sys.argv[1])))
GG="DF4709156BC8A23E"
L=[("EE28-EDAF","Start new game with 255 GP"),("6D28-EFDF","Start new game with 32,768 GP"),("EE28-EFDF","Start new game with 65,280 GP"),
("6F09-8707","Start new game at Level 16"),("9C06-81AD","Strength for level 16 is 90"),("9C06-85DD","Agility for level 16 is 90"),
("9C06-850D","Constitution for level 16 is 90"),("9C06-856D","Intelligence for level 16 is 90"),("9C06-85AD","Wisdom for level 16 is 90"),
("EE6B-8738","Elder chest 65360 GP"),("C274-8764","Inn Potos free 1"),("C277-8DA4","Inn Potos free 2"),("CE5F-5767","Potos shop free"),
("DDEB-E544","Candy"),("DDE3-E044","Overalls"),("DDE8-E9C4","Bandanna"),("DDEC-E9C4","Cup of wishes"),("DDEC-E944","Medical herb"),
("DDE7-7047","Wristband"),("DDE8-E144","Hair ribbon"),("DDE8-E1C4","Rabite cap"),("DDEC-E0C4","Faerie walnut 1"),("DDEC-E034","Faerie walnut 2"),
("DDEC-E044","Royal jam"),("DDEB-E5C4","Chocolate"),("DDAB-E715","Neko inn free"),("8208-776D","Protection from most hits")]
for c,n in L:
    t=''.join('%X'%GG.index(ch) for ch in c.replace('-',''))
    v=int(t[:2],16); a=int(t[2:],16)
    a=(((a&0x003C00)<<10)|((a&0x00003C)<<14)|((a&0xF00000)>>8)|((a&0x000003)<<10)|((a&0x00C000)>>6)|((a&0x0F0000)>>12)|((a&0x0003C0)>>6))
    b=a>>16; o=(((b&0x3F)<<16)|(a&0xFFFF))&0x1FFFFF
    cls='CODE' if o in code else 'data'
    same=it[o-6:o+7]==us[o-6:o+7]
    print('%-30s %s -> %06X=%02X off %06X it=%02X us=%02X %s %s  %s'%(n,c,a,v,o,it[o],us[o],'same' if same else 'DIFF',cls,it[o-6:o+6].hex(' ')))
