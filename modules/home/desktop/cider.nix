{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  settings = "${config.xdg.configHome}/sh.cider.genten/spa-config.yml";
  # Written by matugen on every wallpaper change (see wallpaper.nix).
  accentFile = "${config.xdg.configHome}/cider/accent";

  # Glass like kitty: Stylix's background at 70 % so Hyprland's blur shows
  # through, instead of Cider's opaque greys.
  css = pkgs.writeText "cider.css" ''
    html, body, #app { background: transparent !important; }
    :root, body {
      --bgColor: rgba(${rgb "base00"}, 0.7) !important;
      --q-dark: rgba(${rgb "base00"}, 0.7) !important;
      --qDark: rgba(${rgb "base00"}, 0.7) !important;
      --qDarkPage: rgba(${rgb "base00"}, 0.7) !important;
      --qDarkHUD: rgba(${rgb "base00"}, 0.85) !important;
      --playerBackground: rgba(${rgb "base01"}, 0.6) !important;
      --playerBackgroundFallback: rgba(${rgb "base01"}, 0.85) !important;
    }
  '';

  # Cider (an Apple Music client) keeps its settings in a YAML file, so the
  # launcher writes the theme in before starting it: transparent window,
  # the wallpaper's accent instead of Apple's red, no album-art tinting,
  # Stylix's font, no in-app window buttons (Hyprland has none) and the CSS
  # above. The file only exists after the first launch, so the theme shows
  # from the second one; a wallpaper change reaches Cider on its next start.
  cider = pkgs.writeShellApplication {
    name = "cider";
    runtimeInputs = [ pkgs.yq-go pkgs.cider-2 ];
    text = ''
      if [ -f ${settings} ]; then
        ACCENT=$(cat ${accentFile} 2>/dev/null || echo "${c.withHashtag.base0D}") \
        CSS=$(cat ${css}) \
          yq -i '
            .visual.transparency = true |
            .visual.useAdaptiveColors = false |
            .visual.ui_custom.customAccentColor = true |
            .visual.ui_custom.customAccentColorValue = strenv(ACCENT) |
            .visual.fonts.main = "${config.stylix.fonts.sansSerif.name}" |
            .visual.titleBarStyle = "native" |
            .visual.customCSS = strenv(CSS)
          ' ${settings}
      fi
      exec cider-2 "$@"
    '';
  };
in {
  # Only the launcher is installed, so Vicinae shows this entry and not the
  # package's own one, which would skip the theme.
  home.packages = [ cider ];

  xdg.desktopEntries.cider = {
    name = "Cider";
    genericName = "Apple Music";
    exec = "cider %U";
    icon = "${pkgs.cider-2}/share/icons/hicolor/256x256/apps/cider.png";
    categories = [ "Audio" "AudioVideo" "Music" ];
    settings.StartupWMClass = "Cider";
  };
}
