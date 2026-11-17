# Add-on vehicles on GTA V Enhanced

## The short version

1. **Prefer mods that ship an Enhanced build** (an `Enhanced/` folder in the archive, resources already Gen9). Every one of those worked first time.
2. If a car only exists for Legacy, it can be converted and fixed (the Audi R8 2023 works that way), but it has to pass every rule below.
3. Run `rpftool verify mods/update` before starting the game. It checks all of this offline.
4. **Make room first**: the game only has space for 3 add-on cars until `MaxExtraVehicleModelInfos` is raised in the mods `gameconfig.xml` (done: 800). Without that, every 4th car looks like a broken car.

## Rules Enhanced enforces

Each rule below cost at least one crash or hang to find.

| Rule | What happens if broken | How to check |
|---|---|---|
| **Room in the vehicle model info pool.** `MaxExtraVehicleModelInfos` in `gameconfig.xml` caps every vehicle not defined in `common.rpf`. The game's own value is 640 and the official DLC vehicles already take 637, so **only 3 add-on cars fit**. The mods copy of `update.rpf` raises it to 800 | Story mode crashes while loading at `GTA5_Enhanced.exe+0x13778cf`, whichever car is the 4th | `verify` (`[global] vehicle model info pool`), `rpftool vehcount` |
| Resources are Gen9: `.yft` v171, `.ytd` v5, `.ydr`/`.ydd` v159, `.ypt` v71 (Legacy is v162/v13/…) | Crash on load or spawn | `rpftool list` prints `[vN]` per file |
| ≤ 128 shaders per drawable and ≤ 128 geometries per model | Crash when the car is drawn (render-thread fatal error, `0x80000003`) | `rpftool inspect` → `shaders=` / `maxGeomsPerModel=` |
| `script_rt_*` textures (dashboard render targets) must look exactly like the game's: A8R8G8B8, 1 mip, `G9_Flags 0x260228`, usage `SKIPPROCESSING` with `G9_UsageData 0x40021A`, byte `+0x23` = 0 | Story mode crashes while loading | `rpftool rawtex` / `verify` compare the 0x80-byte struct with `script_rt_dials_banshee` |
| Textures only in formats the game itself uses (DXT1, DXT5, A8R8G8B8, A8B8G8R8, A8, ATI1, ATI2). BC7 and DXT3 appear in none of ~7,000 official textures | Unconfirmed: suspected for the Mustang before the pool limit was found (see the crash history); kept as a cheap precaution | `verify`, `rpftool texhdr` |
| Every file in `content.xml` must exist in the pack | The game hangs forever on the loading screen | `verify` |
| Mod kit ids must not collide with official kits or other packs | Tuning parts mix between cars | `verify` |

Background: Sollumz's [asset conversion guide](https://docs.sollumz.org/2.8/tutorials/asset-conversion-for-gtav-enhanced) documents the 128 limit and the `script_rt_` format; the exact header bytes came from comparing the R8's texture with all 41 `script_rt_dials_*` textures in the game, which are identical to each other.

## Converting a Legacy car

Pipeline used for the Audi R8 2023 (`audir82023`):

```sh
rpftool <game> convert legacy/dlc.rpf out/dlc.rpf                # Gen8 → Gen9, same loop as CodeWalker's Gen9Converter
rpftool <game> cat out/dlc.rpf content.xml                       # drop items whose files don't exist
rpftool <game> put out/dlc.rpf content.xml fixed-content.xml
rpftool <game> inspect out/dlc.rpf                               # shaders / geometries / script_rt
rpftool <game> yft2xml out/dlc.rpf 'vehicles.rpf\car_hi.yft' xml/car_hi.yft.xml
python3 fixyft.py xml/car_hi.yft.xml xml/car_hi.fixed.yft.xml    # dedupe shaders, merge geometries
rpftool <game> xml2yft out/dlc.rpf 'vehicles.rpf\car_hi.yft' xml/car_hi.fixed.yft.xml   # same for car.yft
rpftool <game> fixrt out/dlc.rpf 'vehicles.rpf\car.ytd'          # ALWAYS last (see below)
```

- `fixyft.py` drops shaders that are byte-identical (the R8 had 11 duplicates: 129 → 118) and, inside each model, merges geometries that share shader, vertex layout and bone palette by concatenating vertex buffers and offsetting indices (163 → 113). The vertex count stays the same; check it, and check every index stays in range.
- **Any re-save of a `.ytd` resets the `script_rt` texture**: CodeWalker's `EnsureGen9()` forces `G9_Unknown_23h = 0x28`. `fixrt` sets the fields and then patches that byte in the serialised data, so it must run after every other `.ytd` edit (the plate change below reset it once).
- **Hex, not decimal**: the vanilla usage value is `4194842` = `0x40021A`. Writing `0x40011A` (one bit off) made story mode crash on load three times before a byte-by-byte comparison found it. Compare raw bytes (`rawtex`), don't trust a field dump.
- `texdump` reads `G9_UsageData` wrongly for converted textures; `rawtex` shows the real bytes.

### Re-encoding a texture in an unofficial format

```sh
rpftool <game> texhdr pack/dlc.rpf | grep -P '\tD3DFMT_(BC7|DXT3)\t'                     # find them (with their mip count)
rpftool <game> texexport pack/dlc.rpf 'x64\vehicles.rpf\car.ytd' tex/ klaxon             # raw BGRA, or a .dds for BC7 (CodeWalker can't decode it)
python3 py/todds.py tex/klaxon.256x256.bgra tex/klaxon_new.dds 9                        # A8R8G8B8 + box-filtered mips, same count
rpftool <game> teximport pack/dlc.rpf 'x64\vehicles.rpf\car.ytd' klaxon tex/klaxon_new.dds
```

`todds.py` needs numpy and Pillow (Pillow decodes BC7). Check with `cmprpf` that only the `.ytd` changed and with `texhdr` that only those textures did, and run `fixrt` last if the `.ytd` has a `script_rt` texture.

### Editing a texture

`texexport` writes mip 0 as raw BGRA; `py/bgra2png.py` and `py/sheet.py` turn them into PNGs and contact sheets to find a texture by eye. To change one, write a DDS (A8R8G8B8 + mip chain, see `py/plate_e.py`) and `teximport` it, then `fixrt`. That's how the R8's EU plate went from "PL" to "E": the strip is in `pigalle_badges`, and the E was built from the existing L glyph (stem + bottom bar, plus copies of the bar at the top and middle).

## Crash history

| Car | Symptom | Cause |
|---|---|---|
| Audi R8 V10 Plus 2017 (Legacy) | Loading screen forever | `content.xml` listed `vehiclelayouts.meta`, not in the pack |
| Same, after removing it | Crash when spawned (render thread, `0x80000003`) | 134 geometries + DXT1 `script_rt` texture |
| Audi R8 2023 (converted, unfixed) | Crash when spawned | 129 shaders, 163 geometries, DXT1 `script_rt` |
| R8 2023 fixed, usage `0x40011A` | Story mode crash on load at `GTA5_Enhanced.exe+0x13778cf` | Wrong usage bit on the render target |
| Skyline R34 (converted) | Crash on load | `script_rt` usage bits wrong + 135 geometries |
| Lamborghini Revuelto (converted) | Crashed together with the R34 | Passes every check on its own; probably innocent |
| R8 2023, final | Works | All rules met |
| Mustang Dark Horse (HAMMER, Enhanced build), with or without its sound, as 4th car | Story mode crash on load at `GTA5_Enhanced.exe+0x13778cf` | First blamed on one BC7 and one DXT3 texture in `fmdh.ytd`; the F80 then crashed the same way as 4th car, which pointed at the pool limit. The same two textures (`toyo_proxes_sport_small_bump`, `klaxon`, shared HAMMER assets) were in the BMW M4, Agera RS, Jesko and 812; all re-encoded as A8R8G8B8 anyway |
| R8 + Revuelto + RS7 + **any** 4th car (Mustang, F80) | Story mode crash on load at `GTA5_Enhanced.exe+0x13778cf` | **Vehicle model info pool full**: 637 official non-base vehicles + 4 add-ons > `MaxExtraVehicleModelInfos` 640. Raised to 800 in `mods/update/update.rpf` → `common/data/gameconfig.xml` |
| All 12 cars, pool at 800 | Works (2026-11-17) | — |

**The pool limit probably explains more of this table than it says.** Three add-on cars always worked and a fourth always crashed at the same address, and several rows above were found while the number of enabled cars was also changing. Two crashes happened with the R8 as the *only* add-on car, so they are real and independent of the pool: the wrong render-target usage bit (`0x40011A`) and the twin-turbo sound pack. The R34/Revuelto row and the BC7/DXT3 guess are not proven; the R34 may well have been a 4th car.

`GTA5_Enhanced.exe+0x13778cf` (game 1.0.1158.16) sits 8 bytes before the call to `InitVehicleArchetype` that Add-On Vehicle Spawner hooks (`e8 ?? ?? ?? ?? 43 89 44 2c`), i.e. in the loop that registers the cars read from every `vehicles.meta`. It faults on a garbage pointer (`0x7d8000f242080`, `0xffffffffffffffff`). That fits running out of model info slots exactly; the texture and sound crashes at the same spot show it is also where other bad DLC data surfaces. **When it crashes there, count first** (`rpftool vehcount mods/update`, or the pool line of `verify`), then look at the newest pack.

## Picking mods

- gta5-mods tags: `vehicles/tags/<make>+enhanced`. The tag means little on its own: the "Enhanced" Revuelto shipped Legacy resources. Check versions with `rpftool list`.
- Authors who publish both builds (HAMMER, for example) put `Legacy/` and `Enhanced/` folders in the archive. Use `Enhanced/`.
- Porsche-branded mods are gone from gta5-mods (reportedly taken down); 911s show up as "Pfister".
- `audioNameHash` in `vehicles.meta` decides the sound. HAMMER's cars use `turismor`, which has no audio object in Enhanced (the Turismo R's own `audioNameHash` is empty), so they use the generic fallback.
- Some mods need extra scripts (`VehFuncs V`, `vStancer`). Pick the variant without them unless you want to install those too.
