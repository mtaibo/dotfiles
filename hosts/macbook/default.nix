{ pkgs, inputs, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;

  services.ollama = {
    enable = true;
  };

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

  environment.systemPackages = with pkgs; [
    neovim
    git
    gh
    colima
    docker-client
    ollama
  ];

  programs.nix-index.enable = true;
}
