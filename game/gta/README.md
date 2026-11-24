# GTA V Enhanced mods on Linux

Notes from setting up story-mode mods for **GTA V Enhanced** (Steam app `3240220`) on the NixOS desktop, running through Proton. The goal was 100% of the story achievements with mods that improve the vanilla experience without trivialising it: no trainers, no cheats.

Everything here was learned the hard way in one long session, including several crashes. The rules that came out of them are what keeps the setup working now.

| File | What it covers |
|---|---|
| [`modding-on-linux.md`](modding-on-linux.md) | Script Hook V, the ASI loader, Proton launch options, OpenRPF and the `mods` folder, editing `update.rpf` |
| [`addon-vehicles.md`](addon-vehicles.md) | Add-on cars on Enhanced: format rules, the 128 limits, `script_rt` textures, converting and fixing Legacy cars, every crash and its cause |
| [`audio.md`](audio.md) | Add-on engine sounds: how a sound pack is built, why one pack crashed the game, which one works |
| [`rpftool/`](rpftool/) | The C# tool (on top of CodeWalker.Core) that does all of the above natively on Linux, plus the helper scripts |

## What is installed

Game folder: `~/games/steam/SteamLibrary/steamapps/common/Grand Theft Auto V Enhanced` (the shared Steam library from `modules/nixos/desktop/steam.nix`). Proton prefix and saves: `~/games/proton/3240220/pfx/drive_c/users/steamuser/Documents/Rockstar Games/GTAV Enhanced`.

| Piece | File(s) | Purpose |
|---|---|---|
| Script Hook V | `ScriptHookV.dll`, `xinput1_4.dll`, `args.txt` | Runs `.asi` script mods; `args.txt` starts the game without BattlEye |
| Swap Main Ride | `SwapMainRide.asi` | F7: make the current car a character's personal vehicle |
| OpenRPF | `OpenRPF.asi` | Loads modified archives from `mods/` (OpenIV.asi replacement for Enhanced) |
| Add-On Vehicle Spawner | `AddonSpawner.asi`, `AddonSpawner/` | F5: spawn add-on cars by name |
| Script Hook V .NET Enhanced 1.1.0.6 (**disabled**) | `ScriptHookVDotNet.asi.off`, `ScriptHookVDotNet2/3.dll`, `ScriptHookVDotNet.ini`, `MinHook.x64.dll` | Runs .NET scripts from `scripts/`. **Crashes story-mode load on the prefix's Wine Mono** (`GTA5_Enhanced.exe+0x1918`, right after `Loading API from ScriptHookVDotNet3.dll`), so the `.asi` is renamed and the three scripts below are inert. See "Known issues" below |
| LemonUI 2.2 | `scripts/LemonUI.SHVDN3.dll` | Menu library for .NET scripts (official GitHub release) |
| Persistence Pro 1.8.0 | `scripts/PersistencePro.dll`, `scripts/PersistencePro.ini` | Cars stay where you park them, across restarts; garage menu on **F8** (moved from F7, which Swap Main Ride uses) |
| Weapon & Vehicle Saving System 2.0.0 | `scripts/WeaponVehicleSavingSystem.dll` + folder | **F10**: save/restore weapons with attachments (its vehicle features overlap Persistence Pro; use that one for cars) |
| Immersive Enhanced Sound Pack 2.5 | `mods/x64/audio/sfx/RESIDENT.rpf`, `WEAPONS_PLAYER.rpf` | Weapon, impact and explosion sounds. Loaded through OpenRPF instead of replacing game files; checked offline that it has every stream of the current game's archives and that untouched files are byte-identical |
| Add-on cars | `mods/update/x64/dlcpacks/<name>/dlc.rpf` | One DLC pack per car, listed in `mods/update/update.rpf` → `common/data/dlclist.xml` |
| Engine sounds | `mods/update/x64/dlcpacks/<audioNameHash>/dlc.rpf` | One sound pack per engine (table below), listed the same way |
| Bigger vehicle pool | `mods/update/update.rpf` → `common/data/gameconfig.xml` | `MaxExtraVehicleModelInfos` 640 → 800. The game's own value only leaves room for 3 add-on cars |

### Status

The first 12 cars (11 packs) and their 9 sound packs load and drive in story mode (confirmed in game, 2026-11-17). The Urus and the F-250 were added afterwards and also work. The Ducati Panigale V4 S (2026-11-18) was converted from Legacy and the Yamaha MT-09 added from its Enhanced build; `rpftool verify` passes 316/316 with 147 free vehicle slots.

Getting there took a long bisect: three add-on cars always worked and a fourth always crashed story-mode load, whichever car it was. The cause was the vehicle pool in `gameconfig.xml` (see [`addon-vehicles.md`](addon-vehicles.md#rules-enhanced-enforces)), not the cars.

### Known issues

- **Script Hook V .NET needs real .NET Framework 4.8, and it could not be installed** (2026-11-17), so Persistence Pro, Weapon & Vehicle Saving System and DriverJobs V (downloaded to `~/games/gtav-disabled-addons/pending/`) don't run. What was tried, all on copies or with a backup:
  - `protontricks 3240220 dotnet48` (nixpkgs): aborts because Proton's wine, outside the Steam runtime, prints a FreeType warning and winetricks' `%AppData%` check fails.
  - winetricks with Proton Experimental's wine inside `steam-run`: removes Wine Mono, then the .NET 4.0 and 4.8 installers fail (status 67, MSI error 1603 with an empty MSI log). Wine 11's new wow64 mode is the likely cause.
  - Proton 9.0's wine on a copy of the prefix: hangs in `wineboot` (Wine 11 → 9 downgrade). On a fresh Proton 9 prefix (`~/games/gtav-prefix-proton9`): hangs in `uninstaller.exe --remove` (Wine Mono), probably on a dialog nobody saw.
  - The real prefix was restored from `~/games/gtav-prefix-backup-before-dotnet48`; the failed state is in `~/games/gtav-prefix-after-dotnet-attempt`.
  - Next attempt: the fresh Proton 9 prefix with someone watching the screen for installer dialogs, then switch the game to Proton 9 in Steam and move the saves over.
- **Several personal vehicles, blips not matching** (Swap Main Ride 2.1): with `ScriptPatch=1` the mod patches `vehicle_gen_controller` so the *game* spawns the custom car (game entity, game blip). "Spawn Main Ride Here" only moves cars the mod created itself, so it spawns another one; with `ShowBlips=1` each copy had a blip (looked like a duplicate blip), with `ShowBlips=0` the summoned one had none. Set to `ScriptPatch=0` (the mod swaps the stock car unseen and owns it) and `ShowBlips=1`. Side effect: the stock car can be glimpsed for a moment, mostly on character switch (the author's known issue). Edit the INI with the game closed; the mod rewrites it on save.

- **Huracán Twin Turbo (`lhtt`): the exhausts and the turbo piping render bright green**, as if a texture were missing or broken. Seen in game on 2026-11-17 and not looked into yet. Likely candidates: a texture the material points at that isn't in `lhtt.ytd` or in the shared `vehshare` dictionaries, or a texture in a format/flags the shader doesn't expect. Start with `rpftool texhdr` on the pack and `fragdump` on `lhtt.yft` to see which shader and textures the exhaust geometry uses.

### Cars

Spawn names for the F5 menu. All are Enhanced builds from gta5-mods except the R8, which was converted and fixed by hand. The menu shows the menu name (`gameName`, at most 11 characters, set with `py/setnames.py`; the brand is in `vehicleMakeName`).

| Car | Spawn name | Menu name | Pack | Sound (`audioNameHash`) |
|---|---|---|---|---|
| Audi R8 V10 2023 | `audir82023` | `audiR8` | converted (see [`addon-vehicles.md`](addon-vehicles.md)) | Aquaphobic 5.2 V10 (`aq68lam52v10`) |
| ABT Audi RS7-R | `abtrs7` | `audiRS7` | HAMMER | Aquaphobic AMG M177 4.0 V8 TT (`aq67merm177`) |
| Lamborghini Huracán Twin Turbo | `lhtt` | `huracanTT` | HAMMER | Aquaphobic 5.2 V10 (`aq68lam52v10`) |
| Lamborghini Revuelto SV 2027 | `lrsv27` | `revueltoSV` | HAMMER | Aquaphobic Aston Martin 5.9 V12 (`aston59v12`) |
| BMW G82 M4 Adro | `g82adro` | `bmwM4` | HAMMER | Aquaphobic S58 (`aq70bmws58`, patched) |
| Koenigsegg Agera RS | `kars` | `ageraRS` | HAMMER | Aquaphobic Koenigsegg 5.0 V8 TT (`aq88koe50v8`, patched) |
| Koenigsegg Jesko Attack | `kja24` | `jesko` | HAMMER | same as the Agera |
| Ford Mustang Dark Horse | `fmdh` | `mustang` | HAMMER | Aquaphobic Coyote 5.0 V8 (`aq02coyotef150`) |
| Bugatti Tourbillon 2026 | `tour26` | `tourbillon` | | Aquaphobic Pagani M297 V12 (`aq59pagm297`, patched) |
| Ferrari 812 Superfast / Competizione | `fast812` / `comp812` | `ferrari812` / `ferrari812C` | one pack, `super812` | Legacy_DMC 812 Superfast (`lg86fer812sf`, patched) |
| Ferrari F80 2025 | `25f80` | `ferrariF80` | | Aquaphobic Alfa 2.9 V6 TT (`alfa690t`) |
| Lamborghini Urus SE 2025 | `luse` | `urusSE` | HAMMER | Legacy_DMC Urus 4.0 V8 Capristo (`lg51uruscapri`, patched) |
| Ford Shelby F-250 Super Baja 2023 (4 seats) | `f250shelby` | `f250Baja` | TabbedScamper, Add-on/Enhanced build | Aquaphobic Coyote 5.0 V8 (`aq02coyotef150`; no 7.3 V8 pack exists) |
| Ducati Panigale V4 S 2025 (bike) | `25v4s` | `panigaleV4` | galen_ 1.1, Legacy only: converted with `rpftool convert` (24/28 shaders and geometries, no `script_rt`, no BC7/DXT3) | vanilla Bati 801RR (`BATI2`) |
| Yamaha MT-09 2021 (bike) | `21mt09` | `yamahaMT09` | galen_ 1.0, Enhanced build | vanilla Vortex (`vortex`) |

Each sound pack is its own folder under `mods/update/x64/dlcpacks/` named after its `audioNameHash`. "Patched" packs had references that don't exist in Enhanced or a missing file in `content.xml`; [`audio.md`](audio.md#one-sound-per-car) has what was changed and why.

Steam launch options: `WINEDLLOVERRIDES="xinput1_4=n,b" %command%` (so Wine loads the ASI loader instead of its built-in `xinput1_4`).

Packs that were tried and turned off live in `~/games/gtav-disabled-addons/` so they can be retried without downloading again. Every edit of a live pack kept the previous version there:

| Folder | Holds the packs as they were before… |
|---|---|
| `backup-before-sounds/` | each car got its own engine sound (`audioNameHash`) |
| `backup-before-texfix/` | BC7/DXT3 textures were re-encoded (Mustang, BMW, Agera, Jesko, 812) |
| `backup-before-volume/` | the engine sounds were lowered 6 dB |
| `backup-before-volume-3db/` | the engine sounds went from −6 dB to quieter (holds the −6 dB versions) |
| `originals-new/` | the Urus, F-250 and Urus sound packs as downloaded |
| `backup-before-mt09/` | `update.rpf` before `dlcpacks:/21mt09/` was added (download in `pending/mt09-1.0/`) |
| `backup-before-panigale/` | `update.rpf` before `dlcpacks:/25v4s/` was added (the Panigale download and its conversion are in `pending/panigale-v4s-1.1/`) |
| `backup-before-names/` | the menu names and brands were set |

Saves were backed up to `~/games/gtav-enhanced-backup-20261117-0824` before the first mod went in.

## Achievements

- Mods don't block achievements; the game doesn't detect Script Hook V in story mode. **Confirmed on 2026-11-17**: "Out of Your Depth" unlocked at 20:21 with every mod loaded (Script Hook V, OpenRPF, add-on cars and sounds, weapon sound pack).
- Steam keeps the unlock times locally in `~/.local/share/Steam/appcache/stats/UserGameStats_<steamid>_3240220.bin` (binary KeyValues; achievement names come from `UserGameStatsSchema_3240220.bin`). `rpftool/py/steamstats.py <schema> <stats>` lists them, handy to check an unlock right after it happens.
- Most remaining story achievements are one-shot at the end of a series (100%, 70 golds, Epsilon…), so Steam shows no progress after a single mission. That's normal, not a sign they're broken.
- **Cheat codes do** (keyboard combos and phone numbers): achievements stay off for that session until a save is reloaded.
- Back up the saves before installing anything. They are tiny (a few MB) and a broken mission is the realistic risk, not a ban.

## After a game update

Rockstar updates break three things:

1. **Script Hook V** checks the game version. Get the new build from dev-c.com when it's out. Its log (`ScriptHookV.log`) prints `INIT: Success, game version is …` when it accepts the game.
2. **`mods/update/update.rpf`** is a full copy of the game's `update.rpf` with our `dlclist.xml` lines and the bigger vehicle pool added. After an update it is stale and must be rebuilt: copy the new `update/update.rpf` into `mods/update/` and re-add the custom `dlcpacks:/…/` items (see [`modding-on-linux.md`](modding-on-linux.md#editing-updaterpf)) and raise `MaxExtraVehicleModelInfos` in `common/data/gameconfig.xml` again (640 → 800; without it only 3 add-on cars fit, see [`addon-vehicles.md`](addon-vehicles.md#rules-enhanced-enforces)). Then run `rpftool verify` before starting the game.
3. **Add-On Vehicle Spawner** finds its hook by pattern; its log (`AddonSpawner/AddonSpawner.log`) says `Found InitVehicleArchetype` when it still works.
