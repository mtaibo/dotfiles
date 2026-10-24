{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  settings = "${config.xdg.configHome}/sh.cider.genten/spa-config.yml";
  clientOptions = "${config.xdg.configHome}/sh.cider.genten/client-options.yml";
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

  # Cider's macOS tray template (the logo in black on transparent) in white,
  # swapped in for its red Linux tray icon so the bar's tray stays monochrome.
  trayIcon = pkgs.runCommand "cider-tray-white.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick ${pkgs.cider-2}/lib/cider/resources/public/trayTemplate@2x.png \
      -fill white -colorize 100 $out
  '';
  package = pkgs.cider-2.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp ${trayIcon} $out/lib/cider/resources/public/tray.png
    '';
  });

  # Cider (an Apple Music client) keeps its settings in a YAML file, so the
  # launcher writes the theme in before starting it: transparent window,
  # the wallpaper's accent instead of Apple's red, no album-art tinting,
  # Stylix's font, no in-app window buttons (Hyprland has none) and the CSS
  # above. Closing the window only hides it, so the music keeps playing.
  # Launching Cider again doesn't bring a hidden window back (it boots a
  # second copy that gives up), so when Cider is already running the launcher
  # "clicks" its tray icon over D-Bus instead, which shows the window. The
  # files only exist after the first launch, so the theme shows from the
  # second one; a wallpaper change reaches Cider on its next start.
  cider = pkgs.writeShellApplication {
    name = "cider";
    runtimeInputs = [ pkgs.yq-go pkgs.procps pkgs.systemd package ];
    text = ''
      if pgrep -x Cider >/dev/null; then
        # Find the tray item whose owner process is Cider and activate it.
        items=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
          org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems | grep -o '"[^"]*"' | tr -d '"')
        for item in $items; do
          service=''${item%%/*}
          pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
            GetConnectionUnixProcessID s "$service" | cut -d' ' -f2)
          if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = Cider ]; then
            busctl --user call "$service" "/''${item#*/}" org.kde.StatusNotifierItem Activate ii 0 0
            exit 0
          fi
        done
        exit 0
      fi

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
            .visual.customCSS = strenv(CSS) |
            .general.closeToTray = true
          ' ${settings}
        # The tray icon is the only way back to a hidden window.
        yq -i ".enableTrayIcon = true" ${clientOptions}
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
    icon = "${package}/share/icons/hicolor/256x256/apps/cider.png";
    categories = [ "Audio" "AudioVideo" "Music" ];
    settings.StartupWMClass = "Cider";
  };

  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, K, Abrir Cider, exec, cider"
  ];
}
