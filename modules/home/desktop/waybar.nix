{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # "rrggbb" -> "r, g, b" so the CSS can use rgba() with Stylix colours.
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  accentCss = "${config.xdg.configHome}/waybar/matugen-colors.css";

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
      [ "$n" -gt 0 ] || n=""
      tip="$tip\nClic: no molestar · Derecho: mostrar la última · Central: borrar"
      printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' "$n" "$state" "$state" "$tip"
    '';
  };
in {
  home.packages = [ pkgs.nerd-fonts.symbols-only pkgs.pavucontrol ];

  # The accent colours come from the wallpaper (matugen, see wallpaper.nix).
  # Until the first wallpaper is set, Stylix's blue stands in.
  home.activation.waybarAccentDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${accentCss} ]; then
      run mkdir -p "$(dirname ${accentCss})"
      run sh -c 'echo "@define-color accent ${c.withHashtag.base0D};" > ${accentCss}'
    fi
  '';

  # Modelled on Hyprlust's bar: one floating glass bar with tinted chips,
  # a hover drawer for system stats, dot workspaces in the centre and the
  # notifications and clock on the right; tinted with the wallpaper's accent.
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      height = 38;
      width = 1500;
      margin-top = 8;
      spacing = 0;
      fixed-center = true;

      modules-left = [ "custom/logo" "hyprland/window" "group/info" ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [ "tray" "group/connection" "custom/notifications" "clock" ];

      "custom/logo" = {
        # Custom modules only draw when they have something to exec.
        exec = "echo ''";
        interval = "once";
        tooltip-format = "Clic: aplicaciones · Derecho: fondos";
        on-click = "vicinae toggle";
        on-click-right = "wallpaper pick";
      };

      "hyprland/window" = {
        format = "{class}";
        max-length = 32;
        separate-outputs = true;
        rewrite."" = "Escritorio";
      };

      # Hover the arrow and CPU, memory and temperature slide out.
      "group/info" = {
        orientation = "inherit";
        drawer = {
          transition-duration = 300;
          transition-left-to-right = true;
        };
        modules = [ "custom/arrow" "cpu" "memory" "temperature" ];
      };
      "custom/arrow" = {
        exec = "echo '󰁔'";
        interval = "once";
        tooltip = false;
      };
      cpu = {
        interval = 2;
        format = "󰘚 {usage}%";
      };
      memory = {
        interval = 5;
        format = "󰍛 {used:0.1f}G";
        tooltip-format = "{used:0.1f} / {total:0.1f} GiB";
      };
      temperature = {
        # Stable path to the CPU package sensor (hwmonN numbers can change).
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
        critical-threshold = 85;
        format = "{icon} {temperatureC}°";
        format-icons = [ "" "" "" ];
      };

      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
        sort-by-number = true;
        persistent-workspaces."*" = 5;
        format-icons = {
          active = "";
          default = "";
          empty = "";
        };
      };

      tray = {
        icon-size = 16;
        spacing = 10;
      };

      "group/connection" = {
        orientation = "inherit";
        modules = [ "network" "bluetooth" "pulseaudio" ];
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
        format-connected = "󰂱";
        tooltip-format-connected = "{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = "blueman-manager";
      };
      pulseaudio = {
        format = "{icon}";
        format-muted = "󰝟";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        tooltip-format = "{volume}%";
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      "custom/notifications" = {
        exec = "${notifications}/bin/waybar-notifications";
        return-type = "json";
        interval = 1;
        format = "{icon} {text}";
        format-icons = {
          none = "󰂚";
          notification = "󱅫";
          dnd = "󰂛";
        };
        on-click = "dunstctl set-paused toggle";
        on-click-right = "dunstctl history-pop";
        on-click-middle = "dunstctl history-clear";
      };

      clock = {
        # `L` makes waybar use the locale for day and month names.
        format = "{:L%H:%M}";
        format-alt = "{:L%A, %e de %B  %H:%M}";
        locale = "es_ES.UTF-8";
        tooltip-format = "<tt>{calendar}</tt>";
      };
    };

    style = ''
      @import url("file://${accentCss}");

      * {
        all: unset;
        font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font";
        font-size: 13px;
        font-weight: 600;
      }

      /* The bar itself: one frosted strip, blurred by Hyprland. */
      window#waybar {
        background: rgba(${rgb "base00"}, 0.55);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        color: ${c.withHashtag.base05};
      }

      /* Chips: a soft wash of the wallpaper's accent. */
      #custom-logo,
      #window,
      #info,
      #workspaces,
      #tray,
      #connection,
      #custom-notifications,
      #clock {
        background: alpha(@accent, 0.12);
        border-radius: 8px;
        margin: 6px 3px;
        padding: 0 10px;
      }

      #custom-logo {
        margin-left: 6px;
        padding: 0 13px 0 11px;
        font-size: 16px;
        color: @accent;
      }

      #window {
        color: ${c.withHashtag.base07};
      }

      window#waybar.empty #window {
        color: ${c.withHashtag.base04};
      }

      #custom-arrow {
        color: @accent;
        font-size: 15px;
      }

      #cpu,
      #memory,
      #temperature {
        padding-left: 12px;
        color: ${c.withHashtag.base05};
      }

      #temperature.critical {
        color: ${c.withHashtag.base08};
      }

      #workspaces {
        padding: 0 6px;
      }

      #workspaces button {
        padding: 0 6px;
        color: rgba(255, 255, 255, 0.55);
        transition: color 300ms ease;
      }

      #workspaces button.empty {
        color: rgba(255, 255, 255, 0.25);
      }

      #workspaces button.active,
      #workspaces button:hover {
        color: @accent;
      }

      #tray {
        padding: 0 10px;
      }

      #network,
      #bluetooth,
      #pulseaudio {
        padding: 0 7px;
        color: @accent;
      }

      #network.disconnected,
      #bluetooth.disabled,
      #pulseaudio.muted {
        color: ${c.withHashtag.base03};
      }

      #custom-notifications {
        color: @accent;
      }

      #custom-notifications.dnd {
        color: ${c.withHashtag.base03};
      }

      #clock {
        margin-right: 6px;
        color: @accent;
        font-weight: 700;
      }

      tooltip {
        background: rgba(${rgb "base00"}, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 10px;
        padding: 8px 10px;
      }

      tooltip label {
        color: ${c.withHashtag.base05};
      }
    '';
  };
}
