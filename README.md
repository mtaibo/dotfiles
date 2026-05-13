# Dotfiles

I'm a first-year computer engineering student and this repo contains all the configuration files I use to set up my machines exactly how I like them for programming, studying, and my personal projects.

## How it started

I wanted a single place to configure **all my devices** — my MacBook, my NixOS desktop, and my Raspberry Pi — so they all share the same terminal, the same editor setup, the same shortcuts, and the same look & feel. If a machine breaks or I get a new one, I can reproduce my whole environment with a single command.

Everything here is:
- **Reproducible** — one command and your machine is set up
- **Portable** — share the same config across different machines
- **Easy to edit** — all config files are in one place, plain text
- **Understandable** — organized so even future-me can figure it out

## What's managed here

| What | Details |
|---|---|
| **Shell** | Zsh with Starship prompt, autosuggestions, syntax highlighting |
| **Terminal** | Kitty with Tokyo Night theme and FiraCode Nerd Font |
| **Editor** | Neovim (Lazy.nvim, Telescope, LSP, GitSigns) + VS Code |
| **Browser** | Firefox with Tokyo Night CSS, uBlock Origin |
| **AI tools** | OpenCode |
| **System (Linux)** | Hyprland WM, SDDM, GRUB, NVIDIA, PipeWire audio |
| **System (macOS)** | Custom Kitty icon, fullscreen shortcut (Cmd+K), wallpaper |

## Machines

| Hostname | OS | Architecture | Role |
|---|---|---|---|
| `nixos` | NixOS 25.11 | x86_64 | Desktop PC (Intel + NVIDIA) |
| `macbook` | macOS (nix-darwin) | aarch64 (Apple Silicon) | Daily laptop |
| *(raspberry)* | NixOS | aarch64 | Home server / tinkering |

## How it's organized

```
dotfiles/
├── flake.nix              # Entry point — defines all machines
├── flake.lock             # Pins all dependency versions
├── hosts/                 # Per-machine config
│   ├── desktop/           # NixOS desktop (GRUB, hardware, locale)
│   └── macbook/           # macOS laptop (fonts, services, wallpaper)
├── modules/               # Shared logic (Nix expressions)
│   ├── home/              # Home Manager — user-level config
│   │   ├── default.nix    # Hub: imports everything below
│   │   ├── packages.nix   # CLI tools I always install
│   │   ├── shell.nix      # Zsh + Starship
│   │   ├── editors/       # Neovim + VS Code
│   │   └── browsers/      # Firefox policies & bookmarks
│   └── nixos/             # System-level config (Linux only)
│       ├── boot.nix       # GRUB, quiet boot, splash image
│       ├── networking.nix # Hostname, NetworkManager
│       └── desktop/       # Hyprland + NVIDIA drivers
└── assets/                # Raw config files & static assets
    ├── kitty/             # Kitty terminal config
    ├── hypr/              # Hyprland WM + wallpaper
    ├── zsh/               # Zsh aliases (eza, bat shortcuts)
    ├── starship/          # Starship prompt icons
    ├── opencode/          # OpenCode AI config
    ├── firefox/           # Tokyo Night Firefox CSS theme
    ├── grub/              # GRUB boot splash image
    └── macos/             # Kitty icon + Automator workflow
```

## How it works

This repo uses **Nix flakes** + **Home Manager** to declare everything:

1. **`flake.nix`** is the brain — it takes inputs (nixpkgs, home-manager, nix-darwin) and builds three outputs: one for each machine.
2. **`hosts/desktop/`** and **`hosts/macbook/`** define what makes each machine unique (hostname, hardware, macOS-specific stuff like fonts and wallpaper).
3. **`modules/home/`** is the shared core — both machines import this. It defines my user packages, shell, editors, and browser. The macOS host overrides a few paths (like `homeDirectory`).
4. **`assets/`** holds the plain config files (`.zshrc`, `kitty.conf`, CSS themes, etc.). Home Manager symlinks them into place at `~/.config/`.

For example, when I run `darwin-rebuild switch` on my MacBook, Nix:
- Reads `flake.nix` → finds `darwinConfigurations.macbook`
- Builds the system config from `hosts/macbook/default.nix`
- Imports my shared home config from `modules/home/`
- Symlinks all config files from `assets/` into `~/.config/`
- Runs activation scripts (sets wallpaper, replaces Kitty icon, registers the `Cmd+K` shortcut)

On my NixOS desktop it's the same but with `nixos-rebuild switch`, however, `update` command works on every machine as an alias for the proper command.

## Tools I use daily

| Tool | What for |
|---|---|
| **Kitty** | Terminal emulator (fast, GPU-accelerated) |
| **Zsh** | Shell with autosuggestions and syntax highlighting |
| **Starship** | Prompt — shows git status, versions, etc. |
| **Neovim** | Main editor with LSP, fuzzy finder, file tree |
| **VS Code** | When I need a GUI editor |
| **Firefox** | Browser with Tokyo Night theme |
| **eza** | Modern `ls` replacement with icons + git status |
| **bat** | `cat` with syntax highlighting |
| **fastfetch** | System info on terminal start |
| **OpenCode** | AI coding assistant in the terminal |
| **Git / GitHub CLI** | Version control |

## How to use

You'll need **Nix** with flakes enabled:

```bash
# On macOS (standalone home-manager)
nix run home-manager/release-25.11 -- switch --flake ~/dotfiles

# On macOS (nix-darwin)
sudo darwin-rebuild switch --flake ~/dotfiles#macbook

# On NixOS
sudo nixos-rebuild switch --flake ~/dotfiles#nixos
```

> **Note:** This is **my** personal config — hardware paths, usernames, and programs are tailored to my machines. But feel free to fork it and adapt it to you.
