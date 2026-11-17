using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using CodeWalker.GameFiles;
using CodeWalker.Core.Utils;

// rpftool <gamedir> list <rpf> [filter]
// rpftool <gamedir> convert <in.rpf> <out.rpf>     (Legacy -> Enhanced, like CodeWalker's Gen9 converter)
// rpftool <gamedir> dlclist <update.rpf> <item>    (adds <Item>item</Item> to common\data\dlclist.xml)
// rpftool <gamedir> cat <rpf> <innerpath>
partial class P
{
    // Same as the tail of GTA5Keys.Generate: derive the NG encrypt tables from the decrypt ones, so archives
    // like update.rpf can be written.
    static void EnsureEncryptTables()
    {
        var et = new uint[17][][];
        var el = new GTA5NGLUT[17][];
        for (int i = 0; i < 17; i++)
        {
            et[i] = new uint[16][];
            for (int j = 0; j < 16; j++) et[i][j] = new uint[256];
            el[i] = new GTA5NGLUT[16];
            for (int j = 0; j < 16; j++) el[i][j] = new GTA5NGLUT();
        }
        et[0] = RandomGauss.Solve(GTA5Keys.PC_NG_DECRYPT_TABLES[0]);
        et[1] = RandomGauss.Solve(GTA5Keys.PC_NG_DECRYPT_TABLES[1]);
        for (int k = 2; k <= 15; k++) el[k] = LookUpTableGenerator.BuildLUTs2(GTA5Keys.PC_NG_DECRYPT_TABLES[k]);
        et[16] = RandomGauss.Solve(GTA5Keys.PC_NG_DECRYPT_TABLES[16]);
        GTA5Keys.PC_NG_ENCRYPT_TABLES = et;
        GTA5Keys.PC_NG_ENCRYPT_LUTs = el;
    }

    static void Main(string[] a)
    {
        var game = a[0];
        var exe = Directory.GetFiles(game).First(f => Path.GetFileName(f).Equals("GTA5_Enhanced.exe", StringComparison.OrdinalIgnoreCase));
        GTA5Keys.GenerateV2(File.ReadAllBytes(exe), null);
        if (GTA5Keys.PC_AES_KEY == null) throw new Exception("AES key not found in exe");
        GTA5Keys.LoadFromPath(game, true, Convert.ToBase64String(GTA5Keys.PC_AES_KEY));
        RpfManager.IsGen9 = true;
        Action<string> log = s => Console.WriteLine(s);
        switch (a[1])
        {
            case "list":
            {
                var rpf = Open(a[2], log);
                foreach (var r in All(rpf))
                    foreach (var e in r.AllEntries)
                        if (a.Length < 4 || e.Path.Contains(a[3]))
                            Console.WriteLine($"{e.Path}{(e is RpfResourceFileEntry re ? $"  [v{re.Version}]" : "")}  enc={r.Encryption}");
                break;
            }
            case "cat":
            {
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                Console.WriteLine(Encoding.UTF8.GetString(e.File.ExtractFile(e)));
                break;
            }
            case "inspect":
            {
                // textures (name/format/levels/G9 flags) and shader/geometry counts of every ytd/yft
                var rpf = Open(a[2], log);
                foreach (var r in All(rpf))
                foreach (var e in r.AllEntries.OfType<RpfResourceFileEntry>())
                {
                    var data = r.ExtractFile(e);
                    if (e.NameLower.EndsWith(".ytd"))
                    {
                        var y = new YtdFile(); y.Load(data, e);
                        Console.WriteLine($"{e.Path} v{e.Version}");
                        PrintTex(y.TextureDict, "   ");
                    }
                    else if (e.NameLower.EndsWith(".yft"))
                    {
                        var y = new YftFile(); y.Load(data, e);
                        var d = y.Fragment?.Drawable;
                        var shaders = d?.ShaderGroup?.Shaders?.data_items?.Length ?? 0;
                        var geoms = d?.AllModels?.Sum(m => m?.Geometries?.Length ?? 0) ?? 0;
                        var maxg = d?.AllModels?.Max(m => m?.Geometries?.Length ?? 0) ?? 0;
                        Console.WriteLine($"{e.Path} v{e.Version} shaders={shaders} geoms={geoms} maxGeomsPerModel={maxg}");
                        PrintTex(d?.ShaderGroup?.TextureDictionary, "   ");
                    }
                }
                break;
            }
            case "verify":
            {
                // verify <modsroot> : exhaustive offline checks of mods/update (update.rpf + x64/dlcpacks)
                Environment.ExitCode = RunVerify(game, a[2], log);
                break;
            }
            case "texdump":
            {
                // texdump <rpf> <filter>: every property of script_rt textures in ytds whose path contains filter
                var rpf = Open(a[2], log);
                foreach (var r in All(rpf))
                foreach (var e in r.AllEntries.OfType<RpfResourceFileEntry>())
                {
                    if (!e.NameLower.EndsWith(".ytd") || !e.Path.Contains(a[3])) continue;
                    var y = new YtdFile(); y.Load(r.ExtractFile(e), e);
                    if (Environment.GetEnvironmentVariable("RELOAD") == "1")
                    {
                        var raw = ResourceBuilder.AddResourceHeader(e, ResourceBuilder.Compress(r.ExtractFile(e)));
                        y = new YtdFile(); y.Load(raw);
                    }
                    foreach (var t in y.TextureDict.Textures.data_items)
                    {
                        if (!t.Name.StartsWith("script_rt", StringComparison.OrdinalIgnoreCase)) continue;
                        Console.WriteLine($"== {e.Path} :: {t.Name}");
                        foreach (var p in t.GetType().GetProperties())
                        {
                            if (p.GetIndexParameters().Length > 0) continue;
                            object v; try { v = p.GetValue(t); } catch { continue; }
                            if (v is byte[] || v is TextureData) { var fd = (v as TextureData)?.FullData; Console.WriteLine($"   {p.Name} = len {fd?.Length}"); continue; }
                            if (v != null && !(v is string) && v.GetType().IsClass) continue;
                            Console.WriteLine($"   {p.Name} = {v}");
                        }
                        if (t.G9_SRV != null) foreach (var p in t.G9_SRV.GetType().GetProperties()) { try { var v = p.GetValue(t.G9_SRV); if (v == null || v is string || !v.GetType().IsClass) Console.WriteLine($"   SRV.{p.Name} = {v}"); } catch { } }
                    }
                }
                break;
            }
            case "fragdump":
            {
                // fragdump <rpf> <inner yft>: scalar fields and child presence/counts of the FragType
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YftFile(); y.Load(e.File.ExtractFile(e), e);
                var f = y.Fragment;
                foreach (var p in f.GetType().GetProperties())
                {
                    if (p.GetIndexParameters().Length > 0) continue;
                    object v; try { v = p.GetValue(f); } catch { continue; }
                    string s;
                    if (v == null) s = "null";
                    else if (v is string || v.GetType().IsValueType) s = v.ToString();
                    else
                    {
                        var cnt = v.GetType().GetProperty("Count")?.GetValue(v) ?? (v.GetType().GetProperty("data_items")?.GetValue(v) as Array)?.Length;
                        s = $"<{v.GetType().Name}>" + (cnt != null ? $" count={cnt}" : "");
                    }
                    if (p.Name.EndsWith("Pointer") || p.Name == "FilePosition") continue;
                    Console.WriteLine($"{p.Name} = {s}");
                }
                var vg = f.VehicleGlassWindows;
                if (vg != null) Console.WriteLine($"VehicleGlassWindows: {string.Join(", ", vg.GetType().GetProperties().Where(p => p.PropertyType.IsValueType).Select(p => $"{p.Name}={p.GetValue(vg)}"))}");
                break;
            }
            case "deepdump":
            {
                // deepdump <rpf> <inner yft>: recursive scalar dump of the FragType object graph
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YftFile(); y.Load(e.File.ExtractFile(e), e);
                var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
                var skipTypes = new HashSet<string>(Environment.GetEnvironmentVariable("SHADERS") == "1" ? new[] { "DrawableGeometry", "VertexBuffer", "IndexBuffer", "VertexData", "Texture", "TextureBase", "YftFile", "RpfFileEntry", "RpfResourceFileEntry", "ResourceAnalyzer", "VertexDeclaration" } : new[] { "DrawableGeometry", "VertexBuffer", "IndexBuffer", "VertexData", "ShaderFX", "ShaderParametersBlock", "VertexDeclaration", "YftFile", "RpfFileEntry", "RpfResourceFileEntry", "ResourceAnalyzer", "Texture", "TextureBase" });
                void Dump(object o, string path, int depth)
                {
                    if (o == null) { Console.WriteLine($"{path} = null"); return; }
                    var tp = o.GetType();
                    if (o is string || tp.IsValueType || tp.IsEnum) { Console.WriteLine($"{path} = {o}"); return; }
                    if (depth > 9 || skipTypes.Contains(tp.Name) || !seen.Add(o)) { Console.WriteLine($"{path} : <{tp.Name}>"); return; }
                    if (o is Array arr)
                    {
                        Console.WriteLine($"{path}.Length = {arr.Length}");
                        if (tp.GetElementType().IsValueType) return;
                        int i = 0; foreach (var it in arr) { if (i >= 200) break; Dump(it, $"{path}[{i++}]", depth + 1); }
                        return;
                    }
                    if (o is System.Collections.IList list)
                    {
                        Console.WriteLine($"{path}.Count = {list.Count}");
                        int i = 0; foreach (var it in list) { if (i >= 200) break; Dump(it, $"{path}[{i++}]", depth + 1); }
                        return;
                    }
                    foreach (var p in tp.GetProperties())
                    {
                        if (p.GetIndexParameters().Length > 0) continue;
                        if (p.Name.EndsWith("Pointer") || p.Name.StartsWith("FilePosition") || p.Name.StartsWith("BlockLength") || p.Name == "Owner" || p.Name == "Parent" || p.Name.EndsWith("Count1") || p.Name.EndsWith("Count2") || p.Name.EndsWith("BlocksSize")) continue;
                        object v; try { v = p.GetValue(o); } catch { continue; }
                        Dump(v, $"{path}.{p.Name}", depth + 1);
                    }
                }
                Dump(y.Fragment, "F", 0);
                break;
            }
            case "rawtex":
            {
                // rawtex <rpf> <ytd path filter> <texname>: hex of the gen9 texture struct (0x80 bytes) + SRV (0x20) + data size info
                var rpf = Open(a[2], log);
                foreach (var r in All(rpf))
                foreach (var e in r.AllEntries.OfType<RpfResourceFileEntry>())
                {
                    if (!e.NameLower.EndsWith(".ytd") || !e.Path.Contains(a[3])) continue;
                    var y = new YtdFile(); y.Load(r.ExtractFile(e), e);
                    foreach (var t in y.TextureDict.Textures.data_items)
                    {
                        if (!t.Name.Equals(a[4], StringComparison.OrdinalIgnoreCase)) continue;
                        Console.WriteLine($"== {e.Path} :: {t.Name}  sys=0x{e.SystemFlags.Value:X} gfx=0x{e.GraphicsFlags.Value:X} SystemSize={e.SystemSize} GraphicsSize={e.GraphicsSize} dataLen={t.Data?.FullData?.Length}");
                        Console.WriteLine($"   struct@0x{t.FilePosition:X}  SRV@0x{t.G9_SRV?.FilePosition:X}  Data@0x{t.Data?.FilePosition:X}");
                        var raw = r.ExtractFile(e);
                        var sig = new byte[] { (byte)(t.Width & 0xFF), (byte)(t.Width >> 8), (byte)(t.Height & 0xFF), (byte)(t.Height >> 8), 1, 0 };
                        var sysLen = (int)e.SystemSize;
                        for (int i = 0x18; i + 0x80 <= sysLen; i += 8)
                        {
                            bool ok = true; for (int k = 0; k < 6; k++) if (raw[i + k] != sig[k]) { ok = false; break; }
                            if (!ok) continue;
                            int st = i - 0x18;
                            for (int row = 0; row < 0x80; row += 0x20) Console.WriteLine($"   +{row:X2}: " + BitConverter.ToString(raw, st + row, 0x20).Replace("-", " "));
                            Console.WriteLine();
                        }
                    }
                }
                break;
            }
            case "texexport":
            {
                // texexport <rpf> <inner ytd> <outdir> <name>...: mip0 pixels as raw BGRA "<name>.<w>x<h>.bgra"
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YtdFile(); y.Load(e.File.ExtractFile(e), e);
                Directory.CreateDirectory(a[4]);
                foreach (var t in y.TextureDict.Textures.data_items)
                {
                    if (a.Length > 5 && !a.Skip(5).Any(n => n.Equals(t.Name, StringComparison.OrdinalIgnoreCase))) continue;
                    var px = CodeWalker.Utils.DDSIO.GetPixels(t, 0);
                    if (px == null)
                    {
                        // CodeWalker can't decode it (BC7): write the texture as a DDS instead
                        File.WriteAllBytes(Path.Combine(a[4], $"{t.Name}.dds"), CodeWalker.Utils.DDSIO.GetDDSFile(t));
                        Console.WriteLine($"exported {t.Name} {t.Width}x{t.Height} {t.Format} as DDS (no decoder)");
                        continue;
                    }
                    File.WriteAllBytes(Path.Combine(a[4], $"{t.Name}.{t.Width}x{t.Height}.bgra"), px);
                    Console.WriteLine($"exported {t.Name} {t.Width}x{t.Height} {t.Format}");
                }
                break;
            }
            case "teximport":
            {
                // teximport <rpf> <inner ytd> <texname> <file.dds>: replace one texture's pixels/format, keep name
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YtdFile(); y.Load(e.File.ExtractFile(e), e);
                var t = y.TextureDict.Textures.data_items.First(x => x.Name.Equals(a[4], StringComparison.OrdinalIgnoreCase));
                var nt = CodeWalker.Utils.DDSIO.GetTexture(File.ReadAllBytes(a[5]));
                t.Width = nt.Width; t.Height = nt.Height; t.Depth = nt.Depth; t.Levels = nt.Levels;
                t.Format = nt.Format; t.Stride = nt.Stride; t.Data = nt.Data; t.G9_Format = 0;
                RpfFile.CreateFile(e.Parent, e.Name, y.Save(), true);
                Console.WriteLine($"imported {a[5]} into {t.Name} ({t.Width}x{t.Height} {t.Format}, {t.Levels} levels)");
                break;
            }
            case "extract":
            {
                // extract <rpf> <inner> <out>: raw (decompressed/decrypted) file bytes
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                File.WriteAllBytes(a[4], e.File.ExtractFile(e));
                Console.WriteLine($"extracted {e.Path} -> {a[4]}");
                break;
            }
            case "awcinfo":
            {
                // awcinfo <rpf> <inner awc>: header + per stream chunk types/sizes + format details
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var awc = new AwcFile(); awc.Load(e.File.ExtractFile(e), e);
                Console.WriteLine($"{e.Path}: Magic=0x{awc.Magic:X} Version={awc.Version} Flags=0x{awc.Flags:X} Streams={awc.Streams?.Length} MultiChannel={awc.MultiChannelFlag} SingleChannelEnc={awc.SingleChannelEncryptFlag} Chunked={awc.ChunkIndicesFlag}");
                foreach (var s in awc.Streams ?? new AwcStream[0])
                {
                    var parts = new List<string>();
                    foreach (var c in s.Chunks ?? new AwcChunk[0])
                    {
                        var info = c.ChunkInfo;
                        string extra = "";
                        if (c is AwcFormatChunk fc) extra = $"(codec={fc.Codec} rate={fc.SamplesPerSecond} samples={fc.Samples} hdr={fc.Headroom} loop={fc.LoopPoint})";
                        if (c is AwcGranularGrainsChunk gg) extra = $"(grains={gg.GranularGrains?.Length})";
                        if (c is AwcGranularLoopsChunk gl) extra = $"(loops={gl.GranularLoops?.Length})";
                        if (c is AwcStreamFormatChunk sf) extra = $"(channels={sf.Channels?.Length} blocks={sf.BlockCount} blocksize={sf.BlockSize})";
                        parts.Add($"{info?.Type}:{info?.Size}{extra}");
                    }
                    Console.WriteLine($"  stream {s.Hash} : {string.Join("  ", parts)}");
                }
                break;
            }
            case "synthops":
            {
                // synthops <rpf> <inner dat10>...: per synth counts + opcode usage (with io signature) and undecodable opcodes
                var rpf = Open(a[2], log);
                foreach (var inner in a.Skip(3))
                {
                    var e = Find(rpf, inner);
                    var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                    foreach (var s in rel.RelDatas.OfType<Dat10Synth>())
                    {
                        var ops = new List<string>(); var unknown = new List<int>();
                        var bc = s.Bytecode;
                        for (int i = 0; i + 1 < bc.Length;)
                        {
                            var op = bc[i + 1];
                            if (!Enum.IsDefined(typeof(Dat10Synth.Opcode), (Dat10Synth.Opcode)op)) { unknown.Add(op); break; }
                            int ni = bc[i] >> 4, no = bc[i] & 0xF;
                            int size = Dat10Synth.SizeOf((Dat10Synth.Opcode)op, ni, no);
                            ops.Add($"{(Dat10Synth.Opcode)op}/{ni}{no}");
                            if (size <= 0) { unknown.Add(op); break; }
                            i += size;
                        }
                        Console.WriteLine($"SYNTH {s.NameHash.Hash} buffers={s.BuffersCount} regs={s.RegistersCount} outs={s.OutputsCount} state={s.StateBlocksCount} bclen={s.BytecodeLength} consts={s.ConstantsCount} vars={s.VariablesCount} cost={s.RuntimeCost} unknown=[{string.Join(",", unknown)}]");
                        foreach (var o in ops) Console.WriteLine($"  OP {o}");
                    }
                }
                break;
            }
            case "cmprpf":
            {
                // cmprpf <a.rpf> <b.rpf>: compare every file's extracted bytes
                var ra = Open(a[2], log); var rb = Open(a[3], log);
                string K(RpfEntry e) { var x = e.Path.ToLowerInvariant(); var i = x.IndexOf('\\'); return i < 0 ? "" : x.Substring(i + 1); }
                var fa = All(ra).SelectMany(r => r.AllEntries).OfType<RpfFileEntry>().Where(e => !(e is RpfBinaryFileEntry be && e.NameLower.EndsWith(".rpf"))).ToDictionary(K);
                var fb = All(rb).SelectMany(r => r.AllEntries).OfType<RpfFileEntry>().Where(e => !(e is RpfBinaryFileEntry be && e.NameLower.EndsWith(".rpf"))).ToDictionary(K);
                int same = 0;
                foreach (var k in fa.Keys.Union(fb.Keys).OrderBy(x => x))
                {
                    if (!fa.ContainsKey(k)) { Console.WriteLine($"  only in B: {k}"); continue; }
                    if (!fb.ContainsKey(k)) { Console.WriteLine($"  only in A: {k}"); continue; }
                    var da = fa[k].File.ExtractFile(fa[k]); var db = fb[k].File.ExtractFile(fb[k]);
                    if (da.AsSpan().SequenceEqual(db)) same++; else Console.WriteLine($"  DIFFERS: {k} ({da.Length} vs {db.Length} bytes)");
                }
                Console.WriteLine($"  identical files: {same}");
                break;
            }
            case "relset":
            {
                // relset <rpf> <inner rel> <old hash> <new hash>: replace every MetaHash field equal to old (dat151), save, verify
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                uint oldH = uint.Parse(a[4]), newH = uint.Parse(a[5]); int n = 0;
                foreach (var d in rel.RelDatas)
                    foreach (var p in d.GetType().GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
                        if (p.PropertyType == typeof(MetaHash) && p.CanWrite && ((MetaHash)p.GetValue(d)).Hash == oldH && p.Name != "NameHash")
                        { p.SetValue(d, new MetaHash(newH)); n++; Console.WriteLine($"  {d.GetType().Name}.{p.Name}: {oldH} -> {newH}"); }
                if (n == 0) throw new Exception("no field had that value");
                var saved = rel.Save();
                var check = new RelFile(); check.Load(saved, e);
                if (check.RelDatas.Length != rel.RelDatas.Length) throw new Exception("item count changed");
                RpfFile.CreateFile(e.Parent, e.Name, saved, true);
                Console.WriteLine($"relset: {n} field(s) changed in {e.Path}");
                break;
            }
            case "relfield":
            {
                // relfield <rpf> <inner rel> <dat151 type> <field> <value>: set a numeric field on every object of that
                // type. Refuses unless CodeWalker re-saves the file byte for byte first, and checks afterwards that only
                // the bytes of that field changed.
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var orig = e.File.ExtractFile(e);
                var rel = new RelFile(); rel.Load(orig, e);
                var resaved = rel.Save();
                if (!resaved.AsSpan().SequenceEqual(orig)) throw new Exception("CodeWalker does not re-save this file byte for byte; not touching it");
                var type = Enum.Parse<Dat151RelType>(a[4]);
                int n = 0, size = 0;
                foreach (var d in rel.RelDatas.Where(x => (Dat151RelType)x.TypeID == type))
                {
                    var p = d.GetType().GetProperty(a[5]) ?? throw new Exception($"{type} has no field {a[5]}");
                    var old = p.GetValue(d);
                    p.SetValue(d, Convert.ChangeType(a[6], p.PropertyType, System.Globalization.CultureInfo.InvariantCulture));
                    size = System.Runtime.InteropServices.Marshal.SizeOf(p.PropertyType);
                    Console.WriteLine($"  {d.Name ?? d.NameHash.ToString()} {a[5]}: {old} -> {p.GetValue(d)}"); n++;
                }
                if (n == 0) throw new Exception($"no {type} object in this file");
                var saved = rel.Save();
                if (saved.Length != orig.Length) throw new Exception("file size changed");
                int diff = 0; for (int i = 0; i < orig.Length; i++) if (orig[i] != saved[i]) diff++;
                if (diff > n * size) throw new Exception($"{diff} bytes changed, expected at most {n * size}");
                var check = new RelFile(); check.Load(saved, e);
                if (check.RelDatas.Length != rel.RelDatas.Length) throw new Exception("item count changed");
                RpfFile.CreateFile(e.Parent, e.Name, saved, true);
                Console.WriteLine($"relfield: {n} object(s), {diff} byte(s) changed in {e.Path}");
                break;
            }
            case "relresave":
            {
                // relresave <rpf> <inner rel> <out.rel>: load with current CodeWalker, Save(), report byte differences
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var orig = e.File.ExtractFile(e);
                var rel = new RelFile(); rel.Load(orig, e);
                var saved = rel.Save();
                File.WriteAllBytes(a[4], saved);
                int diffs = 0, first = -1;
                for (int i = 0; i < Math.Min(orig.Length, saved.Length); i++) if (orig[i] != saved[i]) { diffs++; if (first < 0) first = i; }
                Console.WriteLine($"{a[3]}: orig {orig.Length} bytes, resaved {saved.Length} bytes, differing bytes {diffs}, first diff @{first}");
                if (diffs > 0)
                {
                    // attribute differing bytes to items (data block starts at file offset 8)
                    var byType = new Dictionary<string, (int items, int bytes)>();
                    foreach (var d in rel.RelDatas)
                    {
                        int s = (int)d.DataOffset + 8, n = (int)d.DataLength, cnt = 0;
                        for (int i = s; i < s + n && i < orig.Length && i < saved.Length; i++) if (orig[i] != saved[i]) cnt++;
                        if (cnt == 0) continue;
                        var tn = rel.RelType == RelDatFileType.Dat151 ? ((Dat151RelType)d.TypeID).ToString() : d.TypeID.ToString();
                        var cur = byType.TryGetValue(tn, out var v) ? v : (0, 0);
                        byType[tn] = (cur.Item1 + 1, cur.Item2 + cnt);
                    }
                    foreach (var kv in byType.OrderByDescending(k => k.Value.bytes)) Console.WriteLine($"   diff in {kv.Key}: {kv.Value.items} items, {kv.Value.bytes} bytes");
                }
                var rel2 = new RelFile(); rel2.Load(saved, e);
                Console.WriteLine($"   resaved: items={rel2.RelDatas?.Length} hashtable={rel2.HashTableCount} packtable={rel2.PackTableCount} (orig hashtable={rel.HashTableCount} packtable={rel.PackTableCount})");
                break;
            }
            case "relht":
            {
                // relht <rpf> <inner rel> [type filter]: per type, the hash table offsets relative to each item's payload (DataOffset+8+4)
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                var hto = rel.HashTableOffsets ?? new uint[0];
                var items = rel.RelDatas.OrderBy(d => d.DataOffset).ToArray();
                var sets = new Dictionary<string, Dictionary<string, int>>();
                foreach (var d in items)
                {
                    var tn = ((Dat151RelType)d.TypeID).ToString();
                    if (a.Length > 4 && tn != a[4]) continue;
                    uint start = d.DataOffset + 8, end = start + d.DataLength;
                    var rels = hto.Where(o => o >= start && o < end).Select(o => (int)(o - start - 4)).OrderBy(x => x).ToArray();
                    var key = string.Join(",", rels);
                    if (!sets.TryGetValue(tn, out var m)) sets[tn] = m = new Dictionary<string, int>();
                    m[key] = m.TryGetValue(key, out var c) ? c + 1 : 1;
                }
                foreach (var kv in sets.OrderBy(k => k.Key))
                    foreach (var s in kv.Value.OrderByDescending(x => x.Value))
                        Console.WriteLine($"{kv.Key,-34} x{s.Value,-4} [{s.Key}]");
                break;
            }
            case "reldump":
            {
                // reldump <rpf> <inner rel> [summary]: items with type and data length (summary = per type length histogram)
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                Console.WriteLine($"{e.Path}: RelType={rel.RelType} items={rel.RelDatas?.Length}");
                if (Environment.GetEnvironmentVariable("HEADER") == "1")
                    foreach (var p in rel.GetType().GetProperties())
                    {
                        object v; try { v = p.GetValue(rel); } catch { continue; }
                        if (v == null) { Console.WriteLine($"  hdr {p.Name} = null"); continue; }
                        if (v is Array arr) { Console.WriteLine($"  hdr {p.Name}.Length = {arr.Length}"); continue; }
                        if (v is string || v.GetType().IsValueType) Console.WriteLine($"  hdr {p.Name} = {v}");
                    }
                string TypeName(RelData d) => rel.RelType == RelDatFileType.Dat151 ? ((Dat151RelType)d.TypeID).ToString()
                    : rel.RelType == RelDatFileType.Dat54DataEntries ? ((Dat54SoundType)d.TypeID).ToString() : d.TypeID.ToString();
                if (a.Length > 4)
                {
                    foreach (var g in rel.RelDatas.GroupBy(TypeName).OrderBy(g => g.Key))
                        Console.WriteLine($"  {g.Key,-36} n={g.Count(),-5} lengths={string.Join(",", g.Select(x => x.DataLength).Distinct().OrderBy(x => x).Take(8))}");
                }
                else foreach (var d in rel.RelDatas)
                {
                    Console.WriteLine($"  {TypeName(d),-36} {d.Name ?? d.NameHash.ToString(),-40} len={d.DataLength}");
                    if (Environment.GetEnvironmentVariable("FIELDS") == "1" && rel.RelType == RelDatFileType.Dat151)
                        foreach (var p in d.GetType().GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.DeclaredOnly))
                        {
                            object v; try { v = p.GetValue(d); } catch { continue; }
                            if (v is MetaHash mh) Console.WriteLine($"      {p.Name} = hash {mh.Hash}");
                            else if (v != null && (v.GetType().IsValueType || v is string)) Console.WriteLine($"      {p.Name} = {v}");
                        }
                }
                break;
            }
            case "texhdr":
            {
                // texhdr <rpf>: one line per texture (every .ytd, plus textures embedded in .yft/.ydr) with the
                // gen9 header fields that matter: format, size, levels, G9_Flags, usage bytes, +0x23
                var rpf = Open(a[2], log);
                foreach (var e in Entries(rpf).OfType<RpfResourceFileEntry>())
                {
                    var n = e.NameLower; Texture[] texs = null;
                    try
                    {
                        if (n.EndsWith(".ytd")) { var y = new YtdFile(); y.Load(e.File.ExtractFile(e), e); texs = y.TextureDict?.Textures?.data_items; }
                        else if (n.EndsWith(".yft")) { var y = new YftFile(); y.Load(e.File.ExtractFile(e), e); texs = y.Fragment?.Drawable?.ShaderGroup?.TextureDictionary?.Textures?.data_items; }
                        else if (n.EndsWith(".ydr")) { var y = new YdrFile(); y.Load(e.File.ExtractFile(e), e); texs = y.Drawable?.ShaderGroup?.TextureDictionary?.Textures?.data_items; }
                    }
                    catch (Exception ex) { Console.WriteLine($"{e.Path}: {ex.Message}"); continue; }
                    foreach (var t in texs ?? new Texture[0])
                    {
                        var h = RtHeader(e, t);
                        string hx(int o, int len) => h == null ? "?" : BitConverter.ToString(h, o, len).Replace("-", "");
                        Console.WriteLine($"{Path.GetFileName(e.Path)}\t{t.Name}\t{t.Format}\t{t.Width}x{t.Height}\tlv={t.Levels}\tflags=0x{t.G9_Flags:X}\tusage={t.Usage}/{t.G9_UsageData:X}\t+1C={hx(0x1C, 8)}\t+48={hx(0x48, 0x10)}\t+60={hx(0x60, 0x20)}");
                    }
                }
                break;
            }
            case "vehcount":
            {
                // vehcount [mods/update dir]: vehicle model infos the game registers, base (common.rpf) vs DLC
                // (official dlcpacks + dlc_patch overrides in update.rpf, and optionally the enabled add-on packs),
                // to compare with MaxVehicleModelInfos / MaxExtraVehicleModelInfos in gameconfig.xml
                HashSet<string> Models(RpfFile r, Func<RpfFileEntry, bool> keep)
                {
                    var set = new HashSet<string>();
                    foreach (var e in Entries(r).OfType<RpfFileEntry>().Where(f => f.NameLower == "vehicles.meta" && keep(f)))
                        foreach (Match m in Regex.Matches(System.Text.Encoding.UTF8.GetString(e.File.ExtractFile(e)), @"<modelName>\s*([^<\s]+)\s*</modelName>"))
                            set.Add(m.Groups[1].Value.ToLowerInvariant());
                    return set;
                }
                var baseSet = Models(Open(Path.Combine(game, "common.rpf"), log), _ => true);
                var dlc = new HashSet<string>();
                foreach (var d in Directory.GetDirectories(Path.Combine(game, "update", "x64", "dlcpacks")))
                    if (File.Exists(Path.Combine(d, "dlc.rpf"))) try { dlc.UnionWith(Models(Open(Path.Combine(d, "dlc.rpf"), log), _ => true)); } catch { }
                var upd = Models(Open(Path.Combine(game, "update", "update.rpf"), log), _ => true);
                Console.WriteLine($"base (common.rpf): {baseSet.Count}");
                Console.WriteLine($"official DLC packs: {dlc.Count} ({dlc.Except(baseSet).Count()} not in base)");
                Console.WriteLine($"update.rpf vehicles.meta: {upd.Count} ({upd.Except(baseSet).Except(dlc).Count()} not in base or DLC)");
                var vanilla = new HashSet<string>(baseSet); vanilla.UnionWith(dlc); vanilla.UnionWith(upd);
                Console.WriteLine($"vanilla total: {vanilla.Count}, of them non-base: {vanilla.Except(baseSet).Count()}");
                if (a.Length > 2)
                {
                    var list = Text(Entries(Open(Path.Combine(a[2], "update.rpf"), log)).OfType<RpfFileEntry>().First(e => e.Path.ToLowerInvariant().EndsWith("common\\data\\dlclist.xml")));
                    var add = new HashSet<string>();
                    foreach (Match m in Regex.Matches(list, @"dlcpacks:/([^/<]+)/"))
                    {
                        var f = Path.Combine(a[2], "x64", "dlcpacks", m.Groups[1].Value, "dlc.rpf");
                        if (File.Exists(f)) add.UnionWith(Models(Open(f, log), _ => true).Except(vanilla));
                    }
                    Console.WriteLine($"enabled add-on models: {add.Count} ({string.Join(" ", add)}) -> non-base total {vanilla.Except(baseSet).Count() + add.Count}");
                }
                break;
            }
            case "gamegrep":
            {
                // gamegrep <word>...: which game data files mention each word (text .meta/.xml/.dat, or the
                // joaat hash of the lowercased word inside binary .ymt/.pso). Scans common.rpf, update.rpf and official dlcpacks.
                var words = a.Skip(2).ToArray();
                var hashes = words.Select(w => BitConverter.GetBytes(JenkHash.GenHash(w.ToLowerInvariant()))).ToArray();
                var hits = words.ToDictionary(w => w, w => new List<string>());
                void Scan(RpfFile r)
                {
                    foreach (var e in Entries(r).OfType<RpfFileEntry>())
                    {
                        var n = e.NameLower;
                        bool text = n.EndsWith(".meta") || n.EndsWith(".xml") || n.EndsWith(".dat");
                        bool bin = n.EndsWith(".ymt") || n.EndsWith(".pso");
                        if (!text && !bin) continue;
                        byte[] data; try { data = e.File.ExtractFile(e); } catch { continue; }
                        if (data == null) continue;
                        var s = text ? System.Text.Encoding.UTF8.GetString(data) : null;
                        for (int i = 0; i < words.Length; i++)
                        {
                            bool hit = text ? s.Contains(words[i], StringComparison.OrdinalIgnoreCase) : data.AsSpan().IndexOf(hashes[i]) >= 0 || data.AsSpan().IndexOf(hashes[i].Reverse().ToArray()) >= 0;
                            if (hit) hits[words[i]].Add(e.Path);
                        }
                    }
                }
                foreach (var f in new[] { "common.rpf", Path.Combine("update", "update.rpf") })
                    if (File.Exists(Path.Combine(game, f))) try { Scan(Open(Path.Combine(game, f), log)); } catch (Exception ex) { Console.WriteLine($"  ! {f}: {ex.Message}"); }
                foreach (var d in Directory.GetDirectories(Path.Combine(game, "update", "x64", "dlcpacks")))
                    if (File.Exists(Path.Combine(d, "dlc.rpf"))) try { Scan(Open(Path.Combine(d, "dlc.rpf"), log)); } catch { }
                foreach (var w in words)
                    Console.WriteLine($"{w}: {hits[w].Count} file(s){(hits[w].Count > 0 ? " e.g. " + string.Join(", ", hits[w].Take(3)) : "")}");
                break;
            }
            case "relstats":
            {
                // relstats <dat151 type> <field>...: distribution of numeric fields over every official object of that
                // type (base game + official dlcpacks), e.g. relstats GranularEngineAudioSettings MasterVolume
                var type = Enum.Parse<Dat151RelType>(a[2]);
                var fields = a.Skip(3).ToArray();
                var vals = fields.ToDictionary(f => f, f => new List<double>());
                void Scan(RpfFile r)
                {
                    foreach (var e in Entries(r).OfType<RpfFileEntry>().Where(f => f.NameLower.EndsWith(".dat151.rel")))
                    {
                        try
                        {
                            var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                            foreach (var d in rel.RelDatas.Where(x => (Dat151RelType)x.TypeID == type))
                                foreach (var f in fields)
                                {
                                    var p = d.GetType().GetProperty(f); if (p == null) continue;
                                    vals[f].Add(Convert.ToDouble(p.GetValue(d)));
                                }
                        }
                        catch { }
                    }
                }
                Scan(Open(Path.Combine(game, "update", "update.rpf"), log));
                if (File.Exists(Path.Combine(game, "x64e.rpf"))) Scan(Open(Path.Combine(game, "x64e.rpf"), log));
                foreach (var d in Directory.GetDirectories(Path.Combine(game, "update", "x64", "dlcpacks")))
                    if (File.Exists(Path.Combine(d, "dlc.rpf"))) try { Scan(Open(Path.Combine(d, "dlc.rpf"), log)); } catch { }
                foreach (var f in fields)
                {
                    var v = vals[f].OrderBy(x => x).ToList();
                    if (v.Count == 0) { Console.WriteLine($"{f}: no values"); continue; }
                    double P(double q) => v[(int)Math.Round(q * (v.Count - 1))];
                    Console.WriteLine($"{f}: n={v.Count} min={v[0]} p10={P(.1)} p25={P(.25)} median={P(.5)} p75={P(.75)} p90={P(.9)} max={v[^1]}");
                }
                break;
            }
            case "relfind":
            {
                // relfind <hash>...: which game rel file (update.rpf, x64e.rpf, official dlcpacks) defines each audio object
                var want = new HashSet<uint>(a.Skip(2).Select(uint.Parse));
                void Scan(RpfFile r)
                {
                    foreach (var e in Entries(r).OfType<RpfFileEntry>().Where(f => f.NameLower.EndsWith(".rel")))
                    {
                        try
                        {
                            var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                            string TN(RelData d) => rel.RelType == RelDatFileType.Dat151 ? ((Dat151RelType)d.TypeID).ToString()
                                : rel.RelType == RelDatFileType.Dat54DataEntries ? ((Dat54SoundType)d.TypeID).ToString() : $"{rel.RelType}:{d.TypeID}";
                            foreach (var d in rel.RelDatas) if (want.Contains(d.NameHash.Hash)) Console.WriteLine($"  {d.NameHash.Hash} {TN(d)} in {e.Path}");
                        }
                        catch { }
                    }
                }
                Scan(Open(Path.Combine(game, "update", "update.rpf"), log));
                if (File.Exists(Path.Combine(game, "x64e.rpf"))) Scan(Open(Path.Combine(game, "x64e.rpf"), log));
                foreach (var d in Directory.GetDirectories(Path.Combine(game, "update", "x64", "dlcpacks")))
                    if (File.Exists(Path.Combine(d, "dlc.rpf"))) try { Scan(Open(Path.Combine(d, "dlc.rpf"), log)); } catch { }
                break;
            }
            case "relwaves":
            {
                // relwaves <rpf>: every wave a dat54 sound plays (SimpleSound / GranularSound channels),
                // checked against the .awc files in the same pack. Container = joaat("<folder>/<awc name>"),
                // file = stream id (hash & 0x1FFFFFFF).
                var rpf = Open(a[2], log);
                var all = Entries(rpf).OfType<RpfFileEntry>().ToList();
                var banks = new Dictionary<uint, (string path, HashSet<uint> ids)>();
                foreach (var e in all.Where(f => f.NameLower.EndsWith(".awc")))
                {
                    var awc = new AwcFile(); awc.Load(e.File.ExtractFile(e), e);
                    var parts = e.Path.ToLowerInvariant().Replace('\\', '/').Split('/');
                    var key = parts[^2] + "/" + Path.GetFileNameWithoutExtension(parts[^1]);
                    banks[JenkHash.GenHash(key)] = (key, new HashSet<uint>((awc.Streams ?? new AwcStream[0]).Select(s => s.Hash.Hash & 0x1FFFFFFF)));
                }
                foreach (var b in banks) Console.WriteLine($"  bank {b.Value.path} hash={b.Key} streams={b.Value.ids.Count}");
                int ok = 0, missing = 0, foreign = 0;
                foreach (var e in all.Where(f => f.NameLower.EndsWith(".dat54.rel")))
                {
                    var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                    var refs = new List<(string obj, string slot, uint c, uint f)>();
                    foreach (var d in rel.RelDatas)
                    {
                        var n = d.Name ?? d.NameHash.ToString();
                        if (d is Dat54SimpleSound ss) refs.Add((n, "SimpleSound", ss.ContainerName.Hash, ss.FileName.Hash));
                        if (d is Dat54GranularSound gs)
                        {
                            var chans = new[] { gs.Channel0, gs.Channel1, gs.Channel2, gs.Channel3, gs.Channel4, gs.Channel5 };
                            for (int i = 0; i < chans.Length; i++) if (chans[i] != null) refs.Add((n, $"Granular.Channel{i}", chans[i].ContainerName.Hash, chans[i].FileName.Hash));
                        }
                    }
                    foreach (var r in refs)
                    {
                        if (!banks.TryGetValue(r.c, out var bk)) { foreign++; Console.WriteLine($"  OTHER-BANK {r.obj} {r.slot}: container {r.c} file {r.f} (not in this pack)"); continue; }
                        if (bk.ids.Contains(r.f & 0x1FFFFFFF)) ok++;
                        else { missing++; Console.WriteLine($"  MISSING {r.obj} {r.slot}: {bk.path} has no stream {r.f & 0x1FFFFFFF}"); }
                    }
                }
                Console.WriteLine($"waves: {ok} found, {missing} missing, {foreign} in other banks");
                break;
            }
            case "yft2xml":
            {
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YftFile(); y.Load(e.File.ExtractFile(e), e);
                Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(a[4])));
                File.WriteAllText(a[4], YftXml.GetXml(y, Path.GetDirectoryName(Path.GetFullPath(a[4]))));
                Console.WriteLine($"exported {e.Path} -> {a[4]}");
                break;
            }
            case "xml2yft":
            {
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = XmlYft.GetYft(File.ReadAllText(a[4]), Path.GetDirectoryName(Path.GetFullPath(a[4])));
                var bytes = y.Save();
                RpfFile.CreateFile(e.Parent, e.Name, bytes, true);
                Console.WriteLine($"imported {a[4]} -> {e.Path} ({bytes.Length} bytes)");
                break;
            }
            case "fixrt":
            {
                // script_rt_* render-target textures must be uncompressed A8R8G8B8 with one level on Enhanced
                var rpf = Open(a[2], log);
                var e = (RpfResourceFileEntry)Find(rpf, a[3]);
                var y = new YtdFile(); y.Load(e.File.ExtractFile(e), e);
                int n = 0;
                foreach (var t in y.TextureDict.Textures.data_items)
                {
                    if (!t.Name.StartsWith("script_rt", StringComparison.OrdinalIgnoreCase)) continue;
                    // values copied from all 41 vanilla Enhanced script_rt_dials_* textures
                    if (t.Format != TextureFormat.D3DFMT_A8R8G8B8 || t.Levels != 1)
                    {
                        t.Format = TextureFormat.D3DFMT_A8R8G8B8;
                        t.G9_Format = 0;
                        t.Levels = 1;
                        t.Stride = (ushort)(t.Width * 4);
                        t.Data.FullData = new byte[t.Width * t.Height * 4];
                    }
                    else if (t.Usage == TextureUsage.SKIPPROCESSING && t.G9_Unknown_23h == 0 && t.G9_UsageData == 0x40021A) continue;
                    t.G9_Flags = 0x00260228;
                    t.Usage = TextureUsage.SKIPPROCESSING;
                    t.G9_UsageData = 0x40021A;
                    t.G9_Unknown_23h = 0;
                    Console.WriteLine($"fixed {t.Name} {t.Width}x{t.Height}");
                    n++;
                }
                if (n > 0)
                {
                    var saved = y.Save();
                    // EnsureGen9() forces G9_Unknown_23h to 0x28; vanilla render targets have 0. Patch the
                    // gen9 TextureBase struct in place: G9_UsageData at +0x40, Width at +0x18, Levels at +0x22, 23h at +0x23.
                    var body = ResourceBuilder.Decompress(saved.Skip(16).ToArray());
                    int patched = 0;
                    for (int i = 0x40; i + 4 <= body.Length; i += 4)
                    {
                        if (BitConverter.ToUInt32(body, i) != 0x40021A) continue;
                        int s = i - 0x40;
                        if (body[s + 0x22] != 1 || body[s + 0x23] != 0x28) continue;
                        body[s + 0x23] = 0; patched++;
                    }
                    if (patched != n) throw new Exception($"patched {patched} of {n} textures");
                    var outb = saved.Take(16).Concat(ResourceBuilder.Compress(body)).ToArray();
                    var ne = (RpfResourceFileEntry)RpfFile.CreateFile(e.Parent, e.Name, outb, true);
                    var back = ne.File.ExtractFile(ne);
                    if (!back.SequenceEqual(body)) throw new Exception("stored data differs");
                    Console.WriteLine($"patched G9_Unknown_23h on {patched} texture(s)");
                }
                break;
            }
            case "put":
            {
                EnsureEncryptTables();   // needed when the target is inside an NG-encrypted archive (update.rpf)
                var rpf = Open(a[2], log);
                var e = Find(rpf, a[3]);
                RpfFile.CreateFile(e.Parent, e.Name, File.ReadAllBytes(a[4]), true);
                Console.WriteLine($"replaced {e.Path}");
                break;
            }
            case "convert":
            {
                File.Copy(a[2], a[3], true);
                var rpf = Open(a[3], log);
                var list = All(rpf); list.Reverse();
                var changedParents = new HashSet<RpfFile>();
                int conv = 0, fail = 0;
                foreach (var t in list)
                {
                    var changed = changedParents.Contains(t);
                    var ents = t.AllEntries.OfType<RpfResourceFileEntry>().OrderBy(x => x.FileOffset).ToList();
                    foreach (var rfe in ents)
                    {
                        if (!Gen9Converter.RequiresConversion(rfe)) continue;
                        var data = t.ExtractFile(rfe);
                        data = ResourceBuilder.Compress(data);
                        data = ResourceBuilder.AddResourceHeader(rfe, data);
                        var outd = Gen9Converter.TryConvert(data, Path.GetExtension(rfe.NameLower), log, rfe.Path, false, out var ok);
                        if (!ok || outd == null) { Console.WriteLine($"ERROR converting {rfe.Path}"); fail++; continue; }
                        RpfFile.CreateFile(rfe.Parent, rfe.Name, outd, true);
                        conv++; changed = true;
                    }
                    if (changed)
                    {
                        RpfFile.Defragment(t, null, false);
                        if (t.Parent != null) changedParents.Add(t.Parent);
                    }
                }
                Console.WriteLine($"converted={conv} failed={fail}");
                if (fail > 0) Environment.Exit(2);
                break;
            }
            case "dlclist":
            {
                EnsureEncryptTables();

                var rpf = Open(a[2], log);
                var e = Find(rpf, "common\\data\\dlclist.xml");
                var xml = Encoding.UTF8.GetString(e.File.ExtractFile(e));
                var remove = a[3].StartsWith("-");
                var item = $"<Item>{a[3].TrimStart('-')}</Item>";
                if (remove)
                {
                    var lines = xml.Split('\n').ToList();
                    var n = lines.RemoveAll(l => l.Trim() == item);
                    if (n == 0) { Console.WriteLine("not present"); break; }
                    xml = string.Join("\n", lines);
                }
                else
                {
                    if (xml.Contains(item)) { Console.WriteLine("already present"); break; }
                    var idx = xml.LastIndexOf("</Paths>");
                    if (idx < 0) throw new Exception("no </Paths> in dlclist.xml");
                    xml = xml.Insert(idx, "\t" + item + "\r\n\t");
                }
                RpfFile.CreateFile(e.Parent, e.Name, Encoding.UTF8.GetBytes(xml), true);
                Console.WriteLine((remove ? "removed " : "added ") + item);
                // Re-open from disk to verify the archive still parses and has the new line.
                var check = Open(a[2], log);
                var ce = Find(check, "common\\data\\dlclist.xml");
                var cxml = Encoding.UTF8.GetString(ce.File.ExtractFile(ce));
                if (cxml.Contains(item) == remove) throw new Exception("verification failed");
                Console.WriteLine($"verified: {check.AllEntries.Count} entries, dlclist ok");
                break;
            }
        }
    }
    static void PrintTex(TextureDictionary td, string ind)
    {
        var tex = td?.Textures?.data_items;
        if (tex == null) return;
        foreach (var t in tex)
            if (t.Name.StartsWith("script_rt", StringComparison.OrdinalIgnoreCase) || Environment.GetEnvironmentVariable("ALLTEX") == "1")
                Console.WriteLine($"{ind}tex {t.Name} {t.Width}x{t.Height} fmt={t.Format} levels={t.Levels} g9flags=0x{t.G9_Flags:X}");
        Console.WriteLine($"{ind}({tex.Length} textures)");
    }
    static RpfFile Open(string path, Action<string> log)
    {
        var rpf = new RpfFile(Path.GetFullPath(path), Path.GetFileName(path));
        rpf.ScanStructure(null, log);
        return rpf;
    }
    static List<RpfFile> All(RpfFile root)
    {
        var res = new List<RpfFile>(); var st = new Stack<RpfFile>(); st.Push(root);
        while (st.Count > 0) { var t = st.Pop(); res.Add(t); if (t.Children != null) foreach (var c in t.Children) st.Push(c); }
        return res;
    }
    static RpfFileEntry Find(RpfFile root, string inner)
    {
        foreach (var r in All(root))
            foreach (var e in r.AllEntries)
                if (e is RpfFileEntry fe && e.Path.EndsWith(inner, StringComparison.OrdinalIgnoreCase) && e.File == r) return fe;
        throw new Exception("not found: " + inner);
    }
}
