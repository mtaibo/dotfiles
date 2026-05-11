{ pkgs, ... }:

{
  home.username = "mtaibo";
  home.homeDirectory = "/home/mtaibo";
  home.stateVersion = "25.11";

  programs.kitty.enable = true;
  programs.starship.enable = true;

  home.file.".config/kitty/kitty.conf".source = ./config/kitty/kitty.conf;
  home.file.".config/starship.toml".source = ./config/starship.toml;

  home.packages = with pkgs; [
    fastfetch
  ];

  programs.home-manager.enable = true;
}
