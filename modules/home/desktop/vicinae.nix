{
  # Raycast-style launcher on SUPER+Space. Colours and opacity come from
  # Stylix; it runs as a daemon so `vicinae toggle` opens instantly, and
  # Hyprland blurs the "vicinae" layer behind it.
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      popToRootOnClose = true;
      closeOnFocusLoss = true;
      window = {
        csd = true;
        rounding = 14;
      };
    };
  };
}
