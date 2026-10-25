{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # Same size and corners as the Bluetooth popup (bluetooth.nix).
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding + 6;
  width = 380;

  # Everything the popup shows, as JSON, polled while it's open: the volume
  # of the output in use, and the outputs and inputs with the one in use
  # marked. From `pw-dump`, since `pactl -f json` breaks on accents
  # ("Estéreo").
  info = pkgs.writeShellApplication {
    name = "audio-info";
    runtimeInputs = with pkgs; [ pipewire wireplumber coreutils jq ];
    text = ''
      lang=$([ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ] && echo en || echo es)
      vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0")
      pw-dump | jq -c --arg lang "$lang" --arg vol "$vol" '
        (map(select(.props."metadata.name"? == "default")) | first.metadata // []
          | map({(.key): .value.name?}) | add // {}) as $default
        | def devices($class; $active): map(select(.info.props."media.class"? == $class)
            | {id, desc: (.info.props."node.description" // .info.props."node.name"),
               active: (.info.props."node.name" == $active)});
        {
          $lang,
          volume: ($vol | capture("(?<v>[0-9.]+)").v | tonumber * 100 | round),
          muted: ($vol | test("MUTED")),
          outputs: devices("Audio/Sink"; $default."default.audio.sink"),
          inputs: devices("Audio/Source"; $default."default.audio.source")
        }'
    '';
  };

  # Click the volume island: open the popup under the click (kept on screen,
  # since the island is at the right edge), or close it if it's already open.
  # Like the others, a clear window behind it closes it on a click anywhere
  # else; opening one popup closes the rest.
  popup = pkgs.writeShellApplication {
    name = "audio-popup";
    runtimeInputs = with pkgs; [ eww hyprland coreutils gnugrep jq ];
    text = ''
      close() { eww close audio audio-closer >/dev/null 2>&1 || true; eww update audio_open=false; }
      if [ "''${1:-}" = close ] || eww active-windows 2>/dev/null | grep -q '^audio:'; then
        close
        exit 0
      fi
      media-popup close
      bluetooth-popup close
      x=$(hyprctl cursorpos | cut -d, -f1)
      x=$(( x - ${toString (width / 2)} ))
      max=$(hyprctl -j monitors | jq '.[] | select(.focused) | (.x + .width / .scale - ${toString (width + 10)}) | floor')
      [ "$x" -le "$max" ] || x=$max
      [ "$x" -ge 10 ] || x=10
      eww update audio_open=true
      eww open audio-closer
      eww open audio --pos "''${x}x6"
    '';
  };
in {
  # The bar's island is in waybar.nix.
  home.packages = [ info popup ];

  xdg.configFile."eww/eww.yuck".text = lib.mkAfter ''

    (defvar audio_open false)
    (defpoll audio :interval "1s" :run-while audio_open
      :initial "{\"lang\":\"es\",\"volume\":0,\"muted\":false,\"outputs\":[],\"inputs\":[]}"
      "${info}/bin/audio-info")

    (defwindow audio
      :monitor 0
      :geometry (geometry :x "0px" :y "6px" :width "${toString width}px" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-audio"
      :exclusive false
      :focusable false
      (audio))

    (defwindow audio-closer
      :monitor 0
      :geometry (geometry :x "0px" :y "-100px" :width "100%" :height "200%" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-closer"
      :exclusive false
      :focusable false
      (eventbox :onclick "${popup}/bin/audio-popup close" (box)))

    (defwidget audio-device [dev]
      (button :class "audio-device ''${dev.active ? "active" : ""}"
        :onclick "${pkgs.wireplumber}/bin/wpctl set-default ''${dev.id}"
        (label :xalign 0 :text {dev.desc} :limit-width 34 :show-truncated true)))

    (defwidget audio []
      (box :class "audio" :orientation "v" :space-evenly false :spacing 8
        (box :class "audio-volume ''${audio.muted ? "muted" : ""}" :orientation "h" :space-evenly false :spacing 10
          (button :class "audio-mute" :onclick "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            (label :text {audio.muted ? "󰝟" : "󰕾"}))
          (scale :class "audio-slider" :hexpand true :min 0 :max 101 :round-digits 0
            :value {audio.volume}
            :onchange "${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ {}%")
          (label :class "audio-percent" :text "''${audio.volume}%"))
        (label :class "audio-section" :xalign 0 :text {audio.lang == "en" ? "Output" : "Salida"})
        (for dev in {audio.outputs} (audio-device :dev dev))
        (label :class "audio-section" :xalign 0 :text {audio.lang == "en" ? "Input" : "Entrada"})
        (for dev in {audio.inputs} (audio-device :dev dev))))
  '';

  xdg.configFile."eww/eww.scss".text = lib.mkAfter ''

    // The volume popup: the Bluetooth popup's glass, with a slider and the
    // outputs and inputs to pick from.
    .audio {
      background-color: rgba(${c."base00-rgb-r"}, ${c."base00-rgb-g"}, ${c."base00-rgb-b"}, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: ${toString radius}px;
      padding: 14px 16px;
      color: $text;
    }

    .audio-mute {
      font-size: 22px;
      min-width: 28px;
      color: $accent;
    }

    .audio-volume.muted .audio-mute {
      color: ${c.withHashtag.base08};
    }

    .audio-slider trough {
      min-height: 6px;
      border-radius: 3px;
      background-color: rgba(255, 255, 255, 0.12);
    }

    .audio-slider highlight {
      border-radius: 3px;
      background-color: $accent;
    }

    .audio-slider slider {
      min-width: 14px;
      min-height: 14px;
      margin: -4px;
      border-radius: 7px;
      background-color: ${c.withHashtag.base07};
    }

    .audio-percent {
      font-size: 12px;
      min-width: 40px;
      color: $muted;
    }

    .audio-section {
      font-size: 11px;
      color: $muted;
      padding: 6px 4px 0;
    }

    .audio-device {
      padding: 7px 10px;
      border-radius: ${toString (radius - 6)}px;
      font-size: 13px;
      color: ${c.withHashtag.base07};
    }

    .audio-device:hover {
      background-color: rgba(255, 255, 255, 0.06);
    }

    .audio-device.active {
      color: $accent;
      background-color: rgba(255, 255, 255, 0.08);
    }
  '';

  wayland.windowManager.hyprland.settings.layerrule = [
    "blur, eww-audio"
    "ignorezero, eww-audio"
  ];
}
