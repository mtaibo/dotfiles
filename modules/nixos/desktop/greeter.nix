{ config, ... }:
let
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
in {
  # Login screen: greetd + ReGreet (GTK4, runs inside cage). Stylix sets the
  # wallpaper, colours, font and cursor; the CSS below adds the same frosted
  # panels and pill inputs as the bar and hyprlock.
  programs.regreet = {
    enable = true;
    settings = {
      appearance.greeting_msg = "Bienvenido";
      widget.clock = {
        format = "%H:%M";
        label_width = 150;
      };
    };
  };

  systemd.services.greetd.environment = {
    # cage ignores the console keymap; without this the password is typed in US layout.
    XKB_DEFAULT_LAYOUT = "es";
    # cage is wlroots-based; hardware cursors can come out invisible on NVIDIA.
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  stylix.targets.regreet.extraCss = ''
    frame {
      background-color: rgba(${rgb "base00"}, 0.55);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 18px;
      padding: 12px;
    }

    entry,
    combobox button,
    dropdown button {
      border-radius: 999px;
      background-color: rgba(255, 255, 255, 0.10);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: ${c.withHashtag.base07};
      min-height: 36px;
      padding: 0 14px;
      box-shadow: none;
    }

    button {
      border-radius: 10px;
    }

    button.suggested-action {
      background-color: rgba(255, 255, 255, 0.18);
      color: ${c.withHashtag.base07};
    }

    button.suggested-action:hover {
      background-color: rgba(255, 255, 255, 0.26);
    }
  '';
}
