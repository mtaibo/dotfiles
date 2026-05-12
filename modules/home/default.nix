{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./packages.nix
    ./brave.nix
  ];

  # System-wide dark theme (also makes Brave chrome dark)
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  home.username = "mtaibo";
  home.homeDirectory = "/home/mtaibo";
  home.stateVersion = "25.11";

  programs.kitty.enable = true;
  programs.vscode.enable = true;

  home.file.".config/hypr".source = ./dotfiles/hypr;
  home.file.".config/kitty".source = ./dotfiles/kitty;
  home.file.".config/starship.toml".source = ./dotfiles/starship.toml;
  home.file.".config/zsh/.zshrc".source = ./dotfiles/zsh/.zshrc;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/downloads";
    documents = "$HOME/downloads";
    download = "$HOME/downloads";
    music = "$HOME/downloads";
    pictures = "$HOME/downloads";
    publicShare = "$HOME/downloads";
    templates = "$HOME/downloads";
    videos = "$HOME/downloads";
  };

  programs.home-manager.enable = true;
}
