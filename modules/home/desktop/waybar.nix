{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # "rrggbb" -> "r, g, b" so the CSS can use rgba() with Stylix colours.
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  accentCss = "${config.xdg.configHome}/waybar/matugen-colors.css";
  font = "JetBrainsMono Nerd Font Propo";
  # A little rounder than the windows.
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding + 6;

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

  # The player island: title and artist (40 characters at most) with a note,
  # or a pause icon when paused; nothing (so the island hides) when nothing
  # plays. `media-info` comes from eww.nix.
  media = pkgs.writeShellApplication {
    name = "waybar-media";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      media-info | jq -c '
        def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
        if .status == "None" or .title == "" then {text: ""} else
          (.title + (if .artist != "" then " - " + .artist else "" end)) as $full
          | ($full | if length > 40 then .[0:39] + "…" else . end) as $short
          | {
              text: ((if .status == "Playing" then "󰝚" else "󰏤" end) + "  " + ($short | esc)),
              tooltip: ($full | esc),
              class: (.status | ascii_downcase)
            }
        end'
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

  # `playerctl` follows the player in use through it.
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

      modules-left = [ "custom/clock" "custom/media" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [ "group/connection" "custom/notifications" "group/audio" ];

      "custom/clock" = {
        exec = "${clock}/bin/waybar-clock";
        return-type = "json";
        interval = 5;
      };

      # What's playing (hidden when nothing is); a click opens the popup. It reads
      # the popup's `media-info` (eww.nix) rather than waybar's mpris module,
      # because Cider's MPRIS metadata goes empty after skipping a song.
      "custom/media" = {
        exec = "${media}/bin/waybar-media";
        return-type = "json";
        interval = 2;
        on-click = "media-popup";
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
      #custom-media {
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

      #custom-media.paused {
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
