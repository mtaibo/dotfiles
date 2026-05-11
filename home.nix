{ pkgs, ... }:

{
  home.username = "mtaibo";
  home.homeDirectory = "/home/mtaibo";
  home.stateVersion = "25.11";

  programs.kitty.enable = true;
  programs.starship.enable = true;

  home.file.".config/kitty".source = ./config/kitty;
  home.file.".config/starship.toml".source = ./config/starship.toml;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake .#nixos";
      conf = "nvim ~/Workspace/dotfiles/configuration.nix";
      hconf = "nvim ~/Workspace/dotfiles/home.nix";
    };
    
    initContent = ''
      fastfetch
      eval "$(starship init zsh)"
    '';
  };

  home.packages = with pkgs; [
    fastfetch
  ];

  programs.home-manager.enable = true;
}
