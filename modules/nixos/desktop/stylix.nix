{ lib, pkgs, inputs, ... }: {
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";
    image = ../../../assets/wallpaper.jpg;

    # macOS-like dark greys with muted accents; colour only shows up where it
    # carries meaning (syntax, warnings), everything else stays grey.
    base16Scheme = {
      base00 = "1c1c1e"; # background
      base01 = "2c2c2e"; # raised surfaces
      base02 = "3a3a3c"; # selection
      base03 = "636366"; # comments, muted text
      base04 = "8e8e93"; # secondary text
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
      terminal = 0.85;
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
    vscode.enable = false;
    # The bar is styled by hand in modules/home/desktop/waybar.nix.
    waybar.enable = false;
  };

  # Hyprland has no use for the minimise/maximise/close buttons the theme draws.
  # mkAfter keeps this below the theme's @import lines.
  home-manager.users.migueltaibo.programs.firefox.profiles.default.userChrome = lib.mkAfter ''
    .titlebar-buttonbox-container { display: none !important; }
  '';
}
