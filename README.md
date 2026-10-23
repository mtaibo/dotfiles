<div align="center">

# ❄️ Dotfiles

**One flake for every machine I use.**

<br/>

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Nix](https://img.shields.io/badge/nix-flakes-5277C3?logo=nixos&logoColor=white)
![Machines](https://img.shields.io/badge/machines-macOS%20%7C%20NixOS%20%7C%20Raspberry%20Pi-lightgrey)

</div>

---

These are the dotfiles behind my MacBook, my NixOS desktop and the Raspberry Pi that runs my home server. Everything is declared with Nix flakes and Home Manager, so the three machines share the same shell, the same editors and the same tools, and any of them can be rebuilt from scratch with a single command.

## Why Nix

I used to set up every machine by hand, and every one ended up slightly different. With Nix the whole environment is code:

- **Reproducible** — a new or wiped machine is back to exactly how I like it with one command
- **Shared** — one set of modules for the shell, editors and packages, reused on every machine
- **Versioned** — `flake.lock` pins every dependency, and every change is a commit I can roll back
- **One command** — `update` rebuilds whatever machine I'm on, whether it's macOS, NixOS or the Pi

## The machines

<table>
<tr>
<td width="33%" valign="top">

### 💻 `macbook`
My daily laptop. **nix-darwin** + Home Manager on Apple Silicon: Nerd Fonts, Kitty with a custom icon and a `Cmd+K` shortcut to open it fullscreen, Docker through Colima, and the tooling for my Swift work.

**macOS · aarch64**

</td>
<td width="33%" valign="top">

### 🖥️ `desktop`
My PC. Full **NixOS** with Hyprland on Wayland, themed system-wide by **Stylix** with a glassy, macOS-like look: Waybar on top, hyprlock and dunst to match, a ReGreet login screen, Secure Boot through lanzaboote (dual-booting Windows 11), NVIDIA drivers and PipeWire, plus the same Home Manager setup as the laptop.

**NixOS · x86_64**

</td>
<td width="33%" valign="top">

### 🍓 `tphome`
The Raspberry Pi 5 that hosts [tphome](https://github.com/mtaibo/tphome) and my [personal cloud](https://github.com/mtaibo/tpcloud). Raspberry Pi OS with standalone Home Manager for the shell and Neovim, plus Docker, Tailscale, a local DNS and a Samba share.

**Raspberry Pi OS · aarch64**

</td>
</tr>
</table>

## What's inside

| Area | What I use |
|---|---|
| **Shell** | Zsh with autosuggestions and syntax highlighting, Starship prompt, fastfetch on start |
| **Terminal** | Kitty with FiraCode Nerd Font (themed by Stylix on Linux) |
| **Editors** | Neovim (lazy.nvim, Telescope, Neo-tree, LSP, GitSigns) and VS Code (One Dark Pro, extensions declared in Nix) |
| **CLI tools** | eza, bat, git, GitHub CLI |
| **AI** | Claude Code and OpenCode |
| **Languages** | Node.js, Java 21 + Maven, OCaml + opam |
| **Desktop (Linux)** | Hyprland, Stylix, Waybar, hyprlock, dunst, greetd + ReGreet, Secure Boot (lanzaboote), NVIDIA, Firefox with the GNOME theme coloured by Stylix and uBlock Origin |
| **macOS extras** | Fonts, Kitty icon, Automator fullscreen shortcut, Colima + Docker, XcodeGen |
| **Home server** | Docker, Tailscale, dnsmasq for `tp.home`, Samba storage, SSH keys pulled from GitHub |

## How it's organised

```
dotfiles/
├── flake.nix              # Entry point: defines every machine
├── flake.lock             # Pinned versions of every input
├── hosts/
│   ├── macbook/           # nix-darwin system + Home Manager overrides
│   ├── desktop/           # NixOS system and hardware config
│   └── tphome/            # Standalone Home Manager for the Pi
├── modules/
│   ├── home/              # Shared user config: shell, packages, editors, browsers
│   │   └── desktop/       # Linux desktop: Hyprland, kitty, Waybar, hyprlock, dunst
│   └── nixos/             # Linux system config: boot, networking, Hyprland, NVIDIA, Stylix
├── assets/                # Plain config files that Home Manager links into place
│                          # (zsh, kitty, starship, opencode, wallpaper…)
├── scripts/               # Pi helpers: SSH keys, Samba storage, Docker shortcuts
└── install-rpi.sh         # One-shot bootstrap for a fresh Raspberry Pi
```

## How it works

```
flake.nix
├── darwinConfigurations.macbook  → hosts/macbook   ─┐
├── nixosConfigurations.desktop   → hosts/desktop   ─┼─▶ modules/home  (shared)
└── homeConfigurations.tphome     → hosts/tphome    ─┘   shell + nvim subset
```

Each host defines what makes that machine unique, and pulls in the shared Home Manager modules. The Mac and the desktop import the whole `modules/home` hub; the Pi only takes the shell and Neovim, since it doesn't need any desktop apps. Plain config files live in `assets/` and Home Manager symlinks them into `~/.config`, so they can still be edited as normal files. The desktop also imports `modules/home/desktop`, where Hyprland and its companions are written as Home Manager modules so Stylix can colour them from one palette.

Running `update` on any machine calls the right rebuild:

| Machine | `update` runs |
|---|---|
| `macbook` | `sudo darwin-rebuild switch --flake ~/Dotfiles#macbook` |
| `desktop` | `sudo nixos-rebuild switch --flake ~/dotfiles#desktop` |
| `tphome` | `home-manager switch --flake ~/dotfiles#tphome` |

On the Mac, the activation step also swaps Kitty's icon and registers the `Cmd+K` shortcut. On the Pi it installs Kitty's terminfo, pulls my SSH public keys from GitHub and sets up the local DNS for `tp.home` over Tailscale.

## How to use

You'll need [Nix](https://nixos.org/download) with flakes enabled. Then, depending on the machine:

```bash
git clone https://github.com/mtaibo/dotfiles ~/dotfiles

# macOS
sudo darwin-rebuild switch --flake ~/dotfiles#macbook

# NixOS
sudo nixos-rebuild switch --flake ~/dotfiles#desktop
```

### Raspberry Pi from scratch

On a fresh Raspberry Pi OS install, one line sets everything up:

```bash
curl -fsSL https://raw.githubusercontent.com/mtaibo/dotfiles/main/install-rpi.sh | bash
```

It sets the hostname, installs Nix, Docker and Tailscale, applies the `tphome` Home Manager config, clones this repo with git and makes zsh the default shell. After that, `scripts/setup-ssh-tphome.sh` (run from the laptop) creates an SSH key and uploads it to GitHub, so the Pi picks it up on its next `update`.

> This is my personal setup: usernames, hostnames and hardware are tailored to my machines. Feel free to fork it and adapt it to yours.
