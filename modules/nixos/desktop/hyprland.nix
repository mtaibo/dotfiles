{ pkgs, ... }: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Installs hyprlock and its PAM service so it can check the password.
  programs.hyprlock.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  environment.systemPackages = with pkgs; [
    libnotify
    wl-clipboard
  ];
}
