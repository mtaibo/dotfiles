{ config, lib, pkgs, ... }:
let
  users = config.dotfiles.steam.users;
in {
  # One Steam library for every account, so a game installed by one is
  # installed for all. The files live once in /srv/steam (root only); each
  # user sees it at ~/games/steam through bindfs, with every file shown as
  # theirs, so Steam can update a game the other account installed.
  # (A list here because reading users.users from fileSystems recurses.)
  options.dotfiles.steam.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Accounts that share the Steam library.";
  };

  config = {
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

    # The DualSense touchpad shows up as a touchpad and moves the cursor; hide
    # it from libinput (Hyprland) only. Steam reads the controller over hidraw,
    # so the touchpad still works inside games. Over USB it's named "Sony
    # Interactive Entertainment DualSense…", over Bluetooth just "DualSense…".
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="*DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

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

    fileSystems = lib.listToAttrs (map (name: lib.nameValuePair "/home/${name}/games/steam" {
      device = "/srv/steam";
      fsType = "fuse.bindfs";
      options = [
        "force-user=${name}" "force-group=users" "perms=u+rwX"
        "chown-ignore" "chgrp-ignore" "allow_other" "nofail"
      ];
    }) users);
    system.fsPackages = [ pkgs.bindfs ];

    # Steam puts the library one level down, in ~/games/steam/SteamLibrary.
    # Proton prefixes (saves, settings) and shader caches stay per user:
    # compatdata and shadercache are relative links that, seen from
    # ~/games/steam/SteamLibrary/steamapps, land in ~/games. Wine refuses a
    # prefix owned by someone else, and each Steam client keeps its own record
    # of the shader cache, so a shared one is downloaded and reprocessed every
    # time the other account plays.
    systemd.tmpfiles.rules = [
      "d /srv/steam 0700 root root -"
      "d /srv/steam/SteamLibrary 0755 root root -"
      "d /srv/steam/SteamLibrary/steamapps 0755 root root -"
      "L+ /srv/steam/SteamLibrary/steamapps/compatdata - - - - ../../../proton"
      "L+ /srv/steam/SteamLibrary/steamapps/shadercache - - - - ../../../shadercache"
    ] ++ lib.concatMap (name: [
      "d /home/${name}/games 0755 ${name} users -"
      "d /home/${name}/games/proton 0755 ${name} users -"
      "d /home/${name}/games/shadercache 0755 ${name} users -"
    ]) users;
  };
}
