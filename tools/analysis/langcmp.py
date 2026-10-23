import sys, json, hashlib
sc=sys.argv[1]
us=open(r'C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA).sfc','rb').read()
it20=open(r'C:\Users\lollo\Downloads\SOM\sources\rom_test.sfc','rb').read()
ips=open(sc+r'\itpatch\Secret of Mana (USA).ips','rb').read()
def apply(src,p):
    d=bytearray(src); assert p[:5]==b'PATCH'; i=5
    while p[i:i+3]!=b'EOF':
        off=int.from_bytes(p[i:i+3],'big'); n=int.from_bytes(p[i+3:i+5],'big'); i+=5
        if n==0:
            rl=int.from_bytes(p[i:i+2],'big'); v=p[i+2]; i+=3; data=bytes([v])*rl
        else: data=p[i:i+n]; i+=n
        if off+len(data)>len(d): d.extend(b'\0'*(off+len(data)-len(d)))
        d[off:off+len(data)]=data
    if len(p)>i+3: 
        t=int.from_bytes(p[i+3:i+6],'big'); d=d[:t]
    return bytes(d)
it201=apply(us,ips)
open(sc+r'\rom_it201.sfc','wb').write(it201)
print('US  ',len(us),hashlib.sha256(us).hexdigest())
print('IT20',len(it20),hashlib.sha256(it20).hexdigest())
print('IT201',len(it201),hashlib.sha256(it201).hexdigest())
aot=set(json.load(open(sc+r'\codemap.json'))); full=set(json.load(open(sc+r'\fullcode.json')))
def diff(a,b,sel):
    n=min(len(a),len(b)); return sum(1 for o in sel if o<n and a[o]!=b[o])
for name,a,b in (('US vs IT20',us,it20),('IT20 vs IT201',it20,it201),('US vs IT201',us,it201)):
    n=min(len(a),len(b)); tot=sum(1 for o in range(n) if a[o]!=b[o])
    print('%-14s total diff %d (len %d/%d)  AOT-code bytes diff %d/%d  all-code diff %d/%d'%(name,tot,len(a),len(b),diff(a,b,aot),len(aot),diff(a,b,full),len(full)))
