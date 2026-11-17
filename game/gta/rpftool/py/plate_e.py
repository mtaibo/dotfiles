# plate_e.py <in.bgra 256x128> <out.dds> <preview.png>: replace "PL" on the EU strip with a centred "E" built from the L glyph
import sys, struct, zlib
src, out, prev = sys.argv[1:4]
w, h = 256, 128
d = bytearray(open(src, 'rb').read())
def get(x, y): i = (y*w+x)*4; return d[i:i+4]
def put(x, y, c): i = (y*w+x)*4; d[i:i+4] = c
white = bytes(get(38, 85))            # L stem colour (b,g,r,a)
# clear glyph area to the strip blue, sampling each row's blue at x=10 to keep any gradient
for y in range(74, 105):
    blue = bytes(get(10, y))
    for x in range(9, 59):
        put(x, y, blue)
# E: stem 3px, bars 3 rows, middle bar slightly shorter (like the font's E)
x0 = 27; top, bot = 77, 101; width = 13; mid = (top + bot) // 2 - 1
for y in range(top, bot + 1):
    for x in range(x0, x0 + 3): put(x, y, white)
for (y0, wd) in ((top, width), (mid, width - 2), (bot - 2, width)):
    for y in range(y0, y0 + 3):
        for x in range(x0, x0 + wd): put(x, y, white)
# mip chain (box filter) + DDS A8R8G8B8
levels = [bytes(d)]; lw, lh = w, h
while lw > 1 or lh > 1:
    pw, ph, p = lw, lh, levels[-1]; lw, lh = max(1, lw//2), max(1, lh//2); n = bytearray(lw*lh*4)
    for y in range(lh):
        for x in range(lw):
            for c in range(4):
                s = sum(p[((min(ph-1, y*2+dy))*pw + min(pw-1, x*2+dx))*4 + c] for dy in (0, 1) for dx in (0, 1))
                n[(y*lw+x)*4+c] = s // 4
    levels.append(bytes(n))
nlev = int(sys.argv[4]) if len(sys.argv) > 4 else len(levels)
levels = levels[:nlev]
hdr = struct.pack('<4sI', b'DDS ', 124) + struct.pack('<IIIIII', 0x1|0x2|0x4|0x1000|0x20000|0x8, h, w, w*4, 0, len(levels)) + b'\0'*44
hdr += struct.pack('<II4sIIIII', 32, 0x41, b'\0\0\0\0', 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
hdr += struct.pack('<IIIII', 0x1000|0x8|0x400000, 0, 0, 0, 0)
open(out, 'wb').write(hdr + b''.join(levels))
# preview x4 over checkerboard
S = 4; rows = b''
for y in range(h*S):
    row = bytearray(b'\0')
    for x in range(w*S):
        b, g, r, a = d[((y//S)*w + x//S)*4:((y//S)*w + x//S)*4+4]; k = 90 if ((x//16+y//16) % 2) else 160
        row += bytes(((r*a+k*(255-a))//255, (g*a+k*(255-a))//255, (b*a+k*(255-a))//255))
    rows += bytes(row)
ch = lambda t, c: struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t+c) & 0xffffffff)
open(prev, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w*S, h*S, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(rows, 6)) + ch(b'IEND', b''))
print('levels', len(levels))
