# steamstats.py <UserGameStatsSchema.bin> <UserGameStats.bin>: list unlocked achievements with unlock time
import struct, sys, datetime
def parse(b, i=0):
    d = {}
    while True:
        t = b[i]; i += 1
        if t == 8: return d, i
        j = b.index(b'\0', i); k = b[i:j].decode('utf8', 'replace'); i = j + 1
        if t == 0: v, i = parse(b, i)
        elif t == 1: j = b.index(b'\0', i); v = b[i:j].decode('utf8', 'replace'); i = j + 1
        elif t in (2, 4, 6): v = struct.unpack_from('<i', b, i)[0]; i += 4
        elif t == 3: v = struct.unpack_from('<f', b, i)[0]; i += 4
        elif t == 7: v = struct.unpack_from('<Q', b, i)[0]; i += 8
        else: raise ValueError(f'type {t} at {i}')
        d[k] = v
schema, _ = parse(open(sys.argv[1], 'rb').read())
stats, _ = parse(open(sys.argv[2], 'rb').read())
app = next(iter(schema.values()))
names = {}
for sid, s in app.get('stats', {}).items():
    for bit, a in (s.get('bits') or {}).items():
        disp = a.get('display', {}).get('name', {})
        names[(sid, int(bit))] = disp.get('english') if isinstance(disp, dict) else a.get('name')
rows = []
def walk(d, path=''):
    for k, v in d.items():
        if isinstance(v, dict): walk(v, path + '/' + k)
root = next(iter(stats.values())) if len(stats) == 1 and isinstance(next(iter(stats.values())), dict) else stats
for sid, s in root.items():
    if not isinstance(s, dict): continue
    data = s.get('data'); times = s.get('AchievementTimes', {})
    if isinstance(data, int):
        for bit in range(32):
            if data >> bit & 1:
                ts = times.get(str(bit), 0)
                if (sid, bit) in names and ts: rows.append((ts, names[(sid, bit)]))
for ts, n in sorted(rows):
    print(datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M'), n)
print(len(rows), 'unlocked of', len(names))
