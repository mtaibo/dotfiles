{ config, lib, ... }: {
  # Colours, font and opacity come from Stylix (modules/nixos/desktop/stylix.nix).
  programs.kitty = {
    enable = true;
    settings = {
      disable_ligatures = "never";
      window_padding_width = 15;
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;
      linux_display_server = "wayland";
    };
    # Stylix maps bright black (what eza, ls and the starship branch use for
    # greys) to base02, almost the background; the muted-text grey reads.
    extraConfig = lib.mkAfter (''
      color8 ${config.lib.stylix.colors.withHashtag.base03}
    '' + builtins.readFile ../../../assets/kitty/unmap.conf);
  };
}
