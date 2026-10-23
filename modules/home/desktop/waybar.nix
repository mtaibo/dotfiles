{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  # "rrggbb" -> "r, g, b" so the CSS can use rgba() with Stylix colours.
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
in {
  home.packages = [ pkgs.nerd-fonts.symbols-only pkgs.pavucontrol ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      height = 34;
      margin-top = 8;
      margin-left = 10;
      margin-right = 10;
      spacing = 6;

      modules-left = [ "custom/logo" "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ ];
      modules-right = [ "tray" "network" "bluetooth" "pulseaudio" "clock" ];

      "custom/logo" = {
        format = "";
        tooltip = false;
        on-click = "vicinae toggle";
      };

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        sort-by-number = true;
      };

      "hyprland/window" = {
        format = "{class}";
        max-length = 40;
        separate-outputs = true;
        rewrite = {
          "" = "Escritorio";
        };
      };

      tray = {
        icon-size = 16;
        spacing = 10;
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

      clock = {
        format = "{:%a %e %b  %H:%M}";
        locale = "es_ES.UTF-8";
        tooltip-format = "<tt>{calendar}</tt>";
      };
    };

    style = ''
      * {
        font-family: "${config.stylix.fonts.sansSerif.name}", "Symbols Nerd Font";
        font-size: 13px;
        font-weight: 500;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: ${c.withHashtag.base05};
      }

      /* Each group is a frosted pill; Hyprland blurs what's behind it. */
      #custom-logo,
      #workspaces,
      #window,
      .modules-right {
        background: rgba(${rgb "base00"}, 0.45);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        padding: 0 12px;
      }

      window#waybar.empty #window {
        background: transparent;
        border-color: transparent;
      }

      #custom-logo {
        font-size: 16px;
        padding: 0 14px 0 12px;
      }

      #workspaces {
        padding: 0 4px;
      }

      #workspaces button {
        color: ${c.withHashtag.base04};
        padding: 0 8px;
        margin: 4px 0;
        border-radius: 8px;
        background: transparent;
        transition: all 200ms ease;
      }

      #workspaces button:hover {
        background: rgba(255, 255, 255, 0.08);
        box-shadow: none;
      }

      #workspaces button.active {
        color: ${c.withHashtag.base07};
        background: rgba(255, 255, 255, 0.14);
      }

      #window {
        font-weight: 600;
      }

      #tray,
      #network,
      #bluetooth,
      #pulseaudio,
      #clock {
        padding: 0 8px;
        color: ${c.withHashtag.base05};
      }

      #clock {
        font-weight: 600;
        color: ${c.withHashtag.base07};
      }

      #network.disconnected,
      #pulseaudio.muted,
      #bluetooth.disabled {
        color: ${c.withHashtag.base03};
      }

      tooltip {
        background: rgba(${rgb "base00"}, 0.9);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 10px;
      }

      tooltip label {
        color: ${c.withHashtag.base05};
      }
    '';
  };
}
