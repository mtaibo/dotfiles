{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # "rrggbb" -> "r, g, b" so the CSS can use rgba() with Stylix colours.
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  accentCss = "${config.xdg.configHome}/waybar/matugen-colors.css";
  font = "JetBrainsMono Nerd Font Propo";

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

  # The power button's menu: a small glass list under the button.
  powerTheme = pkgs.writeText "power-menu.rasi" ''
    @import "${config.xdg.configHome}/rofi/matugen-colors.rasi"

    configuration {
      hover-select: true;
      me-select-entry: "MouseSecondary";
      me-accept-entry: "MousePrimary";
      font: "${font} Bold 11";
    }

    * {
      background-color: transparent;
      text-color: ${c.withHashtag.base05};
    }

    window {
      location: north east;
      anchor: north east;
      x-offset: -10px;
      y-offset: 52px;
      width: 220px;
      transparency: "real";
      border-radius: 20px;
      border: 1px;
      border-color: rgba(255, 255, 255, 0.08);
      background-color: rgba(${rgb "base00"}, 0.75);
    }

    mainbox {
      children: [ "listview" ];
      padding: 8px;
    }

    listview {
      lines: 4;
      spacing: 4px;
      fixed-height: false;
    }

    element {
      padding: 10px 14px;
      border-radius: 14px;
    }

    element selected {
      background-color: @accent;
      text-color: ${c.withHashtag.base00};
    }

    element-text {
      text-color: inherit;
    }
  '';

  power = pkgs.writeShellApplication {
    name = "waybar-power";
    runtimeInputs = with pkgs; [ rofi systemd hyprland procps ];
    text = ''
      # A second click on the button closes the menu.
      if pkill -x rofi; then exit 0; fi
      choice=$(printf '%s\n' \
        "󰌾  Bloquear" \
        "󰍃  Cerrar sesión" \
        "󰜉  Reiniciar" \
        "󰐥  Apagar" \
        | rofi -dmenu -i -p "" -no-custom -theme ${powerTheme}) || exit 0
      case "$choice" in
        *Bloquear) hyprlock ;;
        *sesión) hyprctl dispatch exit ;;
        *Reiniciar) systemctl reboot ;;
        *Apagar) systemctl poweroff ;;
      esac
    '';
  };
in {
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono pkgs.pavucontrol ];

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
  # rounded island tinted by the wallpaper. Clock, connections and lettered
  # workspaces on the left, the focused window in the middle, notifications,
  # audio and the power button on the right.
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

      modules-left = [ "clock" "group/connection" "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [ "custom/notifications" "group/audio" "custom/power" ];

      clock = {
        # `L` makes waybar use the locale for day and month names.
        interval = 1;
        format = " {:L%H:%M}";
        format-alt = " {:L%A, %e de %B  %H:%M}";
        locale = "es_ES.UTF-8";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar.format.today = "<b><u>{}</u></b>";
      };

      "group/connection" = {
        orientation = "inherit";
        modules = [ "tray" "network" "bluetooth" ];
      };
      tray = {
        icon-size = 16;
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
        format = "{icon}";
        on-click = "activate";
        on-scroll-up = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
        sort-by-number = true;
        persistent-workspaces."*" = 5;
        format-icons = {
          "1" = "A"; "2" = "B"; "3" = "C"; "4" = "D"; "5" = "E";
          "6" = "F"; "7" = "G"; "8" = "H"; "9" = "I"; "10" = "J";
        };
      };

      "hyprland/window" = {
        format = "{}";
        max-length = 55;
        separate-outputs = true;
        rewrite = {
          "(.*) — Mozilla Firefox" = "󰈹  $1";
          "(.*) - zsh" = "> [$1]";
        };
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

      "custom/power" = {
        exec = "echo '󰐥'";
        interval = "once";
        tooltip-format = "Bloquear, cerrar sesión, reiniciar o apagar";
        on-click = "${power}/bin/waybar-power";
      };
    };

    style = ''
      @import url("file://${accentCss}");

      * {
        all: unset;
        font-family: "${font}";
        font-size: 13px;
        font-weight: bold;
        font-feature-settings: '"zero", "ss01", "ss02", "ss03", "ss04", "ss05", "cv31"';
      }

      window#waybar {
        background: transparent;
        color: @text;
      }

      /* Islands: one dark, wallpaper-tinted pill per module. */
      #clock,
      #connection,
      #workspaces,
      #window,
      #custom-notifications,
      #audio,
      #custom-power {
        background: alpha(@island, 0.75);
        border-radius: 20px;
        padding: 8px 15px;
        margin-left: 5px;
      }

      #clock {
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
        padding: 6px 8px;
      }

      #workspaces button {
        padding: 1px 4px 0 4px;
        margin: 0 2px;
        border-radius: 9px;
        color: @muted;
        transition: all 0.5s cubic-bezier(.55, -0.68, .48, 1.682);
      }

      #workspaces button:hover {
        color: @accent;
      }

      #workspaces button.active {
        padding: 1px 10px 0 10px;
        color: @surface;
        background: alpha(@accent_fixed, 0.75);
        transition: all 0.3s cubic-bezier(.55, -0.68, .48, 1.682);
      }

      #workspaces button.urgent {
        color: @accent;
      }

      /* Nothing focused: the middle island disappears. */
      window#waybar.empty #window {
        background: transparent;
        padding: 0;
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

      #custom-power {
        padding: 8px 13px;
      }

      #custom-power:hover {
        color: @accent;
      }

      tooltip {
        background: rgba(0, 0, 0, 0.8);
        border-radius: 20px;
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
