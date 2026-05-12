{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./packages.nix
  ];

  home.username = "mtaibo";
  home.homeDirectory = "/home/mtaibo";
  home.stateVersion = "25.11";

  programs.kitty.enable = true;

  home.file.".config/kitty".source = ./dotfiles/kitty;
  home.file.".config/starship.toml".source = ./dotfiles/starship.toml;

  programs.home-manager.enable = true;
}
