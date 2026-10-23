# One design for the lock screen (hyprlock, modules/home/desktop/hyprlock.nix)
# and the login screen (SDDM theme, modules/nixos/desktop/greeter.nix), so the
# two look identical. Positions are pixel offsets from the screen centre with
# y pointing up, and font sizes are points, both the way hyprlock reads them.
# `colors` is Stylix's palette (config.lib.stylix.colors) and `font` its UI font.
{ colors, font }: {
  inherit font;

  background = {
    blurPasses = 3;
    blurSize = 8;
    brightness = 0.7;
    vibrancy = 0.2;
  };

  # Text colours are base07 with an alpha suffix ("dd" = 87 %).
  date = {
    strftime = "%A, %e de %B"; # hyprlock runs `date`
    qtFormat = "dddd, d 'de' MMMM"; # the SDDM theme formats it in QML
    locale = "es_ES";
    size = 22;
    weight = "Regular";
    color = "${colors.base07}dd";
    y = 330;
  };

  clock = {
    size = 110;
    weight = "Bold";
    color = "${colors.base07}ee";
    y = 220;
  };

  name = {
    size = 15;
    weight = "SemiBold";
    color = "${colors.base07}ee";
    y = -160;
  };

  input = {
    width = 260;
    height = 44;
    y = -215;
    fill = "ffffff1a";
    outline = "ffffff26";
    textColor = colors.base05;
    checkColor = colors.base0A;
    failColor = colors.base08;
    dotsSize = 0.25; # of the field's height
    dotsSpacing = 0.3; # of the dot size
    placeholder = "Contraseña";
    placeholderColor = "${colors.base07}99";
    failText = "Contraseña incorrecta";
    failTimeoutMs = 2000;
  };

  fadeMs = 400;
}
