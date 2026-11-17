# fixyft.py <in.yft.xml> <out.yft.xml> [maxgeoms=128]
# Makes a converted vehicle fit GTA V Enhanced's 128 shaders / geometries-per-model limit:
#  1. drops shaders that are exact duplicates and remaps every ShaderIndex in the file
#  2. in every model, merges geometries that share shader, vertex layout and bone palette
#     (vertices concatenated, indices offset), staying under 65535 vertices per geometry
import sys, xml.etree.ElementTree as ET, collections

src, dst = sys.argv[1], sys.argv[2]
tree = ET.parse(src)
root = tree.getroot()
main = root.find('Drawable')
shaders = main.find('ShaderGroup/Shaders')

# 1. dedupe shaders
first = {}
remap = {}
keep = []
for i, s in enumerate(list(shaders)):
    k = ET.tostring(s)
    if k in first:
        remap[i] = first[k]
    else:
        first[k] = len(keep)
        remap[i] = len(keep)
        keep.append(s)
for s in list(shaders):
    shaders.remove(s)
for s in keep:
    shaders.append(s)
for si in root.iter('ShaderIndex'):
    si.set('value', str(remap[int(si.get('value'))]))
print(f'shaders: {len(remap)} -> {len(keep)}')

# 2. merge geometries
def lines(el):
    return [l for l in (el.text or '').splitlines() if l.strip()]

def merge_into(a, b):
    va, vb = a.find('VertexBuffer/Data'), b.find('VertexBuffer/Data')
    la, lb = lines(va), lines(vb)
    off = len(la)
    ia = (a.find('IndexBuffer/Data').text or '').split()
    ib = [str(int(x) + off) for x in (b.find('IndexBuffer/Data').text or '').split()]
    ind = la[0][:len(la[0]) - len(la[0].lstrip())] if la else '     '
    va.text = '\n' + '\n'.join(ind + l.strip() for l in la + lb) + '\n' + ind[:-1]
    allidx = ia + ib
    rows = [' '.join(allidx[i:i + 24]) for i in range(0, len(allidx), 24)]
    a.find('IndexBuffer/Data').text = '\n' + '\n'.join(ind + r for r in rows) + '\n' + ind[:-1]
    for tag, fn in (('BoundingBoxMin', min), ('BoundingBoxMax', max)):
        ea, eb = a.find(tag), b.find(tag)
        for ax in ('x', 'y', 'z', 'w'):
            if ea.get(ax) is not None:
                ea.set(ax, repr(fn(float(ea.get(ax)), float(eb.get(ax)))))
    return off + len(lb)

for d in root.iter('Drawable'):
    for lod in ('DrawableModelsHigh', 'DrawableModelsMedium', 'DrawableModelsLow', 'DrawableModelsVeryLow'):
        ms = d.find(lod)
        if ms is None:
            continue
        for mi, m in enumerate(ms):
            gs = m.find('Geometries')
            before = len(gs)
            target = {}   # key -> (geometry, vertexcount)
            for g in list(gs):
                lay = g.find('VertexBuffer/Layout')
                key = (g.find('ShaderIndex').get('value'), lay.get('type'), tuple(c.tag for c in lay),
                       (g.findtext('BoneIDs') or '').strip(), g.find('VertexBuffer/Flags').get('value'))
                nv = len(lines(g.find('VertexBuffer/Data')))
                if key in target and target[key][1] + nv <= 65535:
                    t, tv = target[key]
                    target[key] = (t, merge_into(t, g))
                    gs.remove(g)
                else:
                    target[key] = (g, nv)
            if len(gs) != before:
                print(f'{d.findtext("Name") or "child"} {lod}[{mi}]: geometries {before} -> {len(gs)}')
            if len(gs) > 128:
                print(f'WARNING: still {len(gs)} geometries')

tree.write(dst, encoding='UTF-8', xml_declaration=True)
