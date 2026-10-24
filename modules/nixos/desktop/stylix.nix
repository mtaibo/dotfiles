{ lib, pkgs, inputs, ... }:
let
  walls = import ../../wallpapers.nix pkgs;
in {
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = walls.default;

    base16Scheme = import ../../palette.nix;

    fonts = {
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 15;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    opacity = {
      desktop = 0.6;
      popups = 0.85;
      terminal = 0.7;
    };
  };

  home-manager.users.migueltaibo.stylix.targets = {
    # Firefox looks like a native GTK app (firefox-gnome-theme) in our colours.
    firefox = {
      profileNames = [ "default" ];
      firefoxGnomeTheme.enable = true;
    };
    # These apps keep their own hand-picked themes.
    neovim.enable = false;
    # The prompt uses the terminal's named colours instead, so its accent
    # follows the wallpaper with kitty's (see modules/home/desktop/wallpaper.nix).
    starship.enable = false;
    vscode.enable = false;
    # The bar is styled by hand in modules/home/desktop/waybar.nix.
    waybar.enable = false;
  };

  # Where SUPER+W records the wallpaper in use (see modules/wallpapers.nix):
  # owned by me so I can switch it, readable by the login screen's user.
  # `L` only creates the link when missing, so a choice survives rebuilds.
  systemd.tmpfiles.rules = [
    "d /var/lib/wallpaper 0755 migueltaibo users -"
    "L ${walls.current} - - - - ${walls.default}"
  ];

  # Hyprland has no use for the minimise/maximise/close buttons the theme draws.
  # mkAfter keeps this below the theme's @import lines.
  home-manager.users.migueltaibo.programs.firefox.profiles.default.userChrome = lib.mkAfter ''
    .titlebar-buttonbox-container { display: none !important; }
  '';
}
