# AGENTS.md

This file provides guidance to OpenCode when working with code in this repository.

## What this repo is

A Nix flake managing system + user config for two hosts: an Apple Silicon MacBook (via `nix-darwin`) and an `x86_64-linux` desktop (via NixOS). Home-Manager is wired into both as a module, so user-level config (`modules/home/`) is shared across both OSes.

## Build / apply commands

The `update` shell alias (defined in `modules/home/shell.nix`) picks the right command per host:

- macOS: `sudo darwin-rebuild switch --flake ~/Dotfiles#macbook`
- NixOS: `sudo nixos-rebuild switch --flake ~/dotfiles#nixos`

Standalone Home-Manager (used when the system rebuild isn't appropriate, e.g. testing user-only changes on darwin without rebuilding the system):

- `home-manager switch --flake ~/Dotfiles#migueltaibo`

Other useful one-offs:

- `nix flake check` — evaluate all outputs
- `nix flake update` — bump all inputs (writes `flake.lock`)
- `darwin-rebuild build --flake .#macbook` / `nixos-rebuild build --flake .#nixos` — dry build without activating

Note the case-sensitive path difference: the macOS repo lives at `~/Dotfiles` (capital D), the NixOS one at `~/dotfiles`. Don't "fix" one to match the other — both aliases are intentional.

## Architecture

Three flake outputs, all defined in `flake.nix`:

- `darwinConfigurations.macbook` — entry: `hosts/macbook/default.nix`. Imports Home-Manager as a darwin module and points it at `hosts/macbook/home.nix`.
- `nixosConfigurations.nixos` — entry: `hosts/desktop/default.nix`. Imports Home-Manager as a NixOS module and points it at `modules/home` directly.
- `homeConfigurations.migueltaibo` — standalone Home-Manager for darwin, also pointing at `hosts/macbook/home.nix`.

`pkgsUnstable` is constructed in `flake.nix` from `nixpkgs-unstable` and passed via `extraSpecialArgs` to Home-Manager modules. Use it sparingly — only for packages where the release channel lags (currently `ollama` on macOS).

### Layout

- `hosts/{macbook,desktop}/default.nix` — per-host system config (hostname, system packages, services, hardware).
- `hosts/macbook/home.nix` — darwin-specific Home-Manager entry. Imports `modules/home` and layers on macOS-only bits: forcing `home.homeDirectory` to `/Users/migueltaibo`, installing Nerd Font `.ttf`s into `/Library/Fonts`, the `OpenKittyFullscreen.workflow` Service, and two `home.activation` hooks that swap kitty's app icon and register a system Services keyboard shortcut.
- `modules/home/` — cross-platform Home-Manager modules. `default.nix` is the entry that aggregates `shell.nix`, `packages.nix`, `vscode.nix`, `firefox.nix`, and wires up dotfile sources from `modules/home/dotfiles/` (kitty, zsh, starship, and hypr on Linux).
- `modules/nixos/` — Linux-only system modules (`boot.nix` with GRUB + grub2-themes, `networking.nix`, `desktop/hyprland.nix`, `desktop/nvidia.nix`).
- `modules/ollama.nix` — custom NixOS module exposing the `mySystem.ollama` option (`enable`, `acceleration`, `models`). When `models` is non-empty it adds a `ollama-pull-models` oneshot systemd unit that waits for the ollama HTTP API and pulls each model on activation.

### Cross-platform gating

`modules/home/` is imported by **both** the macbook and the NixOS desktop, so anything Linux-only must be guarded. The patterns already in use:

- Whole-file gate: `programs.firefox = mkIf pkgs.stdenv.hostPlatform.isLinux { ... };` (see `firefox.nix`).
- Conditional config block: `gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux { ... };`, `home.file.".config/hypr" = lib.mkIf ... { source = ...; };` (see `modules/home/default.nix`).
- Conditional package list: `home.packages = with pkgs; [ ... ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ bibata-cursors grim slurp ];` (see `packages.nix`).
- Conditional alias: the `update` alias branches on `pkgs.stdenv.hostPlatform.isDarwin` (see `shell.nix`).

When adding anything that touches Wayland/Linux-only services, GTK, or Linux-specific paths, gate it; don't move it out of `modules/home/` unless it has no darwin counterpart at all.

### Dotfiles vs. Nix-managed config

Files under `modules/home/dotfiles/` (kitty, zsh `.zshrc`, starship, hypr configs, macOS workflow, kitty icon) are installed verbatim by Home-Manager via `home.file` / `xdg.configFile`. Edit those files directly to change runtime config — there is no template/generation step.

`xdg.configFile."gh/config.yml".force = true;` in `modules/home/default.nix` is load-bearing: without it Home-Manager refuses to clobber the file `gh` writes on first login (see commit `24d5277`). Don't remove the `force` without a plan.
