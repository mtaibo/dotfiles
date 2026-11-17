# setaudio.py <in vehicles.meta> <out> <model=audio>...: set audioNameHash per modelName, keep everything else byte-identical
import sys, re
raw = open(sys.argv[1], 'rb').read(); bom = raw.startswith(b'\xef\xbb\xbf'); s = raw.decode('utf-8-sig')
want = dict(a.split('=') for a in sys.argv[3:]); done = set()
def item(m):
    body = m.group(0); mm = re.search(r'<modelName>([^<]+)</modelName>', body)
    if not mm or mm.group(1).strip().lower() not in want: return body
    model = mm.group(1).strip().lower(); new = want[model]
    body2, n = re.subn(r'<audioNameHash>[^<]*</audioNameHash>|<audioNameHash\s*/>', f'<audioNameHash>{new}</audioNameHash>', body, count=1)
    if n != 1: raise SystemExit(f'{model}: no audioNameHash element')
    done.add(model); return body2
s = re.sub(r'<Item>\s*<modelName>.*?</Item>', item, s, flags=re.S)
missing = set(want) - done
if missing: raise SystemExit(f'models not found: {missing}')
open(sys.argv[2], 'wb').write((b'\xef\xbb\xbf' if bom else b'') + s.encode('utf-8'))
print('set', ', '.join(f'{m}={want[m]}' for m in sorted(done)))
