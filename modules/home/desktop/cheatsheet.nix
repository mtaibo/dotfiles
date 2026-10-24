{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding;
  english = pkgs.writeText "english.json" (builtins.toJSON config.dotfiles.english);

  # A Spotlight-like glass window in the middle of the screen, the same look
  # as the wallpaper picker; the accent comes from the wallpaper.
  theme = pkgs.writeText "cheatsheet.rasi" ''
    @import "${config.xdg.configHome}/rofi/matugen-colors.rasi"

    configuration {
      hover-select: true;
      me-select-entry: "MouseSecondary";
      me-accept-entry: "MousePrimary";
      font: "JetBrainsMono Nerd Font 13";
    }

    * {
      background-color: transparent;
      text-color: ${c.withHashtag.base05};
    }

    window {
      location: center;
      anchor: center;
      width: 820px;
      transparency: "real";
      border-radius: ${toString radius}px;
      border: 1px;
      border-color: rgba(255, 255, 255, 0.08);
      background-color: rgba(${rgb "base00"}, 0.75);
    }

    mainbox {
      children: [ "inputbar", "listview" ];
      padding: 14px;
      spacing: 12px;
    }

    inputbar {
      padding: 12px 18px;
      border-radius: ${toString (radius - 2)}px;
      background-color: rgba(255, 255, 255, 0.08);
      children: [ "entry" ];
    }

    entry {
      placeholder: "Buscar atajo…";
      placeholder-color: rgba(255, 255, 255, 0.4);
    }

    listview {
      lines: 14;
      spacing: 2px;
      scrollbar: false;
      fixed-height: true;
    }

    element {
      padding: 8px 14px;
      border-radius: ${toString (radius - 4)}px;
    }

    element selected {
      background-color: rgba(255, 255, 255, 0.10);
      text-color: @accent;
    }

    element-text {
      text-color: inherit;
    }
  '';

  # Lists every Hyprland bind that has a description (`bindd`), straight from
  # the running compositor, so it never goes stale. Enter runs the shortcut.
  cheatsheet = pkgs.writeShellApplication {
    name = "hypr-cheatsheet";
    runtimeInputs = with pkgs; [ rofi jq hyprland procps ];
    text = ''
      # SUPER+H again closes it.
      if pkill -x rofi; then exit 0; fi

      # In English when the system language is (language.nix): descriptions
      # through dotfiles.english, key names and the rows below by hand.
      if [ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ]; then
        english=$(cat ${english})
        keys='{"SPACE": "Space", "Print": "Print Screen", "XF86AudioMute": "Mute",
               "XF86AudioNext": "Next", "XF86AudioPrev": "Previous"}'
        mouse=($'SUPER + left click drag\tResize the window\t\t'
               $'SUPER + right click drag\tMove the window\t\t')
        placeholder="Search shortcuts…"
      else
        english='{}'
        keys='{"SPACE": "Espacio", "Print": "Impr Pant", "XF86AudioMute": "Silencio",
               "XF86AudioNext": "Siguiente", "XF86AudioPrev": "Anterior"}'
        mouse=($'SUPER + clic izq. arrastrando\tRedimensionar la ventana\t\t'
               $'SUPER + clic der. arrastrando\tMover la ventana\t\t')
        placeholder="Buscar atajo…"
      fi

      mapfile -t rows < <(hyprctl binds -j | jq -r --argjson english "$english" --argjson keys "$keys" '
        def bit(n): (. / n | floor) % 2 == 1;
        def mods: [ (if bit(64) then "SUPER" else empty end),
                    (if bit(4) then "CTRL" else empty end),
                    (if bit(8) then "ALT" else empty end),
                    (if bit(1) then "SHIFT" else empty end) ];
        def name: ({
          "left": "←", "right": "→", "up": "↑", "down": "↓",
          "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
          "XF86AudioPlay": "Play"
        } + $keys)[.] // .;
        .[] | select(.has_description)
        | [ ((.modmask | mods) + [ .key | name ] | join(" + ")),
            ($english[.description] // .description), .dispatcher, .arg ]
        | @tsv')

      # Mouse binds can't carry a description; listed by hand, no action.
      rows+=("''${mouse[@]}")

      i=$(for row in "''${rows[@]}"; do
            IFS=$'\t' read -r key desc _ <<< "$row"
            printf '<b>%-30s</b><span foreground="${c.withHashtag.base04}">%s</span>\n' "$key" "$desc"
          done | rofi -dmenu -i -p "" -markup-rows -format i -theme ${theme} \
            -theme-str "entry { placeholder: \"$placeholder\"; }") || exit 0

      IFS=$'\t' read -r _ _ dispatcher arg <<< "''${rows[$i]}"
      if [ -n "$dispatcher" ]; then
        if [ -n "$arg" ]; then hyprctl dispatch "$dispatcher" "$arg"; else hyprctl dispatch "$dispatcher"; fi
      fi
    '';
  };
in {
  home.packages = [ cheatsheet ];

  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, H, Atajos de teclado, exec, hypr-cheatsheet"
  ];
  dotfiles.english."Atajos de teclado" = "Keyboard shortcuts";
}
