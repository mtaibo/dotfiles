{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # Same size and corners as the player popup (eww.nix).
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding + 6;
  width = 380;
  busy = ''"$XDG_RUNTIME_DIR/bluetooth-busy"'';

  # The bar's island: the Bluetooth icon, crossed out when it's off and with
  # dots when something is connected. The tooltip names what is.
  status = pkgs.writeShellApplication {
    name = "waybar-bluetooth";
    runtimeInputs = with pkgs; [ bluez coreutils gnugrep jq ];
    text = ''
      en=$([ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ] && echo 1 || true)
      if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        tip=$([ -n "$en" ] && echo "Bluetooth off" || echo "Bluetooth apagado")
        jq -cn --arg tip "$tip" '{text: "󰂲", class: "off", tooltip: $tip}'
        exit 0
      fi
      names=$(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3- || true)
      if [ -n "$names" ]; then
        jq -cn --arg tip "$names" '{text: "󰂱", class: "connected", tooltip: $tip}'
      else
        tip=$([ -n "$en" ] && echo "Nothing connected" || echo "Nada conectado")
        jq -cn --arg tip "$tip" '{text: "󰂯", class: "on", tooltip: $tip}'
      fi
    '';
  };

  # Everything the popup shows, as JSON, polled while it's open: whether the
  # adapter is on and scanning, and every known device with a name, the
  # connected ones first, then the paired ones, then the ones just found.
  info = pkgs.writeShellApplication {
    name = "bluetooth-info";
    runtimeInputs = with pkgs; [ bluez coreutils gnugrep gnused jq ];
    text = ''
      lang=$([ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ] && echo en || echo es)
      show=$(bluetoothctl show 2>/dev/null || true)
      powered=$(grep -q "Powered: yes" <<< "$show" && echo true || echo false)
      scanning=$(grep -q "Discovering: yes" <<< "$show" && echo true || echo false)
      pending=$(cat ${busy} 2>/dev/null || true)

      devices=$(
        if [ "$powered" = true ]; then
          bluetoothctl devices 2>/dev/null | cut -d' ' -f2 | while read -r mac; do
            bluetoothctl info "$mac" 2>/dev/null | jq -R -s --arg mac "$mac" '
              [split("\n")[] | capture("^\\s+(?<key>[^:]+): (?<value>.*)$")] | from_entries
              | select(.Name != null)
              | {
                  mac: $mac,
                  name: .Name,
                  icon: (.Icon // ""),
                  paired: (.Paired == "yes"),
                  connected: (.Connected == "yes"),
                  battery: ((."Battery Percentage" // "") | capture("\\((?<n>[0-9]+)\\)").n // "")
                }'
          done
        fi | jq -s '.'
      )

      jq -cn --argjson powered "$powered" --argjson scanning "$scanning" \
        --arg busy "$pending" --arg lang "$lang" --argjson devices "$devices" '
        def glyph: {
          "audio-headphones": "󰋋", "audio-headset": "󰋎", "audio-card": "󰓃",
          "input-keyboard": "󰌌", "input-mouse": "󰍽", "input-gaming": "󰊗",
          "input-tablet": "󰓶", "phone": "󰏲", "computer": "󰟀", "video-display": "󰍹"
        }[.] // "󰂯";
        {
          $powered, $scanning, $lang,
          devices: ($devices
            | sort_by(if .connected then 0 elif .paired then 1 else 2 end, (.name | ascii_downcase))
            | map(. + {
                glyph: (.icon | glyph),
                busy: (.mac == $busy),
                state: (if .mac == $busy then (if $lang == "en" then "Connecting…" else "Conectando…" end)
                  elif .connected then (if $lang == "en" then "Connected" else "Conectado" end)
                  elif .paired then (if $lang == "en" then "Paired" else "Emparejado" end)
                  else (if $lang == "en" then "Available" else "Disponible" end) end)
              }))
        }'
    '';
  };

  # bluetooth-device MAC: disconnects it if it's connected; otherwise pairs
  # it (the first time) and connects it. In the background, so the popup
  # shows "Connecting…" meanwhile.
  device = pkgs.writeShellApplication {
    name = "bluetooth-device";
    runtimeInputs = with pkgs; [ bluez coreutils gnugrep util-linux procps ];
    text = ''
      mac=$1
      if [ "''${2:-}" != run ]; then
        setsid -f "$0" "$mac" run >/dev/null 2>&1
        exit 0
      fi
      echo "$mac" > ${busy}
      trap 'rm -f ${busy}; pkill -RTMIN+10 -x .waybar-wrapped || true' EXIT
      inf=$(bluetoothctl info "$mac" 2>/dev/null || true)
      if grep -q "Connected: yes" <<< "$inf"; then
        bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
      else
        if ! grep -q "Paired: yes" <<< "$inf"; then
          bluetoothctl --timeout 20 pair "$mac" >/dev/null 2>&1 || true
          bluetoothctl trust "$mac" >/dev/null 2>&1 || true
        fi
        bluetoothctl --timeout 15 connect "$mac" >/dev/null 2>&1 || true
      fi
    '';
  };

  # bluetooth-power: turns the adapter on or off.
  power = pkgs.writeShellApplication {
    name = "bluetooth-power";
    runtimeInputs = with pkgs; [ bluez gnugrep procps util-linux ];
    text = ''
      if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off >/dev/null
      else
        rfkill unblock bluetooth 2>/dev/null || true
        bluetoothctl power on >/dev/null
      fi
      pkill -RTMIN+10 -x .waybar-wrapped || true
    '';
  };

  # Click the Bluetooth island: open the popup under the click and look for
  # new devices while it's open, or close it if it's already open. Like the
  # player's, a clear window behind it closes it on a click anywhere else;
  # opening one popup closes the other.
  popup = pkgs.writeShellApplication {
    name = "bluetooth-popup";
    runtimeInputs = with pkgs; [ eww hyprland bluez coreutils gnugrep util-linux procps ];
    text = ''
      stop_scan() { pkill -f "bluetoothctl --timeout 120 scan on" || true; }
      close() { eww close bluetooth bluetooth-closer >/dev/null 2>&1 || true; eww update bt_open=false; stop_scan; }
      if [ "''${1:-}" = close ] || eww active-windows 2>/dev/null | grep -q '^bluetooth:'; then
        close
        exit 0
      fi
      media-popup close
      x=$(hyprctl cursorpos | cut -d, -f1)
      x=$(( x - ${toString (width / 2)} ))
      [ "$x" -ge 10 ] || x=10
      eww update bt_open=true
      eww open bluetooth-closer
      eww open bluetooth --pos "''${x}x6"
      # Scans for two minutes at most, in case the popup is left open.
      stop_scan
      setsid -f bluetoothctl --timeout 120 scan on >/dev/null 2>&1
    '';
  };
in {
  # The bar's island is in waybar.nix.
  home.packages = [ pkgs.bluez status info device power popup ];

  xdg.configFile."eww/eww.yuck".text = lib.mkAfter ''

    (defvar bt_open false)
    (defpoll bt :interval "1s" :run-while bt_open
      :initial "{\"powered\":false,\"scanning\":false,\"lang\":\"es\",\"devices\":[]}"
      "${info}/bin/bluetooth-info")

    (defwindow bluetooth
      :monitor 0
      :geometry (geometry :x "0px" :y "6px" :width "${toString width}px" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-bluetooth"
      :exclusive false
      :focusable false
      (bluetooth))

    (defwindow bluetooth-closer
      :monitor 0
      :geometry (geometry :x "0px" :y "-100px" :width "100%" :height "200%" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-closer"
      :exclusive false
      :focusable false
      (eventbox :onclick "${popup}/bin/bluetooth-popup close" (box)))

    (defwidget bluetooth []
      (box :class "bluetooth" :orientation "v" :space-evenly false :spacing 10
        (box :class "bt-header" :orientation "h" :space-evenly false :spacing 10
          (label :class "bt-header-icon" :text {bt.powered ? "󰂯" : "󰂲"})
          (box :orientation "v" :space-evenly false :hexpand true :valign "center"
            (label :class "title" :xalign 0 :text "Bluetooth")
            (label :class "artist" :xalign 0
              :text {!bt.powered ? (bt.lang == "en" ? "Off" : "Apagado") : (bt.scanning ? (bt.lang == "en" ? "Looking for devices…" : "Buscando dispositivos…") : (bt.lang == "en" ? "On" : "Encendido"))}))
          (button :class "bt-switch ''${bt.powered ? "on" : ""}" :valign "center"
            :onclick "${power}/bin/bluetooth-power"
            (box :class "knob" :halign {bt.powered ? "end" : "start"})))
        (box :class "bt-list" :orientation "v" :space-evenly false :spacing 4 :visible {bt.powered}
          (label :class "bt-empty" :visible {arraylength(bt.devices) == 0}
            :text {bt.lang == "en" ? "No devices nearby" : "No hay dispositivos cerca"})
          (for dev in {bt.devices}
            (button :class "bt-device ''${dev.connected ? "connected" : ""} ''${dev.busy ? "busy" : ""}"
              :onclick "${device}/bin/bluetooth-device ''${dev.mac}"
              (box :orientation "h" :space-evenly false :spacing 12
                (label :class "bt-glyph" :text {dev.glyph})
                (box :orientation "v" :space-evenly false :hexpand true :valign "center"
                  (label :class "bt-name" :xalign 0 :text {dev.name} :limit-width 26 :show-truncated true)
                  (label :class "bt-state" :xalign 0 :text {dev.state}))
                (label :class "bt-battery" :valign "center" :visible {dev.battery != ""}
                  :text "󰁹 ''${dev.battery}%")))))))
  '';

  xdg.configFile."eww/eww.scss".text = lib.mkAfter ''

    // The Bluetooth popup: the player's glass, with a list of devices.
    .bluetooth {
      background-color: rgba(${c."base00-rgb-r"}, ${c."base00-rgb-g"}, ${c."base00-rgb-b"}, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: ${toString radius}px;
      padding: 14px 16px;
      color: $text;
    }

    .bt-header-icon {
      font-size: 26px;
      color: $accent;
      min-width: 36px;
    }

    .bt-switch {
      min-width: 40px;
      min-height: 22px;
      padding: 2px;
      border-radius: 13px;
      background-color: rgba(255, 255, 255, 0.12);
    }

    .bt-switch.on {
      background-color: $accent;
    }

    .bt-switch .knob {
      min-width: 18px;
      min-height: 18px;
      border-radius: 9px;
      background-color: ${c.withHashtag.base07};
    }

    .bt-device {
      padding: 8px 10px;
      border-radius: ${toString (radius - 6)}px;
    }

    .bt-device:hover {
      background-color: rgba(255, 255, 255, 0.06);
    }

    .bt-glyph {
      font-size: 22px;
      min-width: 28px;
      color: $muted;
    }

    .bt-device.connected .bt-glyph,
    .bt-device.connected .bt-state {
      color: $accent;
    }

    .bt-device.busy {
      opacity: 0.6;
    }

    .bt-name {
      font-size: 14px;
      color: ${c.withHashtag.base07};
    }

    .bt-state,
    .bt-battery,
    .bt-empty {
      font-size: 11px;
      color: $muted;
    }

    .bt-empty {
      padding: 8px;
    }
  '';

  wayland.windowManager.hyprland.settings.layerrule = [
    "blur, eww-bluetooth"
    "ignorezero, eww-bluetooth"
  ];
}
