{ config, pkgs, lib, nixos-raspberrypi, ... }: {
  imports = [
    ./hardware-configuration.nix
    nixos-raspberrypi.lib.inject-overlays
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
  ];

  networking.hostName = "tphome";
  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.max-jobs = 1;
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  users.users.migueltaibo = {
    isNormalUser = true;
    description = "Miguel Taibo";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    initialPassword = "changeme";
  };
  users.users.migueltaibo.shell = pkgs.zsh;
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  swapDevices = [{
    device = "/swapfile";
    size = 4096;
  }];

  boot.loader.raspberry-pi = {
    firmwarePath = "/boot";
    bootloader = "kernel";
    configurationLimit = 3;
  };

  programs.dconf.enable = true;

  virtualisation.docker.enable = true;

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

  environment.systemPackages = with pkgs; [
    neovim
    git
    gh
    docker-client
    docker-compose
    fastfetch
    eza
    bat
  ];
}
