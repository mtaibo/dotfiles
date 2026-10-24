{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # "rrggbb" -> "r, g, b" so the CSS can use rgba() with Stylix colours.
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  accentCss = "${config.xdg.configHome}/waybar/matugen-colors.css";
  font = "JetBrainsMono Nerd Font Propo";
  # Same corners as the windows.
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding;

  # Bell for the bar: dunst's history count, or what's queued while
  # "do not disturb" (dunst paused) is on.
  notifications = pkgs.writeShellApplication {
    name = "waybar-notifications";
    runtimeInputs = [ pkgs.dunst ];
    text = ''
      if [ "$(dunstctl is-paused)" = true ]; then
        n=$(dunstctl count waiting)
        state=dnd
        tip="No molestar · $n pendientes"
      else
        n=$(dunstctl count history)
        state=$([ "$n" -gt 0 ] && echo notification || echo none)
        tip="$n notificaciones recientes"
      fi
      if [ "$n" -gt 0 ]; then n="$n "; else n=""; fi
      tip="$tip\nClic: no molestar · Derecho: mostrar la última · Central: borrar"
      printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' "$n" "$state" "$state" "$tip"
    '';
  };

  # The music popup: a small glass list under the player island.
  mediaTheme = pkgs.writeText "media-menu.rasi" ''
    @import "${config.xdg.configHome}/rofi/matugen-colors.rasi"

    configuration {
      hover-select: true;
      me-select-entry: "MouseSecondary";
      me-accept-entry: "MousePrimary";
      font: "${font} Bold 13";
    }

    * {
      background-color: transparent;
      text-color: ${c.withHashtag.base05};
    }

    window {
      location: north west;
      anchor: north west;
      y-offset: 6px;
      width: 320px;
      transparency: "real";
      border-radius: ${toString radius}px;
      border: 1px;
      border-color: rgba(255, 255, 255, 0.08);
      background-color: rgba(${rgb "base00"}, 0.75);
    }

    mainbox {
      children: [ "message", "listview" ];
      padding: 8px;
      spacing: 6px;
    }

    message {
      padding: 8px 14px 4px 14px;
    }

    textbox {
      text-color: ${c.withHashtag.base05};
    }

    listview {
      lines: 3;
      spacing: 4px;
      fixed-height: false;
    }

    element {
      padding: 10px 14px;
      border-radius: ${toString (radius - 4)}px;
    }

    element selected {
      background-color: @accent;
      text-color: ${c.withHashtag.base00};
    }

    element-text {
      text-color: inherit;
    }
  '';

  # Clicking the player island: the song and previous / play-pause / next.
  # It reopens after each action, so it works like a small remote; Escape
  # or a click outside closes it.
  media = pkgs.writeShellApplication {
    name = "waybar-media";
    runtimeInputs = with pkgs; [ rofi playerctl procps hyprland gnused coreutils ];
    text = ''
      # A second click on the island closes the popup.
      if pkill -x rofi; then exit 0; fi

      # Open under the cursor, which is on the island that was clicked.
      x=$(hyprctl cursorpos | cut -d, -f1)
      x=$(( x > 170 ? x - 160 : 10 ))

      esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

      while :; do
        title=$(playerctl metadata --format '{{ title }}' 2>/dev/null | esc || true)
        artist=$(playerctl metadata --format '{{ artist }}' 2>/dev/null | esc || true)
        if [ "$(playerctl status 2>/dev/null || true)" = Playing ]; then
          toggle="󰏤  Pausar"
        else
          toggle="󰐊  Reproducir"
        fi
        choice=$(printf '%s\n' "󰒮  Anterior" "$toggle" "󰒭  Siguiente" \
          | rofi -dmenu -i -p "" -no-custom -mesg "<b>''${title:-Nada sonando}</b>
      <span alpha='65%'>$artist</span>" \
            -theme ${mediaTheme} -theme-str "window { x-offset: ''${x}px; }") || exit 0
        case "$choice" in
          *Anterior) playerctl previous ;;
          *Siguiente) playerctl next ;;
          *) playerctl play-pause ;;
        esac
        sleep 0.3
      done
    '';
  };

  # Always date and time, capitalised the way I write it ("Sábado, 24 de
  # Octubre 09:19"); waybar's clock can only give lowercase Spanish names.
  # The tooltip is the month's calendar.
  clock = pkgs.writeShellApplication {
    name = "waybar-clock";
    runtimeInputs = with pkgs; [ coreutils gnused util-linux jq ];
    text = ''
      export LC_TIME=es_ES.UTF-8
      text=$(date "+%A, %-d de %B %H:%M" | sed "s/^./\\u&/; s/ de \\(.\\)/ de \\u\\1/")
      cal=$(cal -m | sed "s/ *$//; 1s/^\\( *\\)\\(.\\)/\\1\\u\\2/")
      jq -cn --arg t "  $text" --arg c "<tt>$cal</tt>" '{text: $t, tooltip: $c}'
    '';
  };

in {
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono pkgs.pavucontrol pkgs.playerctl ];

  # waybar's mpris module and `playerctl` follow the player in use through it.
  services.playerctld.enable = true;

  # The colours come from the wallpaper (matugen, see wallpaper.nix). Until
  # the first wallpaper is set, or after the template gains new names,
  # Stylix's colours stand in.
  home.activation.waybarAccentDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! grep -qs "define-color island" ${accentCss}; then
      run mkdir -p "$(dirname ${accentCss})"
      run sh -c 'cat > ${accentCss} <<EOF
    @define-color accent ${c.withHashtag.base0D};
    @define-color accent_fixed ${c.withHashtag.base0D};
    @define-color surface ${c.withHashtag.base00};
    @define-color island ${c.withHashtag.base01};
    @define-color text ${c.withHashtag.base05};
    @define-color muted ${c.withHashtag.base03};
    EOF'
    fi
  '';

  # Copied from rice-reference-2 (JaKooLit's "window middle" layout with the
  # "islands" style): no bar background, every module is its own dark
  # rounded island tinted by the wallpaper. Clock and the music player on the
  # left, the workspaces in the middle (instead of the original's focused
  # window), connections, notifications and audio on the right; no power button.
  # SUPER+N hides and shows the bar.
  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, N, Mostrar u ocultar la barra, exec, pkill -USR1 -x .waybar-wrapped"
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      margin-top = 6;
      margin-left = 10;
      margin-right = 10;
      spacing = 0;
      fixed-center = true;

      modules-left = [ "custom/clock" "mpris" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [ "group/connection" "custom/notifications" "group/audio" ];

      "custom/clock" = {
        exec = "${clock}/bin/waybar-clock";
        return-type = "json";
        interval = 5;
      };

      # What's playing (hidden when nothing is); a click opens the remote.
      mpris = {
        format = "{player_icon}  {dynamic}";
        format-paused = "{status_icon}  {dynamic}";
        dynamic-order = [ "title" "artist" ];
        dynamic-len = 40;
        player-icons.default = "󰝚";
        status-icons.paused = "󰏤";
        tooltip-format = "{player}: {title} · {artist}";
        on-click = "${media}/bin/waybar-media";
        on-click-middle = "playerctl play-pause";
        on-click-right = "playerctl next";
      };

      "group/connection" = {
        orientation = "inherit";
        modules = [ "tray" "network" "bluetooth" ];
      };
      tray = {
        icon-size = 20;
        spacing = 8;
      };
      network = {
        format-ethernet = "󰈀";
        format-wifi = "󰖩";
        format-disconnected = "󰈂";
        tooltip-format = "{ifname} · {ipaddr}";
      };
      bluetooth = {
        format = "󰂯";
        format-disabled = "󰂲";
        format-off = "󰂲";
        format-connected = "󰂱";
        tooltip-format-connected = "{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = "blueman-manager";
      };

      "hyprland/workspaces" = {
        format = "{name}";
        on-click = "activate";
        on-scroll-up = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
        sort-by-number = true;
        persistent-workspaces."*" = 4;
      };

      "custom/notifications" = {
        exec = "${notifications}/bin/waybar-notifications";
        return-type = "json";
        interval = 1;
        format = "{text}{icon}";
        format-icons = {
          none = "󰂚";
          notification = "󱅫";
          dnd = "󰂛";
        };
        on-click = "dunstctl set-paused toggle";
        on-click-right = "dunstctl history-pop";
        on-click-middle = "dunstctl history-clear";
      };

      # Hover the volume and the microphone slides out.
      "group/audio" = {
        orientation = "inherit";
        drawer = {
          transition-duration = 500;
          children-class = "audio-child";
          transition-left-to-right = true;
        };
        modules = [ "pulseaudio" "pulseaudio#microphone" ];
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 {volume}%";
        format-icons = {
          headphone = "󰋋";
          headset = "󰋋";
          default = [ "󰕿" "󰖀" "󰕾" ];
        };
        tooltip-format = "{desc} · {volume}%";
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-right = "pavucontrol -t 3";
        scroll-step = 5;
      };
      "pulseaudio#microphone" = {
        format = "{format_source}";
        format-source = "󰍬 {volume}%";
        format-source-muted = "󰍭";
        tooltip-format = "{source_desc} · {source_volume}%";
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        on-click-right = "pavucontrol -t 4";
        on-scroll-up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+";
        on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
      };

    };

    style = ''
      @import url("file://${accentCss}");

      * {
        all: unset;
        font-family: "${font}";
        font-size: 17px;
        font-weight: bold;
      }

      window#waybar {
        background: transparent;
        color: @text;
      }

      /* Islands: one dark, wallpaper-tinted pill per module. */
      #custom-clock,
      #connection,
      #workspaces,
      #custom-notifications,
      #audio,
      #mpris {
        background: alpha(@island, 0.75);
        border-radius: ${toString radius}px;
        padding: 12px 20px;
        margin-left: 5px;
      }

      #custom-clock {
        margin-left: 0;
      }

      #tray,
      #network,
      #bluetooth {
        padding: 0 5px;
      }

      #network.disconnected,
      #bluetooth.disabled,
      #bluetooth.off {
        color: @muted;
      }

      #workspaces {
        padding: 8px 12px;
      }

      #workspaces button {
        padding: 4px 8px;
        margin: 0 2px;
        border-radius: ${toString (radius - 4)}px;
        color: @text;
        transition: all 0.5s cubic-bezier(.55, -0.68, .48, 1.682);
      }

      /* Workspaces without windows fade to grey. */
      #workspaces button.empty {
        color: @muted;
      }

      #workspaces button:hover {
        color: @accent;
      }

      #workspaces button.active {
        padding: 4px 14px;
        color: @surface;
        background: alpha(@accent_fixed, 0.75);
        transition: all 0.3s cubic-bezier(.55, -0.68, .48, 1.682);
      }

      #workspaces button.urgent {
        color: @accent;
      }

      #pulseaudio.microphone {
        padding-left: 10px;
      }

      #pulseaudio.muted,
      #pulseaudio.microphone.source-muted {
        color: ${c.withHashtag.base08};
      }

      #custom-notifications.dnd {
        color: @muted;
      }

      #mpris.paused {
        color: @muted;
      }

      tooltip {
        background: rgba(0, 0, 0, 0.8);
        border-radius: ${toString radius}px;
        padding: 8px 12px;
      }

      tooltip label {
        color: @text;
      }

      menu {
        background: rgba(${rgb "base00"}, 0.92);
        border-radius: 12px;
        padding: 6px;
      }

      menu menuitem {
        padding: 4px 10px;
        border-radius: 8px;
      }

      menu menuitem:hover {
        background: alpha(@accent, 0.25);
      }
    '';
  };
}
