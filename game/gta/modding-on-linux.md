# Modding GTA V Enhanced on Linux

## Script Hook V under Proton

- Download only from dev-c.com. The archive ships `ScriptHookV.dll`, two ASI loaders (`dinput8.dll` for Legacy, `xinput1_4.dll` for Enhanced), `args.txt` and a sample `NativeTrainer.asi`.
- **Enhanced imports `XINPUT1_4.dll`, not `dinput8.dll`** (checked with `strings` on `GTA5_Enhanced.exe`). Install `xinput1_4.dll` only. A mod README saying "copy dinput8.dll" is written for Legacy.
- Proton must prefer the native DLL: Steam launch options `WINEDLLOVERRIDES="xinput1_4=n,b" %command%`.
- `args.txt` contains `-nobattleye -noBE`. Without it the game starts through `GTA5_Enhanced_BE.exe` and mods don't load. GTA Online doesn't work on Linux anyway (BattlEye has no Proton support for it).
- Logs land in the game folder: `asiloader.log` (which `.asi` files got loaded), `ScriptHookV.log` (version check and which scripts started). If `CORE: Creating threads` never appears, the game hung before story mode started.
- Version check: Script Hook V refuses unknown builds. The 1158.13 build worked on game 1.0.1158.16 (the log reported 1158_13; the check passed).
- Leave `NativeTrainer.asi` out: it's a full trainer (god mode, spawning weapons), the opposite of what this setup is for.

## OpenRPF and the mods folder

[OpenRPF](https://www.gta5-mods.com/tools/openrpf-openiv-asi-for-gta-v-enhanced) replaces `OpenIV.asi` on Enhanced: archives under `mods/` override the game's own, and it bypasses `rpf.cache` for them. Install only `OpenRPF.asi` (the `xinput1_4.dll` loader from Script Hook V loads it; v0.2+ dropped its own `dsound.dll`). Its log is at `%APPDATA%\Los Santos Multiplayer\OpenRPF.log` inside the Proton prefix and lists every modified archive it opens.

An add-on car is a DLC pack:

```
mods/update/update.rpf                 copy of the game's update.rpf, dlclist.xml extended
mods/update/x64/dlcpacks/<name>/dlc.rpf the pack
```

`common/data/dlclist.xml` inside `update.rpf` gets one `<Item>dlcpacks:/<name>/</Item>` per pack, before `</Paths>`. The game's own list contains `dlcpacks:/mp2025_01_g9ec/` twice; that is Rockstar's, leave it.

## Editing update.rpf

There is no OpenIV on Linux, and CodeWalker is a Windows app, but its core library (`CodeWalker.Core`, netstandard2.0) builds and runs with the .NET 8 SDK from nixpkgs. [`rpftool`](rpftool/) wraps it.

Things that matter when writing to the game's archives:

- **Keys come from the executable.** `GTA5Keys.GenerateV2(GTA5_Enhanced.exe)` finds the AES key; the NG tables come from CodeWalker's embedded `magic.dat`, decrypted with it. Nothing is downloaded.
- **Writing an NG-encrypted archive needs the encrypt tables**, which CodeWalker only derives inside `GTA5Keys.Generate` (`RandomGauss.Solve` / `LookUpTableGenerator.BuildLUTs2` over the decrypt tables). `rpftool dlclist` does that before writing; without it you get `Unable to encrypt - tables not loaded`.
- **The NG key depends on the file name.** A copy named `update.rpf.new` cannot be read back ("Error in RPF7 file entry"). Edit a copy under its real name in a staging folder (`mods/update/.staging/update.rpf`) and `mv` it into place.
- **Swap files with `mv`, never overwrite in place while the game runs.** The running game keeps the old inode; the new file applies on the next start.
- CodeWalker builds internal paths with `\`, so its folder-based helpers (`Gen9Converter.Convert`, `GTA5Keys.LoadFromPath`) don't work on Linux. `rpftool` re-implements the few loops it needs on top of `RpfFile`.

```sh
rpftool <game> dlclist mods/update/.staging/update.rpf 'dlcpacks:/name/'    # add
rpftool <game> dlclist mods/update/.staging/update.rpf '-dlcpacks:/name/'   # remove
rpftool <game> extract mods/update/.staging/update.rpf 'common\data\gameconfig.xml' gameconfig.xml
rpftool <game> put mods/update/.staging/update.rpf 'common\data\gameconfig.xml' gameconfig.xml   # after editing it
```

Each run re-opens the archive and checks the line is there (or gone) before returning.

## Debugging crashes

- Crash dumps: `%LOCALAPPDATA%\Rockstar Games\GTAV Enhanced\CrashLogs\*.dmp` plus `crashcontext.log` (game state, loaded packs, streaming info) in the prefix.
- The `.dmp` is a normal minidump. Parse stream 6 (exception: code, address) and the thread context for registers; the Python `minidump` package chokes on Rockstar's custom stream type `0xFFF0`, a 40-line `struct` parser works.
- `0x80000003` (breakpoint) on the render thread with `d3d12core.dll` frames = the game's own fatal error, usually a resource it can't render.
- The game's `.text` is encrypted on disk, so a crash address can't be disassembled from the exe, and the dumps don't include code pages.
- `PROTON_LOG=1` doesn't help for crashes inside game code; the dump already has more.
- `rpftool/py/mdmp.py <file.dmp>` prints the exception code and `module+offset`; that is usually enough to tell a known crash (`GTA5_Enhanced.exe+0x13778cf` = vehicle registration while loading story mode) from a new one.
- **Bisect by count as well as by pack.** Disabling "the suspicious car" also lowers the number of add-on cars; with a fixed-size pool that hides the real cause. Enable one pack at a time and note how many are on when it breaks. Remove a pack from `dlclist.xml` to pause it; keep the files.
