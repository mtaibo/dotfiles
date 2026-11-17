import struct,sys
d=open(sys.argv[1],'rb').read()
n,rva=struct.unpack_from('<II',d,8)
streams={}
for i in range(n):
    t,sz,r=struct.unpack_from('<III',d,rva+i*12); streams[t]=(r,sz)
mods=[]
r,_=streams[4]; cnt=struct.unpack_from('<I',d,r)[0]
for i in range(cnt):
    o=r+4+i*108; base,size=struct.unpack_from('<QI',d,o); nr=struct.unpack_from('<I',d,o+20)[0]
    ln=struct.unpack_from('<I',d,nr)[0]; name=d[nr+4:nr+4+ln].decode('utf-16le')
    mods.append((base,size,name.split('\\')[-1]))
r,_=streams[6]; tid=struct.unpack_from('<I',d,r)[0]
code,flags,rec,addr,np=struct.unpack_from('<IIQQI',d,r+8)
params=struct.unpack_from('<%dQ'%np,d,r+8+32)
def where(a):
    for b,s,nm in mods:
        if b<=a<b+s: return f"{nm}+0x{a-b:x}"
    return hex(a)
print(f"code=0x{code:08x} at {where(addr)} params={[hex(p) for p in params]}")
