{ pkgs, inputs, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;

  networking.hostName = "macbook";

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  environment.systemPackages = with pkgs; [
    neovim
    git
    gh
  ];

  programs.nix-index.enable = true;
}
