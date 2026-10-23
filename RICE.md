<div align="center">

# 🍚 The rice

**A glassy, low-colour, macOS-inspired Hyprland desktop, declared entirely in Nix.**

</div>

---

This is the tour of how my NixOS desktop looks and why. Everything here lives in this repo: nothing is clicked together by hand, so `nixos-rebuild` on a fresh machine gives back the same desktop down to the last pixel of blur. The [README](README.md) covers the machines and how the flake fits together; this file is only about the look.

## The idea

I wanted my PC to feel as calm as a Mac: dark greys, frosted glass, one accent colour and nothing shouting for attention. Most rices go for neon and rainbow; I went the other way.

- **One palette, everywhere** — [Stylix](https://github.com/nix-community/stylix) takes a single colour scheme, font set and wallpaper and themes every app it knows. Change one hex value and the bar, terminal, browser, lock screen and login screen all follow.
- **Glass, not boxes** — panels are translucent with a faint white edge, and Hyprland blurs whatever is behind them. The bar, notifications and launcher all share the same recipe.
- **Colour only when it means something** — text and chrome are grey. Blue marks the accent (git changes, a nix shell), red means something failed. Syntax highlighting is the only place the full palette shows up.
- **Declarative to the end** — every part is a Nix module. Where an app only takes a config file, the file is generated from Nix with the palette interpolated in.

## At a glance

| Part | Tool | Module |
|---|---|---|
| Theme engine | Stylix | [`modules/nixos/desktop/stylix.nix`](modules/nixos/desktop/stylix.nix) |
| Login screen | SDDM + custom QML theme | [`modules/nixos/desktop/greeter.nix`](modules/nixos/desktop/greeter.nix), [`assets/sddm/`](assets/sddm/) |
| Lock + login design | Shared Nix attrset | [`modules/lockscreen.nix`](modules/lockscreen.nix) |
| Window manager | Hyprland | [`modules/home/desktop/hyprland.nix`](modules/home/desktop/hyprland.nix) |
| Wallpapers | swww, a rofi picker and matugen accents, on SUPER+W | [`modules/wallpapers.nix`](modules/wallpapers.nix), [`modules/home/desktop/wallpaper.nix`](modules/home/desktop/wallpaper.nix) |
| Top bar | Waybar | [`modules/home/desktop/waybar.nix`](modules/home/desktop/waybar.nix) |
| Launcher | Vicinae | [`modules/home/desktop/vicinae.nix`](modules/home/desktop/vicinae.nix) |
| Notifications | dunst | [`modules/home/desktop/dunst.nix`](modules/home/desktop/dunst.nix) |
| Lock screen | hyprlock | [`modules/home/desktop/hyprlock.nix`](modules/home/desktop/hyprlock.nix) |
| Terminal | kitty | [`modules/home/desktop/kitty.nix`](modules/home/desktop/kitty.nix) |
| Prompt | Starship | [`modules/home/starship.nix`](modules/home/starship.nix) |
| System info | fastfetch | [`modules/home/fastfetch.nix`](modules/home/fastfetch.nix) |
| Browser | Firefox + firefox-gnome-theme | [`modules/home/browsers/firefox.nix`](modules/home/browsers/firefox.nix) |

The desktop-only Home Manager modules sit in `modules/home/desktop/` and are imported only by `hosts/desktop`, because `modules/home` is shared with the Mac. Starship and fastfetch are shared by all three machines.

## From power button to desktop

```
  Power on
     │
     ▼
  systemd-boot (signed by lanzaboote, Secure Boot on)
     │
     ▼
  SDDM (weston) ──▶ glass theme          login screen, identical to the lock screen
     │
     ▼  password OK
  Hyprland
     │  exec-once: import env into systemd, start hyprland-session.target
     ▼
  hyprland-session.target ──▶ graphical-session.target
     │
     ├──▶ swww         wallpaper daemon, then the last wallpaper is restored
     ├──▶ waybar       top bar
     ├──▶ dunst        notifications (D-Bus activated)
     └──▶ vicinae      launcher daemon, so SUPER+Space opens instantly
```

Nothing is started from a long `exec-once` list. Every long-running piece is a systemd user service tied to the Hyprland session, so it starts with the session, restarts if it crashes and stops when I log out.

## 🎨 Palette, fonts and cursor

Stylix doesn't ship a scheme I liked for this, so the palette is my own base16 scheme, based on the greys macOS uses in dark mode:

| Slot | Hex | Role |
|---|---|---|
| `base00` | `#1c1c1e` | Background |
| `base01` | `#2c2c2e` | Raised surfaces |
| `base02` | `#3a3a3c` | Selection |
| `base03` | `#8e8e93` | Comments, muted text, inactive things (bright enough to read on glass) |
| `base04` | `#aeaeb2` | Secondary text |
| `base05` | `#e5e5ea` | Foreground |
| `base06` | `#f2f2f7` | Light foreground |
| `base07` | `#ffffff` | Brightest text (clock, active workspace) |
| `base08` | `#e5736b` | Red — errors, failed commands |
| `base09` | `#e0a060` | Orange |
| `base0A` | `#e5cc73` | Yellow — git rebase/merge in progress |
| `base0B` | `#7cc68a` | Green |
| `base0C` | `#7fc8d9` | Cyan |
| `base0D` | `#6aa9f2` | **Blue — the one accent** |
| `base0E` | `#c49bdc` | Purple |
| `base0F` | `#a89279` | Brown |

The accents are deliberately muted versions of Apple's system colours, so even syntax highlighting doesn't get loud.

| | Choice | Why |
|---|---|---|
| **UI font** | Inter | The closest thing to San Francisco in nixpkgs |
| **Monospace** | FiraCode Nerd Font Mono | Ligatures plus every icon the bar and prompt use |
| **Cursor** | Bibata Modern Classic, 24 px | Clean and sharp, with a macOS-like shape |
| **Opacity** | terminal 0.7 · popups 0.85 · desktop 0.6 | Enough to see the wallpaper, not so much that text suffers |

## 🧊 How the glass works

Every glass surface is two layers:

1. **The fill** — the component paints itself with `base00` at partial alpha (`rgba(28, 28, 30, 0.45)` on the bar, `#1c1c1e99` on notifications) and a 1 px border of white at 8–15 % opacity. That faint edge is what makes it read as glass rather than just "transparent".
2. **The blur** — Hyprland blurs whatever is behind specific layer-shell surfaces, picked by namespace:

```nix
decoration.blur = { enabled = true; size = 5; passes = 2; brightness = 0.7; contrast = 1.0; noise = 0.02; vibrancy = 0.1; };

layerrule = [
  "blur, waybar"        "ignorezero, waybar"
  "blur, notifications" "ignorezero, notifications"
  "blur, vicinae"       "ignorealpha 0, vicinae"
];
```

`ignorezero` stops Hyprland from blurring the fully transparent gaps between the bar's pills, so only the pills themselves are frosted. The blur is deliberately light (2 passes of size 5), so the shapes of the wallpaper still show through, and `brightness = 0.7` darkens whatever is behind the glass. That is what keeps grey text in a 70 % transparent terminal readable even over a bright wallpaper; a heavier, undarkened blur turned bright skies into a milky haze.

The login screen does its own blur in Qt (see below), since it runs before Hyprland exists.

## 🔑 Login screen — SDDM with a custom theme

The first thing after boot looks exactly like the lock screen: same date, clock, name, password pill and blurred wallpaper (see [hyprlock](#-lock-screen--hyprlock) below). No user list, no session picker, no buttons. Booting and unlocking feel like the same thing, as on a Mac.

It's SDDM running a theme I wrote in QML ([`assets/sddm/Main.qml`](assets/sddm/Main.qml)). I first tried greetd + ReGreet because Stylix themes it, but ReGreet always shows a user and a session selector. A custom SDDM theme gives full control.

### One design, two screens

The layout isn't copied between the two: it's defined once in [`modules/lockscreen.nix`](modules/lockscreen.nix) (positions, font sizes and weights, colours from Stylix, blur, texts, fade time). `hyprlock.nix` turns it into hyprlock's config, and `greeter.nix` writes the same values into a generated `Style.qml` (JSON, which is valid JavaScript) that the theme reads. Move the clock or change a colour there and both screens follow.

`Main.qml` then draws it with hyprlock's rules:

- **Positions** are offsets from the screen centre with y pointing up, and **font sizes** are points at 96 dpi (`px = pt × 4/3`), the way hyprlock renders them.
- **Background:** the wallpaper through Qt's `MultiEffect` blur, then a black layer at 30 % opacity. That layer multiplies every colour by 0.7, which is exactly what hyprlock's `brightness = 0.7` does. Vibrancy becomes a small saturation boost. The wallpaper is decoded at 480 px wide and upscaled smoothly before blurring, because a full-resolution source makes `MultiEffect` leave a blocky pattern. It's also drawn 96 px larger than the screen, so the blur's dark fringe stays off the edges.
- **Input:** the same 260 × 44 pill showing centred dots (25 % of the height, spaced at 30 % of a dot) instead of characters. The edge turns yellow while PAM checks the password, and on a wrong one it turns red and shows "Contraseña incorrecta" for 2 s.
- The cursor is hidden and everything fades in over 400 ms.

### Under the hood

- **No choices to make:** there's one user and one session, so the theme logs in as SDDM's last user (falling back to `migueltaibo`) into the last session, which is always Hyprland (`defaultSession = "hyprland"`). The name under the clock is my account's description, like hyprlock's `$DESC`.
- **Keyboard and cursor:** `services.xserver.xkb.layout = "es"` gives SDDM's compositor (weston) the Spanish layout, so the password types the same as in the session. The cursor is Stylix's Bibata.
- **A content hash in the theme's name** (e.g. `glass-467c1cfb`): Qt caches compiled QML by file path and modification time, and every file in the Nix store has the same 1970 mtime. Under a fixed path like `themes/glass/Main.qml`, the greeter kept running the very first compiled version after the theme changed. Hashing `Main.qml` and `Style.qml` into the name gives each version its own path, so the cache can never serve a stale one.

> Switching display managers can't be done live: use `nixos-rebuild boot` and reboot, not `switch`.

## 🪟 Window manager — Hyprland

Hyprland runs from the NixOS module (`programs.hyprland`), and its whole config is written in Nix through Home Manager's `wayland.windowManager.hyprland` (with `package = null`, so the system package is used). That's what lets Stylix reach it.

### Look

| Setting | Value |
|---|---|
| Gaps | 5 px between windows, 10 px to the screen edge |
| Borders | 2 px, active `rgba(ddddddee)` / inactive `rgba(595959aa)` |
| Corners | 10 px |
| Layout | dwindle |
| Animations | custom `snappy` bezier `0.05, 0.9, 0.1, 1.05`: windows and fades in 300 ms, workspaces in 200 ms, with a slight overshoot that feels springy |

Stylix wants to paint the active border in the blue accent. I override it with `lib.mkForce` to keep borders grey: with the accent on every focused window, blue would stop meaning anything.

### Keybindings

| Keys | Action |
|---|---|
| `SUPER` + `Space` | Launcher (Vicinae) |
| `SUPER` + `Q` | Terminal (kitty) |
| `SUPER` + `F` | Firefox |
| `SUPER` + `R` | Claude desktop app |
| `SUPER` + `C` | Close window |
| `SUPER` + `Shift` + `F` | Fullscreen |
| `SUPER` + `V` | Toggle floating |
| `SUPER` + `L` | Lock screen |
| `SUPER` + `W` | Next wallpaper |
| `SUPER` + `Shift` + `W` | Pick a wallpaper (with previews) |
| `SUPER` + `M` | Exit Hyprland |
| `SUPER` + `h` `j` `k` `l` | Move focus |
| `SUPER` + `Shift` + `h` `j` `k` `l` | Resize window |
| `SUPER` + `Alt` + `h` `j` `k` `l` | Move window within the layout |
| `SUPER` + `1`…`9` | Switch workspace |
| `SUPER` + `Shift` + `1`…`9` | Send window to workspace |
| `SUPER` + drag | Left button resizes, right button moves |
| `Print` | Screenshot a region to the clipboard (`grim` + `slurp`) |
| Volume keys | `wpctl` up/down 5 %, mute |

The workspace bindings are generated with a small `lib.concatMap` over `1..9` instead of 18 hand-written lines.

## 🖼️ Wallpapers

`SUPER + W` switches to the next wallpaper with a circle that grows out from the cursor, and `SUPER + Shift + W` opens the picker. [swww](https://github.com/LGFae/swww) draws them; a small `wallpaper` script (`next`, `prev`, `random`, `pick`, `set FILE`) drives it.

### The picker

Modelled on the rofi wallpaper menu from [Hyprlust](https://github.com/NischalDawadi/Hyprlust): a glass window 75 % of the screen wide with one row of five large square previews and the name under each, plus a ". random" card first (its preview is the wallpaper it will pick). Type to filter, arrows or the mouse to choose, Enter or click to apply.

```
╭──────────────────────────────────────────────────────────────────────╮
│  ( Buscar fondo…                                                  )  │
│  ┏━━━━━━━━━┓ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │
│  ┃  ▓▓▓▓▓  ┃ │  ▓▓▓▓▓  │ │  ▓▓▓▓▓  │ │  ▓▓▓▓▓  │ │  ▓▓▓▓▓  │         │
│  ┃ . random┃ │  curvy  │ │ darkest │ │ forest  │ │  lake   │         │
│  ┗━━━━━━━━━┛ └─────────┘ └─────────┘ └─────────┘ └─────────┘         │
╰──────────────────────────────────────────────────────────────────────╯
```

The theme is generated in Nix with the same glass as the bar (`base00` at 60 %, faint white edge, blurred by a `rofi` layer rule). The selected card's border is the wallpaper's accent colour. The previews are 400 × 400 thumbnails made once at build time, so the menu opens instantly instead of decoding 5K images.

### Colours that follow the wallpaper

Every time the wallpaper changes, [matugen](https://github.com/InioX/matugen) reads it and builds a Material You palette, and the script makes every open kitty reload (`SIGUSR1`). Only the accent tones are used, which keeps the "one accent" idea: the accent simply becomes the wallpaper's colour.

- **Terminal:** matugen's primary, tertiary and secondary tones replace the terminal's blue, magenta and cyan (and their bright versions). That's what `ls`/`l` use for folders and dates, what the prompt uses for git status and a nix shell, and what fastfetch uses for its icons. Mountain turns them sky blue, the forest turns them green.
- **Kept fixed on purpose:** red, green and yellow keep their meaning (errors, `git diff`, warnings), and the greys, background and foreground stay Stylix's so text stays readable on the glass.
- **Why matugen and not wallust** (which Hyprlust uses): wallust takes colours straight from the picture, and on dark wallpapers several of them came out dark grey, unreadable on a dark terminal. Material You tones have a guaranteed lightness for dark themes, so every wallpaper gives a readable accent.
- kitty loads the result with `globinclude matugen-colors.conf` after Stylix's colours; `eza` no longer uses `--color-scale=size`, whose fixed RGB greens ignored the palette.

**The collection** ([`modules/wallpapers.nix`](modules/wallpapers.nix)) is mostly dark, low-colour pictures that already ship in nixpkgs under free licences, so nothing is downloaded from random sites and the set is reproducible:

| File | From | |
|---|---|---|
| `mountain.png` | KDE Plasma "Mountain" (dark variant) | **Default.** Snowy peaks against a grey night sky |
| `darkest-hour.jpg` | KDE Plasma "Darkest Hour" | A misty lake at blue hour |
| `forest-path.jpg` | KDE Plasma "Path" | A path through a dark pine forest |
| `curvy.png` | GNOME "curvy" (dark) | Grey curves; converted from JPEG XL at build time, since swww can't read it |
| `nineish-dark-gray.png` | NixOS artwork | The NixOS logo on dark grey |
| `lake.jpg` | [`assets/wallpapers/`](assets/wallpapers/) | My original sunny lake |

**One wallpaper everywhere.** The choice is stored as a symlink, `/var/lib/wallpaper/current`, and three things read it: swww restores it when the session starts, hyprlock uses it as the lock-screen background, and the SDDM theme uses it on the login screen, which keeps login and lock identical. It lives outside `$HOME` because my home is `0700` and the greeter runs as the `sddm` user. `systemd.tmpfiles` creates the directory (owned by me, readable by everyone) and the first link to the default; the `L` rule never overwrites an existing link, so the choice survives rebuilds. If the link ever breaks, the login screen falls back to Stylix's image.

`stylix.image` is the default wallpaper too, but Stylix's hyprpaper is turned off in favour of swww, and Hyprland's own mascot wallpaper is disabled so nothing flashes before swww draws.

## 📊 Top bar — Waybar

A floating bar 8 px from the top and 10 px from each side, built from separate glass pills instead of one solid strip:

```
╭────╮╭─────────────╮╭──────────╮                ╭────────────────────────────────────╮
│    ││  1  2  3    ││  kitty   │                │  ⋯  󰈀  󰂯  󰕾   jue 23 oct  14:32   │
╰────╯╰─────────────╯╰──────────╯                ╰────────────────────────────────────╯
 logo   workspaces     active app                   tray · network · bt · volume · clock
```

| Module | Shows | Click |
|---|---|---|
| Logo | Nix snowflake | Opens Vicinae |
| Workspaces | Numbers, sorted. The active one is white on a 14 % white highlight, the others grey | Switches workspace |
| Active window | The app's class in semibold, or "Escritorio" when no window is focused, and the pill hides itself when empty | — |
| Tray | App tray icons at 16 px | App menu |
| Network | 󰈀 ethernet · 󰖩 wifi · 󰈂 disconnected (dimmed) | Tooltip with interface and IP |
| Bluetooth | 󰂯 on · 󰂱 connected · 󰂲 off (dimmed) | blueman; the tooltip lists connected devices |
| Volume | 󰕿 󰖀 󰕾 by level · 󰝟 muted (dimmed) | Left: pavucontrol · right: mute · scroll: ±5 % |
| Clock | `jue 23 oct  14:32` in Spanish, semibold white | Tooltip with a month calendar |

The CSS is hand-written. Stylix's Waybar target is turned off because it can't do the pill layout, but every colour comes from `config.lib.stylix.colors`, so the bar still follows the palette. It runs as a systemd user service.

## 🔍 Launcher — Vicinae

`SUPER + Space` opens [Vicinae](https://vicinae.com), a Raycast-style launcher. Beyond apps, it searches files and emoji, keeps a clipboard history, does maths and runs commands, which makes it the closest thing to Spotlight or Raycast on Linux.

- It runs as a daemon (systemd user service), so `vicinae toggle` opens it instantly instead of cold-starting.
- Stylix generates a `stylix` theme for it and sets its window opacity to 0.85. Hyprland blurs the `vicinae` layer behind it.
- 14 px corners. It closes when it loses focus and always reopens on the root search.

## 🔔 Notifications — dunst

Notifications drop in at the top right, just under the bar, like on macOS:

- 360 px wide, up to 160 px tall, at most 5 on screen with 8 px between them, offset `(12, 52)` to clear the bar.
- The same glass as the bar: `base00` at 60 %, a 1 px white 15 % frame, 14 px corners, blurred by Hyprland's `notifications` layer rule.
- Bold title over the body in Inter, with the icon on the left (32–48 px).
- Low urgency disappears after 4 s and normal after 6 s. Critical notifications keep Stylix's red frame, sit on a more opaque background and stay until dismissed.
- Left click runs the notification's action and closes it; right click clears them all.

It's `services.dunst` in Home Manager, D-Bus activated, so there's nothing to start by hand.

## 🔒 Lock screen — hyprlock

`SUPER + L` locks with hyprlock. It uses Wayland's `ext-session-lock` protocol, so the compositor guarantees nothing shows or gets input while it's up, and a crash leaves the session locked, not open. It checks the password through PAM (`programs.hyprlock.enable` on the NixOS side installs its PAM service).

```
                      jueves, 23 de octubre

                          ██  ██ ██ ██
                          ██  ██ ██ ██      ← $TIME, Inter Bold 110
                          ██  ██ ██ ██

                          Miguel Taibo      ← $DESC (GECOS name)
                    ╭──────────────────────╮
                    │      Contraseña      │ ← glass pill input
                    ╰──────────────────────╯
```

- **Background:** the current wallpaper (whatever SUPER+W last picked) with 3 blur passes, darkened to 70 % brightness, plus a little vibrancy.
- **Type:** the date in Spanish at 22 pt, the clock at 110 pt bold and my name at 15 pt semibold, all in white at 87–93 % opacity.
- **Input:** a 260 × 44 pill with a translucent white 10 % fill and a 15 % outline, which I force over Stylix's solid fill. The dots and the check/fail colours (yellow while checking, red on a wrong password, with "Contraseña incorrecta" for 2 s) come from the palette.
- A 400 ms fade in and out. The cursor is hidden, and pressing Enter with an empty field does nothing.

All of these values come from [`modules/lockscreen.nix`](modules/lockscreen.nix), shared with the login screen so the two always match.

There's no hypridle on purpose: the screen never turns off or locks by itself.

## 🐱 Terminal — kitty

`programs.kitty` in Home Manager. Stylix sets the font (FiraCode Nerd Font Mono, 15 pt), the base16 colour table and the 0.7 background opacity, so Hyprland's blur shows through like the rest of the glass. The blue, magenta and cyan are then overridden by the wallpaper's accent (see [Colours that follow the wallpaper](#colours-that-follow-the-wallpaper)). What I set by hand is only the feel: 15 px padding, no window decorations, ligatures always on and no confirm-on-close. The Mac keeps its own kitty config in `assets/kitty`.

## ❯ Prompt — Starship

A two-line prompt that stays out of the way:

```
 dotfiles  main ✘+                                              󱎫 3s
❯
```

**Line one, left to right:**

| Part | Style |
|---|---|
| OS icon | White. `` NixOS, `` macOS, `` Raspberry Pi OS |
| Hostname | Grey, and only over SSH, with a `` prefix |
| Directory | Bold white, the last 3 levels or from the repo root, with a `󰌾` in red if read-only |
| Git branch | Grey, with a `` prefix |
| Git state | Yellow, only during a rebase/merge/cherry-pick, with progress |
| Git status | Blue — the accent marks "you have changes" |

**Right side** (pushed over with `$fill`): the project's language and version, all in the same grey instead of a colour per language (Nerd Font symbols for ~40 languages and tools); a `nix shell` in blue; and the last command's duration if it took more than 2 s.

**Line two:** just `❯`, white when the last command succeeded and red when it failed. In vi mode it flips to `❮`.

The colours are named terminal colours (`blue`, `bright-black`, …), so they come from the terminal's palette. On the desktop that means the blue accent follows the wallpaper with kitty's; Stylix's Starship target is turned off because it would pin the names to fixed hex values. On the Mac and the Pi they come from the terminal's own theme. It's one module for all three machines.

## 💻 System info — fastfetch

Every new shell opens with an "About This Mac"-style summary:

```
             ╭─ Sistema
             │   OS          NixOS 25.11 (Xantusia)
   (NixOS    │   Kernel      6.12.87
  snowflake  │  󰏖 Paquetes    1754
   image)    │   Ventanas    Hyprland
             │   Terminal    kitty
             │   Shell       zsh
             ╰  󰅐 Encendido   3h 12m

             ╭─ Hardware
             │  󰌢 Equipo      B760M DS3H DDR4
             │   CPU         13th Gen Intel(R) Core(TM) i7-13700K
             │  󰢮 GPU         GeForce RTX 4070
             │   Memoria     4.15 GiB / 15.38 GiB
             │   Disco       28.80 GiB / 195.80 GiB
             ╰  󰍹 Pantalla    2560x1440 @ 144 Hz

             ● ● ● ● ● ● ● ●
```

- **The logo is a real image**: the white NixOS snowflake PNG, drawn with kitty's graphics protocol (`kitty-direct`). Images don't survive tmux or SSH, so the shell checks for kitty, no `$TMUX` and no `$SSH_CONNECTION` first, and otherwise falls back to a small text logo (`NixOS_small`, `raspbian_small` or `macos_small`). The Mac uses the built-in Apple logo.
- **Tree layout** with grey branches, blue icon + label and white values. Labels are padded in Nix rather than with `key.width`, which positions by absolute column and misaligns next to a logo.
- The integrated Intel GPU is hidden (`hideType = "integrated"`), and uptime is formatted as `3h 12m` instead of fastfetch's English "3 hours".
- Like the prompt, it uses named terminal colours, so it follows Stylix through kitty.

## 🦊 Browser — Firefox

Firefox uses [firefox-gnome-theme](https://github.com/rafaelmardojai/firefox-gnome-theme) through Stylix's Firefox target, so it looks like a native GTK app rather than a web page in a frame: tabs and the address bar share one header, buttons and menus are rounded, and every colour comes from the palette. Stylix also sets Inter and FiraCode as the web fonts.

- The theme is versioned per Firefox release, so it's its own flake input pinned to a tag (`v150` today) that `stylix.inputs.firefox-gnome-theme` follows. When nixpkgs moves Firefox to a new major version, the tag gets bumped in `flake.nix`.
- The theme draws minimise/maximise/close buttons that are useless on Hyprland. One CSS rule hides them, added with `lib.mkAfter` so it lands after the theme's `@import` lines (CSS ignores imports that come after other rules).
- The old "dark-theme" add-on is set to `blocked` in the policies, so Firefox uninstalls it from existing profiles instead of letting it paint over the theme.
- uBlock Origin is force-installed, and telemetry, Pocket and studies are off.

## ✏️ Editors and everything else

- **GTK and Qt apps** get Stylix's `adw-gtk3` theme with the palette, so file pickers, pavucontrol, blueman and the rest match.
- **Neovim** keeps its own carbonfox colourscheme (monochrome, transparent background). Stylix's Neovim target is off because it would fight the lazy.nvim setup, and carbonfox already fits the look.
- **VS Code** keeps One Dark Pro. Stylix's VS Code target is off because it writes `userSettings`, which would turn `settings.json` back into a read-only symlink and break the writable-settings trick in `vscode.nix`.

## 🛠️ Changing things

| I want to… | Edit |
|---|---|
| Change the whole colour scheme | `base16Scheme` in `stylix.nix` (or point it at any scheme from `base16-schemes`) |
| Add a wallpaper | Drop it in `assets/wallpapers/` and add it to `modules/wallpapers.nix` |
| Change which terminal colours follow the wallpaper | The matugen templates in `modules/home/desktop/wallpaper.nix` |
| Change the default wallpaper | `default` in `modules/wallpapers.nix` |
| Make glass more or less see-through | `stylix.opacity` for Stylix-themed apps; the `rgba(…, 0.45)` values in `waybar.nix` and `dunst.nix` |
| Change the blur | `decoration.blur` in `hyprland.nix` |
| Restyle the lock and login screens | `modules/lockscreen.nix` (both follow) |
| Change fonts | `stylix.fonts` |
| Add a keybinding | `bind` in `hyprland.nix` |
| Add a bar module | `modules-right` and its block in `waybar.nix`, plus a selector in its CSS |
| Fix Firefox after a major update | Bump the `firefox-gnome-theme` tag in `flake.nix` |

Then `update` (an alias for `sudo nixos-rebuild switch --flake ~/dotfiles#desktop`). Changes to the login screen or the display manager need `nixos-rebuild boot` and a reboot instead.

## Known limits

- **The login theme is hand-written QML.** It only uses stock QtQuick, Controls and Effects, but a big SDDM or Qt update could still need small tweaks to `Main.qml`.
- **Neovim and VS Code aren't on the palette**, on purpose (see above).
- **firefox-gnome-theme tracks Firefox versions.** A major Firefox update without a tag bump can leave parts of the UI slightly off until the tag catches up.
- **The fastfetch image logo is kitty-only.** Everywhere else you get the small text logo.
