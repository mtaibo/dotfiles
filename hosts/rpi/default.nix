{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/rpi/firmware.nix
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

  boot.kernelPackages = pkgs.linuxPackages_rpi4;

  programs.dconf.enable = true;

  system.activationScripts.rpi5-oscheck = ''
    if [ -f /boot/config.txt ]; then
      grep -q "os_check=0" /boot/config.txt || echo "os_check=0" >> /boot/config.txt
    fi
  '';

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
