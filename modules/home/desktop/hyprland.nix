{ lib, ... }: {
  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland itself and its portal come from the NixOS module.
    package = null;
    portalPackage = null;

    # Wallpaper (hyprpaper) and colours come from Stylix; waybar starts as a
    # systemd user service, and so does dunst.
    settings = {
      monitor = ",preferred,auto,1";

      "$terminal" = "kitty";
      "$browser" = "firefox";
      "$menu" = "vicinae toggle";

      bind = [
        "SUPER, Q, exec, $terminal"
        "SUPER, F, exec, $browser"
        "SUPER, SPACE, exec, $menu"
        "SUPER, R, exec, claude-desktop"
        "SUPER, C, killactive,"
        "SUPER SHIFT, F, fullscreen,"
        "SUPER, L, exec, hyprlock"
        "SUPER, V, togglefloating,"
        "SUPER, M, exec, hyprctl dispatch exit"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"

        # Volume
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Window navigation (hjkl)
        "SUPER, h, movefocus, l"
        "SUPER, j, movefocus, d"
        "SUPER, k, movefocus, u"
        "SUPER, l, movefocus, r"

        # Resize windows (SUPER + SHIFT + hjkl)
        "SUPER SHIFT, h, resizeactive, -10 0"
        "SUPER SHIFT, j, resizeactive, 0 10"
        "SUPER SHIFT, k, resizeactive, 0 -10"
        "SUPER SHIFT, l, resizeactive, 10 0"

        # Move windows within layout (SUPER + ALT + hjkl)
        "SUPER ALT, h, movewindow, l"
        "SUPER ALT, j, movewindow, d"
        "SUPER ALT, k, movewindow, u"
        "SUPER ALT, l, movewindow, r"
      ]
      # Workspaces 1-9: SUPER + n switches, SUPER + SHIFT + n moves the window
      ++ lib.concatMap (n: [
        "SUPER, ${n}, workspace, ${n}"
        "SUPER SHIFT, ${n}, movetoworkspace, ${n}"
      ]) (map toString (lib.range 1 9));

      # Mouse resize/move (hold SUPER and drag)
      bindm = [
        "SUPER, mouse:272, resizewindow"
        "SUPER, mouse:273, movewindow"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        # Keep borders grey instead of Stylix's accent colour.
        "col.active_border" = lib.mkForce "rgba(ddddddee)";
        "col.inactive_border" = lib.mkForce "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          noise = 0.02;
          vibrancy = 0.2;
        };
      };

      # Frosted glass behind the bar, notifications and launcher
      layerrule = [
        "blur, waybar"
        "ignorezero, waybar"
        "blur, notifications"
        "ignorezero, notifications"
        "blur, vicinae"
        "ignorealpha 0, vicinae"
      ];

      animations = {
        bezier = [ "snappy, 0.05, 0.9, 0.1, 1.05" ];
        animation = [
          "windows, 1, 3, snappy"
          "windowsOut, 1, 3, snappy"
          "fade, 1, 3, snappy"
          "workspaces, 1, 2, snappy"
          "border, 1, 5, default"
        ];
      };

      input = {
        kb_layout = "es";
        follow_mouse = 1;
      };
    };
  };
}
