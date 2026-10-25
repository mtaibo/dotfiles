{ ... }: {
  # Steam with its FHS runtime; 32-bit graphics come from nvidia.nix.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
