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

      # `bindd` = bind with a description; SUPER+H lists them (see cheatsheet.nix).
      # Descriptions can't contain commas. mkBefore keeps these first in the list.
      bindd = lib.mkBefore ([
        "SUPER, SPACE, Lanzador de aplicaciones, exec, $menu"
        "SUPER, Q, Terminal, exec, $terminal"
        "SUPER, F, Firefox, exec, $browser"
        "SUPER, R, Claude, exec, claude-desktop"
        "SUPER, C, Cerrar la ventana, killactive,"
        "SUPER SHIFT, F, Pantalla completa, fullscreen,"
        "SUPER, V, Ventana flotante o en mosaico, togglefloating,"
        "SUPER, L, Bloquear la pantalla, exec, hyprlock"
        "SUPER, M, Salir de Hyprland, exec, hyprctl dispatch exit"

        ", Print, Captura de una zona al portapapeles, exec, grim -g \"$(slurp)\" - | wl-copy"

        ", XF86AudioRaiseVolume, Subir el volumen, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, Bajar el volumen, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, Silenciar, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, Reproducir o pausar la música, exec, playerctl play-pause"
        ", XF86AudioNext, Siguiente canción, exec, playerctl next"
        ", XF86AudioPrev, Canción anterior, exec, playerctl previous"

        # Windows with the arrows: SUPER focuses, + SHIFT resizes, + ALT moves.
        "SUPER, left, Foco a la izquierda, movefocus, l"
        "SUPER, down, Foco abajo, movefocus, d"
        "SUPER, up, Foco arriba, movefocus, u"
        "SUPER, right, Foco a la derecha, movefocus, r"

        "SUPER SHIFT, left, Estrechar la ventana, resizeactive, -10 0"
        "SUPER SHIFT, down, Alargar la ventana, resizeactive, 0 10"
        "SUPER SHIFT, up, Acortar la ventana, resizeactive, 0 -10"
        "SUPER SHIFT, right, Ensanchar la ventana, resizeactive, 10 0"

        "SUPER ALT, left, Mover la ventana a la izquierda, movewindow, l"
        "SUPER ALT, down, Mover la ventana abajo, movewindow, d"
        "SUPER ALT, up, Mover la ventana arriba, movewindow, u"
        "SUPER ALT, right, Mover la ventana a la derecha, movewindow, r"
      ]
      # Workspaces 1-9: SUPER + n switches, SUPER + SHIFT + n moves the window
      ++ lib.concatMap (n: [
        "SUPER, ${n}, Ir al escritorio ${n}, workspace, ${n}"
        "SUPER SHIFT, ${n}, Mandar la ventana al escritorio ${n}, movetoworkspace, ${n}"
      ]) (map toString (lib.range 1 9)));

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
        # Light blur that also darkens what's behind: shapes still show through
        # glass (terminal, bar, popups) while text on it stays readable, even
        # over a bright wallpaper.
        blur = {
          enabled = true;
          size = 5;
          passes = 2;
          brightness = 0.7;
          contrast = 1.0;
          noise = 0.02;
          vibrancy = 0.1;
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
