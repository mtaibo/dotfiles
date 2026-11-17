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
| Add-on cars | `mods/update/x64/dlcpacks/<name>/dlc.rpf` | One DLC pack per car, listed in `mods/update/update.rpf` → `common/data/dlclist.xml` |
| Engine sounds | `mods/update/x64/dlcpacks/<audioNameHash>/dlc.rpf` | One sound pack per engine (table below), listed the same way |
| Bigger vehicle pool | `mods/update/update.rpf` → `common/data/gameconfig.xml` | `MaxExtraVehicleModelInfos` 640 → 800. The game's own value only leaves room for 3 add-on cars |

### Status

All 12 cars (11 packs) and their 9 sound packs load and drive in story mode (confirmed in game, 2026-11-17). `rpftool verify` passes 249/249 with 151 free vehicle slots.

Getting there took a long bisect: three add-on cars always worked and a fourth always crashed story-mode load, whichever car it was. The cause was the vehicle pool in `gameconfig.xml` (see [`addon-vehicles.md`](addon-vehicles.md#rules-enhanced-enforces)), not the cars.

### Known issues

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

Each sound pack is its own folder under `mods/update/x64/dlcpacks/` named after its `audioNameHash`. "Patched" packs had references that don't exist in Enhanced or a missing file in `content.xml`; [`audio.md`](audio.md#one-sound-per-car) has what was changed and why.

Steam launch options: `WINEDLLOVERRIDES="xinput1_4=n,b" %command%` (so Wine loads the ASI loader instead of its built-in `xinput1_4`).

Packs that were tried and turned off live in `~/games/gtav-disabled-addons/` so they can be retried without downloading again. Every edit of a live pack kept the previous version there:

| Folder | Holds the packs as they were before… |
|---|---|
| `backup-before-sounds/` | each car got its own engine sound (`audioNameHash`) |
| `backup-before-texfix/` | BC7/DXT3 textures were re-encoded (Mustang, BMW, Agera, Jesko, 812) |
| `backup-before-volume/` | the engine sounds were lowered 6 dB |
| `backup-before-names/` | the menu names and brands were set |

Saves were backed up to `~/games/gtav-enhanced-backup-20261117-0824` before the first mod went in.

## Achievements

- Mods don't block achievements; the game doesn't detect Script Hook V in story mode.
- **Cheat codes do** (keyboard combos and phone numbers): achievements stay off for that session until a save is reloaded.
- Back up the saves before installing anything. They are tiny (a few MB) and a broken mission is the realistic risk, not a ban.

## After a game update

Rockstar updates break three things:

1. **Script Hook V** checks the game version. Get the new build from dev-c.com when it's out. Its log (`ScriptHookV.log`) prints `INIT: Success, game version is …` when it accepts the game.
2. **`mods/update/update.rpf`** is a full copy of the game's `update.rpf` with our `dlclist.xml` lines and the bigger vehicle pool added. After an update it is stale and must be rebuilt: copy the new `update/update.rpf` into `mods/update/` and re-add the custom `dlcpacks:/…/` items (see [`modding-on-linux.md`](modding-on-linux.md#editing-updaterpf)) and raise `MaxExtraVehicleModelInfos` in `common/data/gameconfig.xml` again (640 → 800; without it only 3 add-on cars fit, see [`addon-vehicles.md`](addon-vehicles.md#rules-enhanced-enforces)). Then run `rpftool verify` before starting the game.
3. **Add-On Vehicle Spawner** finds its hook by pattern; its log (`AddonSpawner/AddonSpawner.log`) says `Found InitVehicleArchetype` when it still works.
