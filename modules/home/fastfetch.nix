{ pkgs, lib, ... }:
let
  # Tree-style key: grey branch, blue icon + label padded to one width.
  key = branch: icon: label:
    "{#bright_black}${branch}{#}  {#blue}${icon} ${label}${lib.strings.replicate (10 - builtins.stringLength label) " "}";
  mid = key "│";
  last = key "╰";
  header = title: { type = "custom"; format = "{#bright_black}╭─{#} {#1}${title}"; };
in {
  # Uses the terminal's named colours, so on the desktop it follows Stylix
  # through kitty's palette and still looks right on the Mac.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = if pkgs.stdenv.hostPlatform.isLinux then {
        # Real image through kitty's graphics protocol; the shell falls back to
        # a small text logo where that isn't available (tmux, SSH, other terminals).
        type = "kitty-direct";
        source = "${pkgs.nixos-icons}/share/icons/hicolor/512x512/apps/nix-snowflake-white.png";
        width = 24;
        height = 11;
        padding = { top = 3; left = 2; right = 4; };
      } else {
        type = "builtin";
        source = "macos";
        padding = { top = 1; left = 2; right = 4; };
      };

      display.separator = "  ";

      modules = [
        { type = "title"; format = "{#1}{user-name}{#}{#bright_black}@{#}{#1}{host-name}"; }
        "break"
        (header "Sistema")
        { type = "os"; key = mid "" "OS"; format = "{pretty-name}"; }
        { type = "kernel"; key = mid "" "Kernel"; format = "{release}"; }
        { type = "packages"; key = mid "󰏖" "Paquetes"; format = "{all}"; }
        { type = "wm"; key = mid "" "Ventanas"; format = "{pretty-name}"; }
        { type = "terminal"; key = mid "" "Terminal"; format = "{pretty-name}"; }
        { type = "shell"; key = mid "" "Shell"; format = "{pretty-name}"; }
        { type = "uptime"; key = last "󰅐" "Encendido"; format = "{?days}{days}d {?}{hours}h {minutes}m"; }
        "break"
        (header "Hardware")
        { type = "host"; key = mid "󰌢" "Equipo"; }
        { type = "cpu"; key = mid "" "CPU"; format = "{name}"; }
        { type = "gpu"; key = mid "󰢮" "GPU"; format = "{name}"; hideType = "integrated"; }
        { type = "memory"; key = mid "" "Memoria"; format = "{used} / {total}"; }
        { type = "disk"; key = mid "" "Disco"; folders = "/"; format = "{size-used} / {size-total}"; }
        { type = "display"; key = last "󰍹" "Pantalla"; format = "{width}x{height} @ {refresh-rate} Hz"; }
      ];
    };
  };
}
