{ config, lib, pkgs, inputs, ... }:
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

  # Where SUPER+W records the wallpaper in use (see modules/wallpapers.nix):
  # writable by every user (group `users`) so anyone can switch it, readable
  # by the login screen's user. `L` only creates the link when missing, so a
  # choice survives rebuilds.
  systemd.tmpfiles.rules = [
    "d /var/lib/wallpaper 0775 migueltaibo users -"
    "L ${walls.current} - - - - ${walls.default}"
  ];

  # For every user (see hosts/desktop/default.nix).
  home-manager.sharedModules = [{ stylix.targets = {
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
  }; }

  # mkAfter keeps these below the theme's @import lines.
  { programs.firefox.profiles.default = let
    c = config.lib.stylix.colors;
    glass = "rgba(${c.base00-rgb-r}, ${c.base00-rgb-g}, ${c.base00-rgb-b}, ${toString config.stylix.opacity.terminal})";
  in {
    # Glass like kitty: the window itself is the terminal's background at its
    # opacity and everything on top is see-through, so the toolbar and pages
    # without a background (the new tab) show the blurred desktop. Hyprland
    # needs an opacity rule for it (see modules/home/desktop/hyprland.nix).
    userChrome = lib.mkAfter ''
      :root, #main-window {
        appearance: none !important;
        background: ${glass} !important;
        --gnome-headerbar-background: transparent !important;
        --gnome-window-background: transparent !important;
        --tabpanel-background-color: transparent !important;
      }
      /* The window's <body> paints an opaque grey over :root. */
      #main-window > body, #navigator-toolbox, #nav-bar, #TabsToolbar, #titlebar, #PersonalToolbar,
      #browser, #appcontent, #tabbrowser-tabbox, #tabbrowser-tabpanels,
      .browserContainer, .browserStack, browser[type="content"] {
        background: transparent !important;
      }
      .tab-background[selected] { background: rgba(255, 255, 255, 0.08) !important; }
      #firefox-view-button { display: none !important; }
      /* Hyprland has no use for the minimise/maximise/close buttons. */
      .titlebar-buttonbox-container { visibility: collapse !important; }
    '';
    userContent = lib.mkAfter ''
      @-moz-document url("about:blank"), url("about:newtab"), url("about:home") {
        :root, body { background: transparent !important; }
      }
      /* The new tab page still draws its customise (pencil) button: hide all of it. */
      @-moz-document url("about:newtab"), url("about:home") {
        body > * { display: none !important; }
      }
    '';
  }; }];
}
