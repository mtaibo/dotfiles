# bgra2png.py <file.WxH.bgra>... -> .png next to it (stdlib only)
import sys, zlib, struct, re
for f in sys.argv[1:]:
    w, h = map(int, re.search(r'\.(\d+)x(\d+)\.bgra$', f).groups())
    d = open(f, 'rb').read()
    rows = b''.join(b'\x00' + bytes(x for i in range(w) for x in (d[(y*w+i)*4+2], d[(y*w+i)*4+1], d[(y*w+i)*4], d[(y*w+i)*4+3])) for y in range(h))
    def chunk(t, c): return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b'')
    open(f[:-5] + '.png', 'wb').write(png)
    print(f[:-5] + '.png')
