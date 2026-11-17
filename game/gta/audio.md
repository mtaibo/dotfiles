# Add-on engine sounds on GTA V Enhanced

## How a sound pack works

A sound mod is its own DLC pack with only audio:

```
x64/audio/<name>_game.dat151.rel     game objects: CarAudioSettings → VehicleEngineAudioSettings + GranularEngineAudioSettings
x64/audio/<name>_sounds.dat54.rel    sound tree (wrappers, multitracks, granular sounds, envelopes…)
x64/audio/<name>_amp.dat10.rel       optional: custom modular synth programs
x64/audio/sfx/dlc_<name>/*.awc       the waves (player + _npc banks)
```

`content.xml` declares them as `AUDIO_GAMEDATA`, `AUDIO_SOUNDDATA`, `AUDIO_SYNTHDATA` (the path omits the `10.rel`/`54.rel` suffix) and `AUDIO_WAVEPACK` (a folder). A car uses it through `<audioNameHash>` in its `vehicles.meta`; the name must match a `CarAudioSettings` object. If nothing matches, the game falls back to a generic sound, so a missing pack makes the car silent rather than crashing it.

## The pack that crashed

The Audi R8 2023 expects `audr8tteng`, Legacy_DMC's [twin-turbo 5.2 V10](https://www.gta5-mods.com/vehicles/twin-turbo-audi-lamborghini-5-2l-v10-sound-mod-sp-add-on-fivem). With that pack installed, story mode crashed on load at the same address as the bad render-target texture (`GTA5_Enhanced.exe+0x13778cf`, see [`addon-vehicles.md`](addon-vehicles.md#crash-history)). Without it, the R8 loaded fine but was silent.

What was checked and turned out fine:

- Object sizes match Enhanced exactly (`CarAudioSettings` 292 bytes, granular 244, engine 232, same as all 256 base-game cars).
- No hash table entries are missing: even Rockstar's own packs have none for car audio objects.
- `DataUnkVal` (`31554421`) is a per-build number; official DLCs each have a different one.
- Every hash reference resolves once all 86 audio rel files of the official DLCs are indexed (synth defs live in DLC `dat10` files; `3817852694` is the null sound, used 43,000+ times by the game).
- CodeWalker re-saves the pack byte-for-byte; the only types it can't round-trip on Enhanced are radio/music ones.
- Its synth programs use only opcodes that the 4,012 official synths also use.

What sets it apart from every official engine and from the pack that works:

| | Twin-turbo (crashes) | Aquaphobic V10 (works) | Official engines |
|---|---|---|---|
| Custom synths (`dat10`) | 5 | none | none in car packs |
| Granular stream sample rate | 48000 / 42000 Hz | 32000 Hz | 32000 Hz |
| Grains per stream | up to 575 | up to 548 | up to ~380 |

That's a strong pattern, not a proof: the game's code is encrypted on disk and wasn't debugged live. `rpftool verify` flags both traits.

## The pack that works

Aquaphobic's [Lamborghini Huracán / Audi R8 5.2 V10](https://www.gta5-mods.com/vehicles/lamborghini-huracan-audi-r8-5-2-v10-engine-sound-oiv-add-on-fivem-sound) v3.0 (`aq68lam52v10`). It's also what the R8 conversions on Nexus' Enhanced section use. Install: the `dlc.rpf` from the OIV (it's a zip) into `mods/update/x64/dlcpacks/aq68lam52v10/`, add `dlcpacks:/aq68lam52v10/` to `dlclist.xml`, set the car's `audioNameHash` to `aq68lam52v10` (`rpftool cat` / `put` on `data\vehicles.meta`).

## One sound per car

Every car got a sound pack for its real engine (or the closest thing that passes the checks). The same round of checks found problems in most packs before they reached the game:

| Car | Engine | Pack (`audioNameHash`) | What the checks found | Fix |
|---|---|---|---|---|
| Audi R8 2023 | 5.2 V10 | Aquaphobic Huracán/R8 V10 (`aq68lam52v10`) | clean | — |
| Huracán Twin Turbo | 5.2 V10 | same pack | clean | — |
| ABT RS7-R | 4.0 TFSI V8 TT | Aquaphobic AMG M177 4.0 V8 TT (`aq67merm177`) | the RS6 EA825 pack had granular streams at 48 kHz | used the M177 instead |
| Revuelto SV 2027 | 6.5 V12 | Aquaphobic Aston Martin 5.9 V12 (`aston59v12`) | both Lamborghini V12 packs (Veneno, Gintani SVJ) ship custom synths | used the closest clean NA V12 |
| BMW M4 G82 | S58 I6 TT | Aquaphobic S58 (`aq70bmws58`) | `SynchronisedSynth` points at a sound that doesn't exist in Enhanced | set to the null sound (`3817852694`, as 16 official engines do) |
| Agera RS, Jesko Attack | 5.0 V8 TT | Aquaphobic Koenigsegg 5.0 V8 TT (`aq88koe50v8`) | rev-limiter pop sound doesn't exist | official pop `1755537032` (base-game `MultitrackSound`, used by 208 engines) |
| Mustang Dark Horse | Coyote 5.0 V8 | Aquaphobic F-150 Coyote (`aq02coyotef150`) | clean, but its readme names `aq26mit4b11t` (another pack) | used the name that matches the pack's hash |
| Bugatti Tourbillon | 8.3 V16 | Aquaphobic Pagani Zonda M297 V12 (`aq59pagm297`) | no V16 exists; rev-limiter pop missing | high-revving NA V12; official pop |
| Ferrari 812 Superfast/Competizione | 6.5 V12 | Legacy_DMC 812 Superfast (`lg86fer812sf`) | `content.xml` lists an `_amp.dat` that isn't in the pack (the bug that hung the first R8) | removed that entry; nothing references its synths |
| Ferrari F80 | 3.0 V6 TT | Aquaphobic Alfa 2.9 V6 TT (`alfa690t`) | clean | — |
| Lamborghini Urus SE | 4.0 V8 TT | Legacy_DMC Urus 4.0 V8 Capristo (`lg51uruscapri`) | `content.xml` lists an `_amp.dat` that isn't in the pack (same as the 812) | removed that entry |
| Ford F-250 Super Baja | 7.3 V8 | Aquaphobic F-150 Coyote (`aq02coyotef150`) | no 7.3 V8 pack exists | Ford truck V8 from the same family |

Lessons:

- **Readmes lie; hashes don't.** Check the name against the `CarAudioSettings` hash in the pack (`joaat(name)`), not the readme.
- **References that don't resolve in Enhanced are common** even in clean-looking packs (sounds that existed in Legacy DLCs). Point them at an official object used in the same field by vanilla engines; `rpftool relset` does it, and it's safe only because CodeWalker re-saves these files byte for byte (check with `relresave` first).
- A pack CodeWalker can't parse (the AMG M279 V12) is out; the game might read it, but nothing can be verified.

## Volume

Every Aquaphobic pack sets `GranularEngineAudioSettings.MasterVolume` to `900` (+9 dB, in hundredths of a dB), the loudest value any official engine uses (official: median 0, p90 +4 dB, max +9 dB over 674 engines; `rpftool relstats GranularEngineAudioSettings MasterVolume`). In game it drowned the radio.

All packs are now **9 dB below their original value**, i.e. at 0 dB like a typical official engine: `900` → `0`, the 812's `850` → `-50`, the Urus Capristo's `700` → `-200`. Steps on 2026-11-17: −6 dB made the radio audible, and the user then asked for quieter still (a −3 dB step was a misunderstanding and never reached the game). Set with `rpftool relfield <rpf> <rel> GranularEngineAudioSettings MasterVolume <value>`, which only runs when CodeWalker re-saves the file byte for byte and checks that only that field's bytes changed. ±100 is ±1 dB. Previous versions are in `~/games/gtav-disabled-addons/backup-before-volume*/`.

## Tools

- `rpftool reldump <rpf> <rel> [summary]`: objects with type and size; `FIELDS=1` prints every field, `HEADER=1` the file header.
- `rpftool relht`: hash-table offsets per object type.
- `rpftool relresave`: CodeWalker round-trip with a per-type diff.
- `rpftool synthops`: disassembles `dat10` synths into opcode signatures.
- `rpftool awcinfo`: streams, chunk types, codec, sample rate, grain and loop counts. CodeWalker decrypts the official (encrypted) `.awc` files.

## Ideas not tried

- Make the twin-turbo work by resampling its granular streams to 32 kHz (grain offsets would have to be rescaled too) and dropping its custom synths for official ones. Grains and loops are sample offsets, so this is real work, and the result might still crash if the cause is something else.
