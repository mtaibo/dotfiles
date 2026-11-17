# todds.py <in> <out.dds> [levels]: rewrite a texture as an uncompressed A8R8G8B8 DDS with a box-filtered mip chain.
# <in> is a raw "<name>.<w>x<h>.bgra" from `rpftool texexport`, or any image Pillow can read (incl. BC7 .dds,
# which CodeWalker can't decode). Needs numpy and Pillow (nix shell nixpkgs#python3Packages.{numpy,pillow}).
import re, struct, sys
import numpy as np

src, out = sys.argv[1], sys.argv[2]
m = re.search(r'\.(\d+)x(\d+)\.bgra$', src)
if m:
    w, h = int(m.group(1)), int(m.group(2))
    img = np.frombuffer(open(src, 'rb').read(), np.uint8).reshape(h, w, 4).copy()   # B,G,R,A
else:
    from PIL import Image
    rgba = np.asarray(Image.open(src).convert('RGBA'), np.uint8)
    h, w = rgba.shape[:2]
    img = rgba[:, :, [2, 1, 0, 3]].copy()                                          # RGBA -> BGRA

levels = [img]
while levels[-1].shape[0] > 1 or levels[-1].shape[1] > 1:
    p = levels[-1].astype(np.uint32)
    if p.shape[0] % 2: p = np.concatenate([p, p[-1:]], 0)
    if p.shape[1] % 2: p = np.concatenate([p, p[:, -1:]], 1)
    n = (p[0::2, 0::2] + p[1::2, 0::2] + p[0::2, 1::2] + p[1::2, 1::2]) // 4
    levels.append(n.astype(np.uint8))
if len(sys.argv) > 3: levels = levels[:int(sys.argv[3])]

hdr = struct.pack('<4sI', b'DDS ', 124) + struct.pack('<IIIIII', 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x8, h, w, w * 4, 0, len(levels)) + b'\0' * 44
hdr += struct.pack('<II4sIIIII', 32, 0x41, b'\0\0\0\0', 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
hdr += struct.pack('<IIIII', 0x1000 | 0x8 | 0x400000, 0, 0, 0, 0)
open(out, 'wb').write(hdr + b''.join(l.tobytes() for l in levels))
a = img[:, :, 3]
print(f'{src} -> {out}: {w}x{h}, {len(levels)} levels, alpha min/max {a.min()}/{a.max()}, mean BGR {img[:, :, :3].reshape(-1, 3).mean(0).round(1)}')
