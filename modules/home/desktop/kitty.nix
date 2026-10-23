{
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
  };
}
