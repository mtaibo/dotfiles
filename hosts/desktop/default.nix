{ config, lib, pkgs, inputs, ... }:
let
  people = {
    migueltaibo = "Miguel Taibo";
    pablotaibo = "Pablo Taibo";
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/desktop/hyprland.nix
    ../../modules/nixos/desktop/nvidia.nix
    ../../modules/nixos/desktop/stylix.nix
    ../../modules/nixos/desktop/greeter.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  system.stateVersion = "25.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.claude-desktop.enable = true;

  # Lets dynamically linked binaries built for generic Linux run as-is
  # (e.g. the native helper VS Code extensions like Claude Code ship).
  programs.nix-ld.enable = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };
  console.keyMap = "es";

  # Every user gets the same account and the same setup (modules/home plus
  # the desktop modules); only the name changes. Login: SDDM, ←/→ picks one.
  users.users = lib.mapAttrs (_: description: {
    isNormalUser = true;
    inherit description;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  }) people;
  home-manager.users = lib.mapAttrs (_: _: {
    imports = [ ../../modules/home ../../modules/home/desktop ];
  }) people;
  programs.zsh.enable = true;


  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
  programs.git = {
    enable = true;
    config = {
      user.name = "Miguel Taibo";
      user.email = "miguel.taibo@icloud.com";
      init.defaultBranch = "main";
    };
  };

  virtualisation.docker.enable = true;

  # NTFS "Storage" partition on the Windows dual-boot disk (sda1)
  fileSystems."/mnt/shared" = {
    device = "/dev/disk/by-uuid/342030672030326A";
    fsType = "ntfs3";
    # Group `users` (every account) can write too.
    options = [ "rw" "uid=1000" "gid=100" "umask=002" "nofail" ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  environment.systemPackages = with pkgs; [
    neovim
    git
    gh
    docker-client
    docker-compose
    cifs-utils
  ];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

}
