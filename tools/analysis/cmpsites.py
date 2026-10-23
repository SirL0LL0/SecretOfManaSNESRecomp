import sys
it=open(sys.argv[1],'rb').read(); us=open(sys.argv[2],'rb').read()
for off,n in [(0x8000,0x20),(0xFFDC,4),(0xFFE0,0x20),(0x30000,0x10),(0x324B0,0x20),(0xB3400,0x260),(0xB3660,0x40)]:
    print('%06X it %s'%(off,it[off:off+n].hex())); print('%06X us %s'%(off,us[off:off+n].hex()))
print(len(it),len(us))
