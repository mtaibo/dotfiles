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
  # Name, then the temperature where the sensor can be read.
  withTemp = "{name}{?temperature}  {#90}·{#}  {temperature}{?}";
  # The OS row's icon: Home Manager inside NixOS or nix-darwin gets `osConfig`;
  # the standalone one is the Raspberry Pi.
  osIcon = if pkgs.stdenv.hostPlatform.isDarwin then ""
    else if args ? osConfig then ""
    else "";
  # The kernel row: XNU on the Mac, Linux everywhere else.
  kernelIcon = if pkgs.stdenv.hostPlatform.isDarwin then "" else "";
  # A white Apple logo in the style of the NixOS snowflake, drawn from the
  # Nerd Font glyph (the built-in macos logo is coloured ASCII).
  appleLogo = pkgs.runCommand "apple-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -background none -fill white -pointsize 480 \
      -font ${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFont-Regular.ttf \
      label:$'\uf179' -trim -gravity center -extent 512x512 $out
  '';
  # The wired connection, printed only when the default route goes through it
  # (an empty result hides the row); Wi-Fi has its own module.
  ethernet = if pkgs.stdenv.hostPlatform.isDarwin then ''
    i=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
    p=$(networksetup -listallhardwareports | awk -v d="Device: $i" '/^Hardware Port: / { sub(/^Hardware Port: /, ""); p = $0 } $0 == d { print p }')
    case "$p" in ""|Wi-Fi) ;; *) printf '%s' "$p" ;; esac
  '' else ''
    i=$(ip route show default 2>/dev/null | awk '{ print $5; exit }')
    case "$i" in en*|eth*) ;; *) exit 0 ;; esac
    [ -d "/sys/class/net/$i/wireless" ] && exit 0
    n=$(nmcli -g GENERAL.CONNECTION device show "$i" 2>/dev/null)
    printf '%s' "''${n:-$i}"
  '';
  # Tailscale's state and its IPv4 (the Mac runs the app, the CLI comes with it).
  tailscale = on: off: ''
    ts=$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)
    "$ts" status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r 'if .BackendState == "Running"
      then "${on}  \u001b[90m·\u001b[0m  " + ([.Self.TailscaleIPs[] | select(contains(":") | not)][0] // "")
      else "${off}" end'
  '';
  # The rows, labels in Spanish or English (the English config is for when
  # the desktop's system language is, see language.nix and shell.nix).
  modules = lang: let t = es: en: if lang == "en" then en else es; in [
    { type = "title"; format = "{#1}{user-name}{#}{#90}@{#}{#1}{host-name}"; }
    "break"
    (header (t "Sistema" "System"))
    { type = "os"; key = mid osIcon "OS"; format = "{pretty-name}"; }
    { type = "kernel"; key = mid kernelIcon "Kernel"; format = "{release}"; }
    { type = "packages"; key = mid "󰏖" (t "Paquetes" "Packages"); format = "{all}"; }
    { type = "wm"; key = mid "" (t "Ventanas" "WM"); format = "{pretty-name}"; }
    { type = "terminal"; key = mid "" "Terminal"; format = "{pretty-name}"; }
    { type = "shell"; key = mid "" "Shell"; format = "{pretty-name}"; }
    { type = "uptime"; key = last "󰅐" (t "Encendido" "Uptime"); format = "{?days}{days}d {?}{hours}h {minutes}m"; }
    "break"
    (header "Hardware")
    { type = "host"; key = mid "󰌢" (t "Equipo" "Machine"); }
    { type = "cpu"; key = mid "" "CPU"; format = withTemp; temp = true; }
    # driverSpecific reads the NVIDIA temperature through NVML.
    { type = "gpu"; key = mid "󰢮" "GPU"; format = withTemp; temp = true; driverSpecific = true; hideType = "integrated"; }
    # Display sits mid-list: on the headless Pi it prints nothing, and as the
    # last row it took the closing branch with it.
    { type = "display"; key = mid "󰍹" (t "Pantalla" "Display"); format = "{width}x{height} @ {refresh-rate} Hz"; }
    { type = "memory"; key = mid "" (t "Memoria" "Memory"); format = "{used} / {total}"; }
    { type = "disk"; key = last "" (t "Disco" "Disk"); folders = "/"; format = "{size-used} / {size-total}"; }
    "break"
    (header (t "Red" "Network"))
    { type = "wifi"; key = mid "󰖩" "Wi-Fi"; format = "{?ssid}{ssid}{?}{/ssid}${t "Sin conexión" "Not connected"}{/}"; }
    { type = "command"; key = mid "󰈀" "Ethernet"; text = ethernet; }
  ] ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin
    { type = "command"; key = mid "󰖂" "Tailscale"; text = tailscale (t "Conectado" "Connected") (t "Desconectado" "Disconnected"); }
  ++ [
    { type = "localip"; key = last "󰩟" (t "IP local" "Local IP"); showIpv4 = true; showIpv6 = false; showMac = false; showPrefixLen = false; defaultRouteOnly = true; format = "{ipv4}"; }
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
