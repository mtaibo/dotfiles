{ config, pkgs, lib, ... }@args:
let
  # Tree-style key: grey branch, blue icon + label padded to one width.
  # Greys are `{#90}`: fastfetch writes `bright_black` as bold + black (1;30),
  # which kitty draws in the background colour.
  key = branch: icon: label:
    "{#90}${branch}{#}  {#blue}${icon} ${label}${lib.strings.replicate (10 - builtins.stringLength label) " "}";
  mid = key "│";
  last = key "╰";
  header = title: { type = "custom"; format = "{#90}╭─{#} {#1}${title}"; };
  # The OS row's icon: Home Manager inside NixOS or nix-darwin gets `osConfig`;
  # the standalone one is the Raspberry Pi.
  osIcon = if pkgs.stdenv.hostPlatform.isDarwin then ""
    else if args ? osConfig then ""
    else "";
  # A white Apple logo in the style of the NixOS snowflake, drawn from the
  # Nerd Font glyph (the built-in macos logo is coloured ASCII).
  appleLogo = pkgs.runCommand "apple-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -background none -fill white -pointsize 480 \
      -font ${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFont-Regular.ttf \
      label:$'\uf179' -trim -gravity center -extent 512x512 $out
  '';
  # The rows, labels in Spanish or English (the English config is for when
  # the desktop's system language is, see language.nix and shell.nix).
  modules = lang: let t = es: en: if lang == "en" then en else es; in [
    { type = "title"; format = "{#1}{user-name}{#}{#90}@{#}{#1}{host-name}"; }
    "break"
    (header (t "Sistema" "System"))
    { type = "os"; key = mid osIcon "OS"; format = "{pretty-name}"; }
    { type = "kernel"; key = mid "" "Kernel"; format = "{release}"; }
    { type = "packages"; key = mid "󰏖" (t "Paquetes" "Packages"); format = "{all}"; }
    { type = "wm"; key = mid "" (t "Ventanas" "WM"); format = "{pretty-name}"; }
    { type = "terminal"; key = mid "" "Terminal"; format = "{pretty-name}"; }
    { type = "shell"; key = mid "" "Shell"; format = "{pretty-name}"; }
    { type = "uptime"; key = last "󰅐" (t "Encendido" "Uptime"); format = "{?days}{days}d {?}{hours}h {minutes}m"; }
    "break"
    (header "Hardware")
    { type = "host"; key = mid "󰌢" (t "Equipo" "Machine"); }
    { type = "cpu"; key = mid "" "CPU"; format = "{name}"; }
    { type = "gpu"; key = mid "󰢮" "GPU"; format = "{name}"; hideType = "integrated"; }
    # Display sits mid-list: on the headless Pi it prints nothing, and as the
    # last row it took the closing branch with it.
    { type = "display"; key = mid "󰍹" (t "Pantalla" "Display"); format = "{width}x{height} @ {refresh-rate} Hz"; }
    { type = "memory"; key = mid "" (t "Memoria" "Memory"); format = "{used} / {total}"; }
    { type = "disk"; key = last "" (t "Disco" "Disk"); folders = "/"; format = "{size-used} / {size-total}"; }
  ];
in {
  # Uses the terminal's named colours, so on the desktop it follows Stylix
  # through kitty's palette and still looks right on the Mac.
  programs.fastfetch = {
    enable = true;
    settings = {
      # Real image through kitty's graphics protocol; the shell falls back to a
      # small text logo where that isn't available (tmux, other terminals).
      logo = {
        type = "kitty-direct";
        source = if pkgs.stdenv.hostPlatform.isDarwin then appleLogo
          else "${pkgs.nixos-icons}/share/icons/hicolor/512x512/apps/nix-snowflake-white.png";
        width = 24;
        height = 11;
        padding = { top = 3; left = 2; right = 4; };
      };

      display.separator = "  ";

      modules = modules "es";
    };
  };

  xdg.configFile."fastfetch/config-en.jsonc".source = (pkgs.formats.json { }).generate "config-en.jsonc"
    (config.programs.fastfetch.settings // { modules = modules "en"; });
}
