# sheet.py <outdir> <files.bgra...>: contact sheets of 96x96 thumbs (8 per row, 6 rows per sheet) with index list
import sys, zlib, struct, re, os
out=sys.argv[1]; files=sorted(sys.argv[2:]); T=96; C=8; R=6
def png(path,w,h,px):
    rows=b''.join(b'\x00'+px[y*w*3:(y+1)*w*3] for y in range(h))
    ch=lambda t,c: struct.pack('>I',len(c))+t+c+struct.pack('>I',zlib.crc32(t+c)&0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(rows,6))+ch(b'IEND',b''))
per=C*R
for s in range(0,len(files),per):
    W,H=C*T,R*T; img=bytearray(W*H*3)
    for k,f in enumerate(files[s:s+per]):
        w,h=map(int,re.search(r'\.(\d+)x(\d+)\.bgra$',f).groups()); d=open(f,'rb').read()
        ox,oy=(k%C)*T,(k//C)*T
        for y in range(T-2):
            for x in range(T-2):
                sx,sy=x*w//(T-2),y*h//(T-2); i=(sy*w+sx)*4
                b,g,r,a=d[i],d[i+1],d[i+2],d[i+3]
                bg=128 if ((x//8+y//8)%2) else 200
                r=(r*a+bg*(255-a))//255; g=(g*a+bg*(255-a))//255; b=(b*a+bg*(255-a))//255
                p=((oy+y)*W+ox+x)*3; img[p:p+3]=bytes((r,g,b))
    png(os.path.join(out,f'sheet{s//per}.png'),W,H,bytes(img))
    print(f'sheet{s//per}.png:',' | '.join(f'{k}:{os.path.basename(f).split(".")[0]}' for k,f in enumerate(files[s:s+per])))
