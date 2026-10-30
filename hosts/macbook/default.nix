{ pkgs, inputs, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;

  networking.hostName = "macbook";

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "lima-full-1.2.2"
    "lima-additional-guestagents-1.2.2"
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  # `crc` turns lid sleep off and on without a password prompt.
  security.sudo.extraConfig = ''
    migueltaibo ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1
  '';

  imports = [ ../../modules/darwin/batt.nix ];

  environment.systemPackages = with pkgs; [
    git
    gh
    colima
    docker-client
    xcodegen
  ];

}
