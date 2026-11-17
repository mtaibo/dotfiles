using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using CodeWalker.GameFiles;
using CodeWalker.Core.Utils;

// Offline verifier for a GTA V Enhanced mods/update folder: update.rpf + x64/dlcpacks/*/dlc.rpf.
// Every rule encodes something that broke (or could break) this setup; see the summary at the end.
partial class P
{
    static int pass, warn, fail;
    static void Pass(string s) { pass++; Console.WriteLine($"  PASS {s}"); }
    static void Warn(string s) { warn++; Console.WriteLine($"  WARN {s}"); }
    static void Fail(string s) { fail++; Console.WriteLine($"  FAIL {s}"); }

    static uint Joaat(string s)
    {
        uint h = 0;
        foreach (var c in s.ToLowerInvariant()) { h += (byte)c; h += h << 10; h ^= h >> 6; }
        h += h << 3; h ^= h >> 11; h += h << 15; return h;
    }

    static string Text(RpfFileEntry e) => Encoding.UTF8.GetString(e.File.ExtractFile(e)).TrimStart('﻿');

    static IEnumerable<RpfEntry> Entries(RpfFile root) => All(root).SelectMany(r => r.AllEntries);

    // path of an entry relative to its root pack, lowercased, '\' separated, without the root name
    static string Rel(RpfEntry e) { var p = e.Path.ToLowerInvariant(); var i = p.IndexOf('\\'); return i < 0 ? "" : p.Substring(i + 1); }

    static int RunVerify(string game, string modsUpdate, Action<string> log)
    {
        var quiet = new Action<string>(_ => { });
        Console.WriteLine($"== Verifying {modsUpdate}");

        // ---------- reference data from the unmodified game ----------
        Console.WriteLine("\n[reference] indexing the game");
        var vanillaUpdate = Open(Path.Combine(game, "update", "update.rpf"), quiet);
        var vanillaDlcList = Text(Find(vanillaUpdate, "common\\data\\dlclist.xml"));
        var vanillaItems = Regex.Matches(vanillaDlcList, "<Item>([^<]+)</Item>").Select(m => m.Groups[1].Value.Trim()).ToList();
        Console.WriteLine($"  vanilla dlclist items: {vanillaItems.Count}");

        // audio object names and vanilla vehicle model names / device names across base game + every official DLC
        var audioNames = new HashSet<uint>();
        var carAudioNames = new HashSet<uint>();
        var vanillaModels = new HashSet<string>();
        var vanillaDevices = new HashSet<string>();
        var vanillaKits = new HashSet<int>();
        void IndexRels(RpfFile root)
        {
            foreach (var e in Entries(root).OfType<RpfFileEntry>())
            {
                var n = e.NameLower;
                if (n.EndsWith(".rel"))
                {
                    try
                    {
                        var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                        foreach (var d in rel.RelDatas)
                        {
                            audioNames.Add(d.NameHash.Hash);
                            if (rel.RelType == RelDatFileType.Dat151 && (Dat151RelType)d.TypeID == Dat151RelType.CarAudioSettings) carAudioNames.Add(d.NameHash.Hash);
                        }
                    }
                    catch { }
                }
                else if (n == "carcols.meta" || n.EndsWith("carcols.ymt"))
                {
                    try { foreach (Match m in Regex.Matches(Text(e), @"<kitName>[^<]*</kitName>\s*<id value=""(\d+)""")) vanillaKits.Add(int.Parse(m.Groups[1].Value)); } catch { }
                }
                else if (n.EndsWith(".yft") && e.Path.ToLowerInvariant().Contains("vehicles.rpf") && !n.EndsWith("_hi.yft"))
                    vanillaModels.Add(Path.GetFileNameWithoutExtension(n));
            }
        }
        IndexRels(vanillaUpdate);
        foreach (var x in new[] { "x64e.rpf" }) { var p = Path.Combine(game, x); if (File.Exists(p)) IndexRels(Open(p, quiet)); }
        var vanillaPackDir = Path.Combine(game, "update", "x64", "dlcpacks");
        foreach (var d in Directory.GetDirectories(vanillaPackDir))
        {
            var f = Path.Combine(d, "dlc.rpf"); if (!File.Exists(f)) continue;
            try
            {
                var r = Open(f, quiet); IndexRels(r);
                var s2 = Entries(r).OfType<RpfFileEntry>().FirstOrDefault(e => Rel(e) == "setup2.xml");
                if (s2 != null) { var m = Regex.Match(Text(s2), "<deviceName>([^<]+)</deviceName>"); if (m.Success) vanillaDevices.Add(m.Groups[1].Value.ToLowerInvariant()); }
            }
            catch { }
        }
        Console.WriteLine($"  vanilla mod kit ids: {vanillaKits.Count} (max {(vanillaKits.Count > 0 ? vanillaKits.Max() : 0)})");
        Console.WriteLine($"  audio objects: {audioNames.Count}, car audio settings: {carAudioNames.Count}, vanilla vehicle models: {vanillaModels.Count}, vanilla DLC devices: {vanillaDevices.Count}");

        // vanilla script_rt render-target header (the bytes Enhanced expects)
        byte[] rtRef = null;
        {
            var x64e = Open(Path.Combine(game, "x64e.rpf"), quiet);
            var e = (RpfResourceFileEntry)Entries(x64e).OfType<RpfResourceFileEntry>().First(z => z.NameLower == "vehicles_banshee_interior.ytd");
            rtRef = RtHeader(e, "script_rt_dials_banshee");
        }
        Console.WriteLine($"  vanilla script_rt header captured: {(rtRef != null ? "yes" : "NO")}");

        // ---------- global: update.rpf + dlclist ----------
        Console.WriteLine("\n[global] mods/update/update.rpf and dlclist.xml");
        var modsRpfPath = Path.Combine(modsUpdate, "update.rpf");
        RpfFile modsRpf = null; string dlcXml = null;
        try { modsRpf = Open(modsRpfPath, quiet); Pass($"update.rpf opens ({modsRpf.AllEntries.Count} root entries)"); }
        catch (Exception ex) { Fail($"update.rpf does not open: {ex.Message}"); return Summary(); }
        var vanillaCount = Entries(vanillaUpdate).Count();
        var modsCount = Entries(modsRpf).Count();
        if (vanillaCount == modsCount) Pass($"update.rpf has the same {modsCount} entries as the game's"); else Fail($"update.rpf entry count {modsCount} != game's {vanillaCount}");
        try { dlcXml = Text(Find(modsRpf, "common\\data\\dlclist.xml")); var xd = new XmlDocument(); xd.LoadXml(dlcXml); Pass("dlclist.xml is well-formed XML"); }
        catch (Exception ex) { Fail($"dlclist.xml invalid: {ex.Message}"); return Summary(); }
        var items = Regex.Matches(dlcXml, "<Item>([^<]+)</Item>").Select(m => m.Groups[1].Value.Trim()).ToList();
        var dups = items.GroupBy(i => i.ToLowerInvariant()).Where(g => g.Count() > 1).Select(g => g.Key).ToList();
        var vanDups = vanillaItems.GroupBy(i => i.ToLowerInvariant()).Where(g => g.Count() > 1).Select(g => g.Key).ToHashSet();
        var ourDups = dups.Where(d => !vanDups.Contains(d)).ToList();
        foreach (var d in dups.Where(vanDups.Contains)) Console.WriteLine($"  INFO duplicate item {d} comes from the game's own dlclist (left as is)");
        if (ourDups.Count == 0) Pass("no duplicate dlclist items added by us"); else Fail($"duplicate dlclist items added by us: {string.Join(", ", ourDups)}");
        var missingVanilla = vanillaItems.Where(v => !items.Contains(v)).ToList();
        if (missingVanilla.Count == 0) Pass($"all {vanillaItems.Count} official dlclist items still present"); else Fail($"official items missing: {string.Join(", ", missingVanilla)}");
        var custom = items.Where(i => !vanillaItems.Contains(i)).ToList();
        Console.WriteLine($"  custom items: {string.Join(", ", custom)}");
        var packDir = Path.Combine(modsUpdate, "x64", "dlcpacks");
        var enabled = new List<(string name, string path)>();
        foreach (var it in custom)
        {
            var m = Regex.Match(it, @"^dlcpacks:[/\\]?([^/\\]+)[/\\]?$", RegexOptions.IgnoreCase);
            if (!m.Success) { Fail($"custom item '{it}' has an unexpected format"); continue; }
            var name = m.Groups[1].Value;
            var f = Path.Combine(packDir, name, "dlc.rpf");
            if (File.Exists(f)) { Pass($"'{it}' -> {name}/dlc.rpf exists"); enabled.Add((name, f)); }
            else Fail($"'{it}' listed but {f} is missing");
        }
        foreach (var d in Directory.Exists(packDir) ? Directory.GetDirectories(packDir) : new string[0])
        {
            var n = Path.GetFileName(d);
            if (!enabled.Any(x => x.name.Equals(n, StringComparison.OrdinalIgnoreCase))) Console.WriteLine($"  INFO pack folder '{n}' exists but is not in dlclist (disabled)");
        }

        // ---------- per pack ----------
        var devices = new Dictionary<string, string>();
        var models = new Dictionary<string, string>();
        var packCarAudio = new HashSet<uint>();
        var packAudioNames = new HashSet<uint>();
        var packKits = new HashSet<int>();
        var opened = new List<(string name, RpfFile rpf)>();
        foreach (var (name, path) in enabled)
        {
            Console.WriteLine($"\n[pack {name}]");
            RpfFile rpf;
            try { rpf = Open(path, quiet); Pass($"dlc.rpf opens, {All(rpf).Count} archive(s), {Entries(rpf).Count()} entries"); }
            catch (Exception ex) { Fail($"dlc.rpf does not open: {ex.Message}"); continue; }
            opened.Add((name, rpf));
            foreach (var r in All(rpf).Skip(1)) if (r.AllEntries == null) Fail($"nested archive {r.Path} did not parse");

            var files = Entries(rpf).OfType<RpfFileEntry>().ToList();
            var relPaths = new HashSet<string>(files.Select(Rel));
            var dirPaths = new HashSet<string>(Entries(rpf).OfType<RpfDirectoryEntry>().Select(Rel));

            // setup2.xml
            var s2 = files.FirstOrDefault(e => Rel(e) == "setup2.xml");
            string device = null;
            if (s2 == null) { Fail("setup2.xml missing"); continue; }
            var s2t = Text(s2);
            device = Regex.Match(s2t, "<deviceName>([^<]+)</deviceName>").Groups[1].Value;
            var datFile = Regex.Match(s2t, "<datFile>([^<]+)</datFile>").Groups[1].Value;
            if (string.IsNullOrEmpty(device)) Fail("setup2.xml has no deviceName");
            else
            {
                var dl = device.ToLowerInvariant();
                if (devices.TryGetValue(dl, out var other)) Fail($"deviceName {device} also used by pack {other}");
                else if (vanillaDevices.Contains(dl)) Fail($"deviceName {device} collides with an official DLC");
                else Pass($"deviceName {device} is unique");
                devices[dl] = name;
            }
            if (!relPaths.Contains(datFile.ToLowerInvariant())) Fail($"setup2 datFile '{datFile}' not in pack"); else Pass($"setup2 datFile {datFile} present");

            // content.xml: every referenced file exists; device prefix matches; changeset items are declared
            var cx = files.FirstOrDefault(e => Rel(e) == datFile.ToLowerInvariant());
            var declared = new HashSet<string>();
            var audioFiles = new List<(string type, string rel)>();
            if (cx != null)
            {
                var ct = Text(cx);
                try { new XmlDocument().LoadXml(ct); Pass($"{datFile} is well-formed XML"); } catch (Exception ex) { Fail($"{datFile} invalid XML: {ex.Message}"); }
                var df = Regex.Matches(ct, @"<Item>\s*<filename>([^<]+)</filename>\s*<fileType>([^<]+)</fileType>", RegexOptions.Singleline);
                int ok = 0;
                foreach (Match m in df)
                {
                    var fn = m.Groups[1].Value.Trim(); var ft = m.Groups[2].Value.Trim();
                    declared.Add(fn.ToLowerInvariant());
                    var mm = Regex.Match(fn, @"^([^:]+):/(.*)$");
                    if (!mm.Success) { Fail($"content file '{fn}' has no device prefix"); continue; }
                    if (!mm.Groups[1].Value.Equals(device, StringComparison.OrdinalIgnoreCase)) Fail($"'{fn}' uses device '{mm.Groups[1].Value}', setup2 says '{device}'");
                    var rel = mm.Groups[2].Value.Replace("%PLATFORM%", "x64").Replace('/', '\\').TrimEnd('\\').ToLowerInvariant();
                    bool exists;
                    if (ft.StartsWith("AUDIO_") && ft != "AUDIO_WAVEPACK")
                        exists = relPaths.Any(p => p.StartsWith(rel) && p.EndsWith(".rel") && Regex.IsMatch(p.Substring(rel.Length), @"^\d*\.rel$"));
                    else if (ft == "AUDIO_WAVEPACK") exists = dirPaths.Contains(rel);
                    else exists = relPaths.Contains(rel);
                    if (ft.StartsWith("AUDIO_")) audioFiles.Add((ft, rel));
                    if (exists) ok++; else Fail($"content.xml references missing file '{fn}' ({ft}) — this is what hung the first R8 on load");
                }
                Pass($"{ok}/{df.Count} content.xml files resolve");
                foreach (Match m in Regex.Matches(ct, @"<filesToEnable>(.*?)</filesToEnable>", RegexOptions.Singleline))
                    foreach (Match it in Regex.Matches(m.Groups[1].Value, "<Item>([^<]+)</Item>"))
                        if (!declared.Contains(it.Groups[1].Value.Trim().ToLowerInvariant())) Fail($"filesToEnable item '{it.Groups[1].Value}' is not declared in dataFiles");
            }
            else Fail($"{datFile} missing");

            // resources: Enhanced versions, 128 limits, script_rt headers
            int res = 0, resOk = 0;
            foreach (var e in files.OfType<RpfResourceFileEntry>())
            {
                var ext = Path.GetExtension(e.NameLower);
                int want = ext switch { ".ytd" => 5, ".yft" => 171, ".ydr" => 159, ".ydd" => 159, ".ypt" => 71, _ => -1 };
                if (want < 0) continue;
                res++;
                if (e.Version != want) { Fail($"{Rel(e)} is v{e.Version}, Enhanced needs v{want} (Legacy file, would crash)"); continue; }
                try
                {
                    var data = e.File.ExtractFile(e);
                    if (ext == ".yft")
                    {
                        var y = new YftFile(); y.Load(data, e);
                        var drawables = new List<(string, DrawableBase)>();
                        if (y.Fragment?.Drawable != null) drawables.Add(("main", y.Fragment.Drawable));
                        var ch = y.Fragment?.PhysicsLODGroup?.PhysicsLOD1?.Children?.data_items;
                        if (ch != null) foreach (var c in ch) { if (c?.Drawable1 != null) drawables.Add(("child", c.Drawable1)); if (c?.Drawable2 != null) drawables.Add(("child2", c.Drawable2)); }
                        var shaders = y.Fragment?.Drawable?.ShaderGroup?.Shaders?.data_items?.Length ?? 0;
                        int maxG = 0;
                        foreach (var (lbl, d) in drawables)
                            foreach (var lod in new[] { d.DrawableModels?.High, d.DrawableModels?.Med, d.DrawableModels?.Low, d.DrawableModels?.VLow })
                                if (lod != null) foreach (var m in lod) maxG = Math.Max(maxG, m?.Geometries?.Length ?? 0);
                        bool good = true;
                        if (shaders > 128) { Fail($"{Rel(e)}: {shaders} shaders > 128 (Enhanced limit)"); good = false; }
                        if (maxG > 128) { Fail($"{Rel(e)}: {maxG} geometries in one model > 128 (Enhanced limit)"); good = false; }
                        // every geometry must point at an existing shader
                        foreach (var (lbl, d) in drawables)
                            foreach (var lod in new[] { d.DrawableModels?.High, d.DrawableModels?.Med, d.DrawableModels?.Low, d.DrawableModels?.VLow })
                                if (lod != null) foreach (var m in lod) foreach (var g in m?.Geometries ?? new DrawableGeometry[0])
                                    if (g.ShaderID >= shaders && shaders > 0) { Fail($"{Rel(e)}: geometry uses shader {g.ShaderID} of {shaders}"); good = false; }
                        // textures embedded in the model (its own texture dictionary): same render-target rule as .ytd
                        foreach (var t in y.Fragment?.Drawable?.ShaderGroup?.TextureDictionary?.Textures?.data_items ?? new Texture[0])
                            if (!OfficialTexFormat(t.Format)) { Fail($"{Rel(e)}::{t.Name} (embedded) is {t.Format}: no official texture uses it"); good = false; }
                        foreach (var t in y.Fragment?.Drawable?.ShaderGroup?.TextureDictionary?.Textures?.data_items ?? new Texture[0])
                            if (t.Name.StartsWith("script_rt", StringComparison.OrdinalIgnoreCase))
                            {
                                var diff = Diff(rtRef, RtHeader(e, t));
                                if (diff.Count == 0) Pass($"{Rel(e)}::{t.Name} (embedded) header matches vanilla render targets byte for byte");
                                else { Fail($"{Rel(e)}::{t.Name} (embedded) header differs from vanilla at {string.Join(",", diff.Select(o => $"+0x{o:X2}"))} (this crashed story-mode load)"); good = false; }
                            }
                        if (good) resOk++;
                    }
                    else if (ext == ".ytd")
                    {
                        var y = new YtdFile(); y.Load(data, e);
                        bool good = true;
                        foreach (var t in y.TextureDict?.Textures?.data_items ?? new Texture[0])
                        {
                            if (t.Data?.FullData == null || t.Data.FullData.Length == 0) { Fail($"{Rel(e)}::{t.Name} has no pixel data"); good = false; }
                            if (!OfficialTexFormat(t.Format)) { Fail($"{Rel(e)}::{t.Name} is {t.Format}: no official texture uses it (the Mustang with a BC7 + a DXT3 texture crashed story-mode load); re-encode it with texexport + py/todds.py + teximport"); good = false; }
                            if (t.Name.StartsWith("script_rt", StringComparison.OrdinalIgnoreCase))
                            {
                                var h = RtHeader(e, t.Name);
                                var diff = Diff(rtRef, h);
                                if (diff.Count == 0) Pass($"{Rel(e)}::{t.Name} header matches vanilla render targets byte for byte");
                                else { Fail($"{Rel(e)}::{t.Name} header differs from vanilla at {string.Join(",", diff.Select(o => $"+0x{o:X2}"))} (this crashed story-mode load)"); good = false; }
                            }
                        }
                        if (good) resOk++;
                    }
                    else resOk++;
                }
                catch (Exception ex) { Fail($"{Rel(e)} failed to parse: {ex.Message}"); }
            }
            if (res > 0) { if (resOk == res) Pass($"{res} resources: Enhanced versions, within 128 shader/geometry limits, parse fine"); else Console.WriteLine($"  ({resOk}/{res} resources clean)"); }

            // audio rels in this pack (collect names first, check refs after all packs are known)
            foreach (var e in files.Where(f => f.NameLower.EndsWith(".rel")))
            {
                try
                {
                    var rel = new RelFile(); rel.Load(e.File.ExtractFile(e), e);
                    foreach (var d in rel.RelDatas)
                    {
                        packAudioNames.Add(d.NameHash.Hash);
                        if (rel.RelType == RelDatFileType.Dat151 && (Dat151RelType)d.TypeID == Dat151RelType.CarAudioSettings) packCarAudio.Add(d.NameHash.Hash);
                    }
                }
                catch (Exception ex) { Fail($"{Rel(e)} does not parse: {ex.Message}"); }
            }
        }

        // ---------- cross-pack checks: vehicles.meta, handling, audio ----------
        foreach (var (name, rpf) in opened)
        {
            var files = Entries(rpf).OfType<RpfFileEntry>().ToList();
            var vm = files.Where(e => e.NameLower == "vehicles.meta").ToList();
            var audioRels = files.Where(e => e.NameLower.EndsWith(".rel")).ToList();
            if (vm.Count == 0 && audioRels.Count == 0) continue;
            Console.WriteLine($"\n[content {name}]");
            var handling = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var h in files.Where(e => e.NameLower == "handling.meta"))
                foreach (Match m in Regex.Matches(Text(h), "<handlingName>([^<]+)</handlingName>")) handling.Add(m.Groups[1].Value.Trim());
            var resNames = new HashSet<string>(files.OfType<RpfResourceFileEntry>().Select(e => e.NameLower));
            foreach (var cc in files.Where(e => e.NameLower == "carcols.meta"))
                foreach (Match m in Regex.Matches(Text(cc), @"<kitName>([^<]*)</kitName>\s*<id value=""(\d+)"""))
                {
                    var id = int.Parse(m.Groups[2].Value); var kn = m.Groups[1].Value;
                    if (vanillaKits.Contains(id)) Fail($"mod kit {kn} id {id} collides with an official kit (tuning parts would mix)");
                    else if (!packKits.Add(id)) Fail($"mod kit {kn} id {id} also used by another pack");
                    else if (id > 65535) Warn($"mod kit {kn} id {id} does not fit in 16 bits (unproven risk; official max is {vanillaKits.Max()})");
                    else Pass($"mod kit {kn} id {id} is unique");
                }
            foreach (var v in vm)
            {
                var t = Text(v);
                try { new XmlDocument().LoadXml(t); Pass("vehicles.meta is well-formed XML"); } catch (Exception ex) { Fail($"vehicles.meta invalid XML: {ex.Message}"); continue; }
                foreach (Match it in Regex.Matches(t, @"<modelName>([^<]+)</modelName>(.*?)</Item>", RegexOptions.Singleline))
                {
                    var model = it.Groups[1].Value.Trim().ToLowerInvariant();
                    var body = it.Groups[2].Value;
                    string F(string tag) { var m = Regex.Match(body, $"<{tag}>([^<]*)</{tag}>"); return m.Success ? m.Groups[1].Value.Trim() : null; }
                    var txd = F("txdName"); var hid = F("handlingId"); var aud = F("audioNameHash");
                    if (models.TryGetValue(model, out var o)) Fail($"model {model} also defined by {o}");
                    else if (vanillaModels.Contains(model)) Fail($"model {model} collides with a vanilla vehicle");
                    else Pass($"model {model} is unique");
                    models[model] = name;
                    if (resNames.Contains(model + ".yft")) Pass($"{model}.yft present"); else Fail($"{model}.yft missing from the pack");
                    if (resNames.Contains(model + "_hi.yft")) Pass($"{model}_hi.yft present"); else Warn($"{model}_hi.yft missing (no high LOD)");
                    if (txd != null && resNames.Contains(txd.ToLowerInvariant() + ".ytd")) Pass($"txd {txd}.ytd present"); else Fail($"txd '{txd}' ytd missing");
                    if (hid != null && handling.Contains(hid)) Pass($"handlingId {hid} defined in the pack's handling.meta"); else Warn($"handlingId '{hid}' not in this pack's handling.meta (must exist in the game)");
                    if (string.IsNullOrEmpty(aud)) Warn("no audioNameHash");
                    else
                    {
                        var ah = Joaat(aud);
                        if (packCarAudio.Contains(ah)) Pass($"audioNameHash {aud} -> CarAudioSettings in an enabled sound pack");
                        else if (carAudioNames.Contains(ah)) Pass($"audioNameHash {aud} -> vanilla CarAudioSettings");
                        else Warn($"audioNameHash {aud} has no CarAudioSettings in the game or enabled packs: the game uses its generic fallback sound");
                    }
                }
            }
            // audio pack checks
            var known = new HashSet<uint>(audioNames); known.UnionWith(packAudioNames); known.Add(3817852694u); known.Add(0);
            foreach (var e in audioRels)
            {
                var rel = new RelFile();
                try { rel.Load(e.File.ExtractFile(e), e); }
                catch (Exception ex) { Fail($"{Rel(e)} does not parse ({ex.GetType().Name}); the game may read it differently, don't use this pack"); continue; }
                if (rel.RelType == RelDatFileType.Dat10ModularSynth)
                    Fail($"{Rel(e)}: custom modular synths ({rel.RelDatas.Length}) — the crashing twin-turbo pack was the only one shipping these; official car packs and the working sound packs don't");
                int refs = 0; var bad = new List<string>();
                foreach (var d in rel.RelDatas)
                    foreach (var p in d.GetType().GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.DeclaredOnly))
                    {
                        if (p.PropertyType != typeof(MetaHash)) continue;
                        if (rel.RelType != RelDatFileType.Dat151) continue;
                        var v = ((MetaHash)p.GetValue(d)).Hash;
                        if (v == 0) continue;
                        refs++;
                        if (!known.Contains(v)) bad.Add($"{(Dat151RelType)d.TypeID}.{p.Name}={v}");
                    }
                if (rel.RelType == RelDatFileType.Dat151)
                {
                    if (bad.Count == 0) Pass($"{Rel(e)}: all {refs} references resolve against the game + enabled packs");
                    else Fail($"{Rel(e)}: unresolved references: {string.Join(", ", bad)}");
                }
            }
            foreach (var e in files.Where(f => f.NameLower.EndsWith(".awc")))
            {
                try
                {
                    var awc = new AwcFile(); awc.Load(e.File.ExtractFile(e), e);
                    var rates = new HashSet<int>(); int gran = 0;
                    foreach (var s in awc.Streams ?? new AwcStream[0])
                    {
                        bool isGran = s.Chunks?.Any(c => c is AwcGranularGrainsChunk) ?? false;
                        if (!isGran) continue;
                        gran++;
                        var fc = s.Chunks.OfType<AwcFormatChunk>().FirstOrDefault();
                        if (fc != null) rates.Add((int)fc.SamplesPerSecond);
                    }
                    if (gran == 0) Pass($"{Rel(e)}: {awc.Streams?.Length} streams, no granular engine streams");
                    else if (rates.All(r => r == 32000)) Pass($"{Rel(e)}: {gran} granular streams, all 32000 Hz like every official engine");
                    else Fail($"{Rel(e)}: granular streams at {string.Join("/", rates)} Hz — official engines are all 32000 Hz (the crashing pack used 48000/42000)");
                }
                catch (Exception ex) { Fail($"{Rel(e)} does not parse: {ex.Message}"); }
            }
        }

        // ---------- vehicle model info pool ----------
        // MaxExtraVehicleModelInfos (gameconfig.xml) caps every vehicle that is not in common.rpf: the official DLC
        // ones already use all but 3 of the vanilla 640, so a 4th add-on car crashed story-mode load at exe+0x13778cf.
        Console.WriteLine("\n[global] vehicle model info pool (gameconfig.xml)");
        try
        {
            int Limit(RpfFile r, string tag) { var m = Regex.Match(Text(Find(r, "common\\data\\gameconfig.xml")), $"<{tag} value=\"(\\d+)\"\\s*/>"); return m.Success ? int.Parse(m.Groups[1].Value) : -1; }
            var nonBase = VanillaNonBaseVehicles(game);
            int limit = Limit(modsRpf, "MaxExtraVehicleModelInfos"), vanLimit = Limit(vanillaUpdate, "MaxExtraVehicleModelInfos");
            int need = nonBase + models.Count;
            Console.WriteLine($"  official non-base vehicles: {nonBase}, add-on models enabled: {models.Count}, MaxExtraVehicleModelInfos: {limit} (game's own: {vanLimit})");
            if (need <= limit) Pass($"{need} non-base vehicle model infos fit in MaxExtraVehicleModelInfos {limit} ({limit - need} left)");
            else Fail($"{need} non-base vehicle model infos > MaxExtraVehicleModelInfos {limit}: story mode crashes while loading; raise it in mods/update/update.rpf common/data/gameconfig.xml");
        }
        catch (Exception ex) { Fail($"could not check the vehicle model info pool: {ex.Message}"); }

        return Summary();
    }

    // vehicles defined outside common.rpf: official dlcpacks plus the dlc_patch vehicles.meta files in update.rpf
    static int VanillaNonBaseVehicles(string game)
    {
        HashSet<string> Models(RpfFile r)
        {
            var set = new HashSet<string>();
            foreach (var e in Entries(r).OfType<RpfFileEntry>().Where(f => f.NameLower == "vehicles.meta"))
                foreach (Match m in Regex.Matches(Text(e), @"<modelName>\s*([^<\s]+)\s*</modelName>")) set.Add(m.Groups[1].Value.ToLowerInvariant());
            return set;
        }
        var quiet = new Action<string>(_ => { });
        var baseSet = Models(Open(Path.Combine(game, "common.rpf"), quiet));
        var all = Models(Open(Path.Combine(game, "update", "update.rpf"), quiet));
        foreach (var d in Directory.GetDirectories(Path.Combine(game, "update", "x64", "dlcpacks")))
            if (File.Exists(Path.Combine(d, "dlc.rpf"))) try { all.UnionWith(Models(Open(Path.Combine(d, "dlc.rpf"), quiet))); } catch { }
        return all.Except(baseSet).Count();
    }

    static int Summary()
    {
        Console.WriteLine($"\n== SUMMARY: {pass} passed, {warn} warnings, {fail} failed");
        return fail > 0 ? 1 : 0;
    }

    // formats seen in ~7,000 textures of the official mp2026_01, mp2025_01 and mpassault packs; BC7 and DXT3 never appear
    static bool OfficialTexFormat(TextureFormat f) => f is TextureFormat.D3DFMT_DXT1 or TextureFormat.D3DFMT_DXT5
        or TextureFormat.D3DFMT_A8R8G8B8 or TextureFormat.D3DFMT_A8B8G8R8 or TextureFormat.D3DFMT_A8
        or TextureFormat.D3DFMT_ATI1 or TextureFormat.D3DFMT_ATI2;

    static List<int> Diff(byte[] a, byte[] b)
    {
        var skip = new HashSet<int>(Enumerable.Range(0, 8).Concat(Enumerable.Range(0x28, 0x18)).Concat(Enumerable.Range(0x58, 8)));
        var r = new List<int>();
        if (a == null || b == null) { r.Add(-1); return r; }
        for (int i = 0; i < 0x80; i++) if (!skip.Contains(i) && a[i] != b[i]) r.Add(i);
        return r;
    }

    // raw gen9 texture struct of a named texture: locate by width/height/levels/format signature in the system page
    static byte[] RtHeader(RpfResourceFileEntry e, string texName)
    {
        var y = new YtdFile(); y.Load(e.File.ExtractFile(e), e);
        return RtHeader(e, y.TextureDict.Textures.data_items.First(x => x.Name.Equals(texName, StringComparison.OrdinalIgnoreCase)));
    }

    // the 0x80-byte gen9 texture struct of t, found in the system part of the resource (works for .ytd and for
    // textures embedded in a .yft/.ydr)
    static byte[] RtHeader(RpfResourceFileEntry e, Texture t)
    {
        var raw = e.File.ExtractFile(e);
        int sysLen = (int)e.SystemSize;
        byte fmt = (byte)t.GetEnhancedFormat(t.Format);
        for (int i = 0x18; i + 0x68 <= sysLen; i += 8)
        {
            if (BitConverter.ToUInt16(raw, i) != t.Width || BitConverter.ToUInt16(raw, i + 2) != t.Height || raw[i + 4] != 1 || raw[i + 5] != 0) continue;
            int st = i - 0x18;
            if (raw[st + 0x1F] != fmt || raw[st + 0x22] != t.Levels) continue;
            if (BitConverter.ToUInt32(raw, st + 0x10) != t.G9_Flags) continue;
            var h = new byte[0x80]; Array.Copy(raw, st, h, 0, 0x80); return h;
        }
        return null;
    }
}
