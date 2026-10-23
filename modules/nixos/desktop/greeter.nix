{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  user = "migueltaibo";

  # The same design hyprlock uses (modules/lockscreen.nix), plus what only the
  # login screen needs. Written as a QML object: JSON is valid JavaScript.
  design = import ../../lockscreen.nix {
    colors = c;
    font = config.stylix.fonts.sansSerif.name;
  };
  styleQml = ''
    import QtQuick

    QtObject {
        readonly property var s: ${builtins.toJSON (design // {
          background = design.background // { color = c.base00; };
          # Same wallpaper as the desktop and the lock screen, Stylix's as fallback.
          wallpaper = (import ../../wallpapers.nix pkgs).current;
          fallbackWallpaper = "${config.stylix.image}";
          inherit user;
          realName = config.users.users.${user}.description;
        })}
    }
  '';
  mainQml = ../../../assets/sddm/Main.qml;

  # Qt caches compiled QML by path + mtime, and every Nix store file has the
  # same mtime, so under a fixed path the greeter kept running the first
  # version of the theme. A content hash in the theme's name gives every
  # version its own path.
  themeName = "glass-" + builtins.substring 0 8
    (builtins.hashString "sha256" (builtins.readFile mainQml + styleQml));

  theme = pkgs.runCommandLocal "sddm-theme-${themeName}" { } ''
    dir=$out/share/sddm/themes/${themeName}
    mkdir -p $dir
    cp ${mainQml} $dir/Main.qml
    cp ${../../../assets/sddm/metadata.desktop} $dir/metadata.desktop
    cp ${pkgs.writeText "Style.qml" styleQml} $dir/Style.qml
  '';
in {
  # Login screen: SDDM with a custom QML theme that reproduces the hyprlock
  # lock screen (Stylix has no SDDM target, so colours come in through
  # Style.qml). User and session are picked automatically.
  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = themeName;
      settings.Theme = {
        CursorTheme = config.stylix.cursor.name;
        CursorSize = config.stylix.cursor.size;
      };
    };
  };

  # The greeter's compositor (weston) takes its keymap from here.
  services.xserver.xkb.layout = "es";

  environment.systemPackages = [ theme config.stylix.cursor.package ];
}
