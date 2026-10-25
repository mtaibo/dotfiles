{ pkgs, ... }: {
  # Steam with its FHS runtime; 32-bit graphics come from nvidia.nix.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    package = pkgs.steam.override {
      extraEnv = {
        # NVIDIA's API inside Proton, so games offer DLSS, Frame Generation
        # and Reflex; the DLSS upgrade swaps a game's bundled DLSS for the
        # latest one.
        PROTON_ENABLE_NVAPI = "1";
        PROTON_DLSS_UPGRADE = "1";
        # Keep compiled shaders instead of trimming the cache at 1 GB, so big
        # games don't recompile them (and stutter) on every launch.
        __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
      };
    };
  };

  # `mangohud %command%` in a game's launch options: FPS, GPU and CPU load
  # overlay, to see which one holds a game back.
  environment.systemPackages = [ pkgs.mangohud ];

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
