{ ... }: {
  # Steam with its FHS runtime; 32-bit graphics come from nvidia.nix.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # `gamemoderun %command%` in a game's launch options: performance CPU
  # governor and higher priority while it runs.
  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };

  # 16 GB and no swap: big games fill RAM, so compressed swap in RAM keeps
  # them from stuttering or being killed.
  zramSwap.enable = true;
}
