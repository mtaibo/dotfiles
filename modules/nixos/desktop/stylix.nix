{ lib, pkgs, inputs, ... }:
let
  walls = import ../../wallpapers.nix pkgs;
in {
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = walls.default;

    # macOS-like dark greys with muted accents; colour only shows up where it
    # carries meaning (syntax, warnings), everything else stays grey.
    base16Scheme = {
      base00 = "1c1c1e"; # background
      base01 = "2c2c2e"; # raised surfaces
      base02 = "3a3a3c"; # selection
      base03 = "8e8e93"; # comments, muted text (readable on glass)
      base04 = "aeaeb2"; # secondary text
      base05 = "e5e5ea"; # foreground
      base06 = "f2f2f7";
      base07 = "ffffff";
      base08 = "e5736b"; # red
      base09 = "e0a060"; # orange
      base0A = "e5cc73"; # yellow
      base0B = "7cc68a"; # green
      base0C = "7fc8d9"; # cyan
      base0D = "6aa9f2"; # blue (accent)
      base0E = "c49bdc"; # purple
      base0F = "a89279"; # brown
    };

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
