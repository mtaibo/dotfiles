{ lib, pkgs, ... }:
let
  # SUPER+F: a new tab in the open Firefox (`firefox --new-tab` never reached
  # the running instance), or Firefox itself, which starts on a blank page.
  firefox-tab = pkgs.writeShellScriptBin "firefox-tab" ''
    if hyprctl clients -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .class == "firefox")' >/dev/null; then
      hyprctl dispatch focuswindow 'class:^(firefox)$'
      hyprctl dispatch sendshortcut 'CTRL, T, class:^(firefox)$'
    else
      exec firefox
    fi
  '';
in {
  home.packages = [ firefox-tab ];

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
      "$browser" = "firefox-tab";
      "$menu" = "vicinae toggle";

      # `bindd` = bind with a description; SUPER+H lists them (see cheatsheet.nix).
      # Descriptions can't contain commas. mkBefore keeps these first in the list.
      bindd = lib.mkBefore ([
        "SUPER, SPACE, Lanzador de aplicaciones, exec, $menu"
        "SUPER, Q, Terminal, exec, $terminal"
        "SUPER, F, Firefox, exec, $browser"
        "SUPER, R, Claude, exec, claude-desktop"
        "SUPER, S, Steam, exec, steam"
        "SUPER, C, Cerrar la ventana, killactive,"
        "SUPER SHIFT, F, Pantalla completa, fullscreen,"
        "SUPER, V, Ventana flotante o en mosaico, togglefloating,"
        "SUPER, L, Bloquear la pantalla, exec, lock-screen"
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

      # Firefox marks a tiled window fully opaque, so Hyprland would draw
      # nothing behind its glass; any opacity below 1 makes it blend.
      windowrule = [ "opacity 0.99 override, class:^(firefox)$" ];

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

      # Games: adaptive sync only for fullscreen windows (2) so the desktop
      # stays as it is. No direct scanout: on NVIDIA it can glitch or slow games.
      misc.vrr = 2;

      input = {
        # Spanish; system-language (language.nix) switches it to "us" and back.
        kb_layout = "es";
        follow_mouse = 1;
      };
    };
  };

  # SUPER+H shows these when the system language is English (language.nix).
  dotfiles.english = {
    "Lanzador de aplicaciones" = "App launcher";
    "Terminal" = "Terminal";
    "Firefox" = "Firefox";
    "Claude" = "Claude";
    "Steam" = "Steam";
    "Cerrar la ventana" = "Close the window";
    "Pantalla completa" = "Fullscreen";
    "Ventana flotante o en mosaico" = "Floating or tiled window";
    "Bloquear la pantalla" = "Lock the screen";
    "Salir de Hyprland" = "Quit Hyprland";
    "Captura de una zona al portapapeles" = "Screenshot of an area to the clipboard";
    "Subir el volumen" = "Volume up";
    "Bajar el volumen" = "Volume down";
    "Silenciar" = "Mute";
    "Reproducir o pausar la música" = "Play or pause the music";
    "Siguiente canción" = "Next song";
    "Canción anterior" = "Previous song";
    "Foco a la izquierda" = "Focus left";
    "Foco abajo" = "Focus down";
    "Foco arriba" = "Focus up";
    "Foco a la derecha" = "Focus right";
    "Estrechar la ventana" = "Make the window narrower";
    "Alargar la ventana" = "Make the window taller";
    "Acortar la ventana" = "Make the window shorter";
    "Ensanchar la ventana" = "Make the window wider";
    "Mover la ventana a la izquierda" = "Move the window left";
    "Mover la ventana abajo" = "Move the window down";
    "Mover la ventana arriba" = "Move the window up";
    "Mover la ventana a la derecha" = "Move the window right";
  } // lib.listToAttrs (lib.concatMap (n: [
    (lib.nameValuePair "Ir al escritorio ${n}" "Go to workspace ${n}")
    (lib.nameValuePair "Mandar la ventana al escritorio ${n}" "Send the window to workspace ${n}")
  ]) (map toString (lib.range 1 9)));
}
