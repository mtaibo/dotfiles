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
  style = pkgs.writeText "Style.qml" ''
    import QtQuick

    QtObject {
        readonly property var s: ${builtins.toJSON (design // {
          background = design.background // { color = c.base00; };
          wallpaper = "${config.stylix.image}";
          inherit user;
          realName = config.users.users.${user}.description;
        })}
    }
  '';

  theme = pkgs.runCommandLocal "sddm-theme-glass" { } ''
    dir=$out/share/sddm/themes/glass
    mkdir -p $dir
    cp ${../../../assets/sddm/Main.qml} $dir/Main.qml
    cp ${../../../assets/sddm/metadata.desktop} $dir/metadata.desktop
    cp ${style} $dir/Style.qml
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
      theme = "glass";
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
