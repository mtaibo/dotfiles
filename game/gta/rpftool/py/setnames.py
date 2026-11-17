# setnames.py <in vehicles.meta> <out> <model=gameName:makeName>...: set the display name (gameName) and brand
# (vehicleMakeName) per modelName, keep everything else byte-identical. Both are shown raw when no text label
# matches them, and the game keeps at most 11 characters of each (longer names get cut: "Audi R8 202").
import sys, re
raw = open(sys.argv[1], 'rb').read(); bom = raw.startswith(b'\xef\xbb\xbf'); s = raw.decode('utf-8-sig')
want = {}
for a in sys.argv[3:]:
    model, names = a.split('=', 1); game, make = names.split(':', 1)
    for n in (game, make):
        if len(n) > 11: raise SystemExit(f'{n!r} is longer than 11 characters')
    want[model.lower()] = (game, make)
done = set()
def item(m):
    body = m.group(0); mm = re.search(r'<modelName>([^<]+)</modelName>', body)
    if not mm or mm.group(1).strip().lower() not in want: return body
    model = mm.group(1).strip().lower(); game, make = want[model]
    for tag, val in (('gameName', game), ('vehicleMakeName', make)):
        body, n = re.subn(rf'<{tag}>[^<]*</{tag}>|<{tag}\s*/>', f'<{tag}>{val}</{tag}>', body, count=1)
        if n != 1: raise SystemExit(f'{model}: no {tag} element')
    done.add(model); return body
s = re.sub(r'<Item>\s*<modelName>.*?</Item>', item, s, flags=re.S)
missing = set(want) - done
if missing: raise SystemExit(f'models not found: {missing}')
open(sys.argv[2], 'wb').write((b'\xef\xbb\xbf' if bom else b'') + s.encode('utf-8'))
print('set', ', '.join(f'{m}={want[m][0]} ({want[m][1]})' for m in sorted(done)))
