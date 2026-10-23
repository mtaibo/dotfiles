{ lib, pkgs, ... }: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Installs hyprlock and its PAM service so it can check the password.
  programs.hyprlock.enable = true;
  # ...which also turns hypridle on by default. No idle locking or screen
  # blanking wanted, and without a config it just crashed on every login.
  services.hypridle.enable = lib.mkForce false;

  # Reboots used to hang: the document portal's FUSE mount sometimes never
  # finishes stopping, and the user manager waited the default 90 s for it.
  # Give it 5 s, and cap every user service at 10 s so no other one can
  # stall a shutdown for long either.
  systemd.user.services.xdg-document-portal.serviceConfig.TimeoutStopSec = "5s";
  systemd.user.extraConfig = "DefaultTimeoutStopSec=10s";

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
