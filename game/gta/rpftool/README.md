# rpftool

A small command-line tool for GTA V Enhanced archives, built on [CodeWalker](https://github.com/dexyfex/CodeWalker)'s core library so it runs natively on Linux (CodeWalker itself is a Windows app). It reads the AES key from `GTA5_Enhanced.exe`, so nothing secret lives here.

## Build

```sh
cd game/gta/rpftool
git clone --depth 1 https://github.com/dexyfex/CodeWalker.git
nix shell nixpkgs#dotnet-sdk_8 -c dotnet build -c Release -o out
alias rpftool='nix shell nixpkgs#dotnet-sdk_8 -c dotnet ~/dotfiles/game/gta/rpftool/out/rpftool.dll'
```

Every command takes the game folder first: `rpftool <game> <command> …`. Inner paths use `\` and match by suffix (`'vehicles.rpf\car.ytd'`).

## Commands

| Command | What it does |
|---|---|
| `verify <mods/update>` | Offline check of the whole mods setup (see below). Exit code 1 if anything fails |
| `list <rpf> [filter]` | Every entry, with resource version `[vN]` and encryption |
| `cat <rpf> <inner>` / `extract <rpf> <inner> <out>` / `put <rpf> <inner> <file>` | Read, dump or replace one file |
| `dlclist <update.rpf> <item>` | Add (`dlcpacks:/x/`) or remove (`-dlcpacks:/x/`) a `dlclist.xml` line; derives the NG encrypt tables and re-verifies |
| `convert <in.rpf> <out.rpf>` | Legacy → Enhanced resources (CodeWalker's Gen9 converter, re-implemented without Windows paths) |
| `inspect <rpf>` | Per `.yft`: shaders and geometries per model; per `.ytd`: `script_rt` textures (`ALLTEX=1` for all) |
| `yft2xml` / `xml2yft` | CodeWalker XML export / import of a `.yft` inside an archive |
| `fixrt <rpf> <inner ytd>` | Make `script_rt_*` textures match the game's render targets byte for byte. Run it after any other `.ytd` edit |
| `rawtex <rpf> <ytd filter> <tex>` | Raw 0x80-byte texture struct, for comparing with vanilla |
| `texexport` / `teximport` | Mip 0 as raw BGRA out (a `.dds` for formats CodeWalker cannot decode, like BC7); a DDS in, replacing one texture |
| `fragdump` / `deepdump` | Fragment fields / recursive object dump, for diffing two `.yft` (`SHADERS=1` includes shaders) |
| `cmprpf <a> <b>` | Byte comparison of every file in two packs |
| `reldump`, `relht`, `relresave`, `synthops`, `awcinfo` | Audio: objects and fields, hash tables, round-trip diff, synth opcodes, wave banks |
| `relwaves <rpf>` | Every wave the pack's `dat54` sounds play, checked against its `.awc` streams (one missing wave is normal: every Aquaphobic pack has it) |
| `texhdr <rpf>` | One line per texture (`.ytd` and embedded in `.yft`/`.ydr`): format, size, mips, gen9 flags and header bytes |
| `vehcount [mods/update]` | Vehicle model infos: base game vs official DLC, plus the enabled add-ons, to compare with `MaxExtraVehicleModelInfos` |
| `gamegrep <word>...` | Which game data files mention each name (text, or its hash in binary `.ymt`) |
| `relfind <hash>...` | Which game `.rel` file defines each audio object, and its type |
| `relstats <dat151 type> <field>...` | Distribution (min, percentiles, max) of numeric fields over every official object of that type |
| `relfield <rpf> <rel> <dat151 type> <field> <value>` | Set a numeric field (e.g. engine `MasterVolume`); refuses unless the file re-saves byte for byte, checks only that field's bytes changed |
| `relset <rpf> <rel> <old> <new>` | Replace every `dat151` reference equal to `old` with `new` and save (check `relresave` is byte-identical first) |

`py/` holds the helpers: `setaudio.py` (set `audioNameHash` per model in a `vehicles.meta`), `setnames.py` (menu name and brand per model, max 11 characters), `fixyft.py` (shader dedupe + geometry merge on a `.yft.xml`), `fixcontent.py` (drop `content.xml` items for missing files), `plate_e.py` (the EU plate edit), `bgra2png.py` and `sheet.py` (look at exported textures), `mdmp.py` (exception code and `module+offset` from a crash `.dmp`), `todds.py` (re-encode a texture as A8R8G8B8 with mips; reads BC7).

## verify

Indexes the unmodified game first (official `dlclist.xml`, every audio object in the base game and all official DLCs, vanilla vehicle models, DLC device names, mod kit ids, and the `script_rt_dials_banshee` header), then checks:

- `update.rpf` opens, has the same entries as the game's, `dlclist.xml` is valid XML, keeps every official item, has no duplicates we added, and every custom item has its `dlc.rpf`.
- Per pack: `setup2.xml` device name unique (vs other packs and official DLCs); every `content.xml` file exists; `filesToEnable` items are declared; resources are Gen9; ≤128 shaders and geometries per model; geometries point at real shaders; `script_rt` headers identical to vanilla (also for textures embedded in `.yft`); no texture in a format the game doesn't use (BC7, DXT3).
- Globally: official non-base vehicles + enabled add-on models fit in `MaxExtraVehicleModelInfos` of the mods `gameconfig.xml`.
- Per `vehicles.meta`: model names unique and not vanilla; `.yft`, `_hi.yft`, `.ytd` present; handling id defined; `audioNameHash` resolves; mod kit ids free.
- Per sound pack: every reference resolves against the game plus enabled packs; no custom `dat10` synths; granular streams at 32 kHz.

It was validated against every pack that broke during setup: each one fails for its real cause, and the working set passes.
