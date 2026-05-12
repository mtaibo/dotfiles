{ pkgs, lib, ... }: {
  imports = [
    ./shell.nix
    ./packages.nix
    ./vscode.nix
    ./firefox.nix
  ];

  home.username = "migueltaibo";
  home.homeDirectory = "/home/migueltaibo";
  home.stateVersion = "25.11";

  programs.git = {
    enable = true;
    settings = {
      user.name = "Miguel Taibo";
      user.email = "miguel.taibo@icloud.com";
      init.defaultBranch = "main";
    };
  };

  programs.gh = {
    enable = true;
  };
  xdg.configFile."gh/config.yml".force = true;

  gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  home.file.".config/kitty".source = ./dotfiles/kitty;
  home.file.".config/starship.toml".source = ./dotfiles/starship.toml;
  home.file.".config/zsh/.zshrc".source = ./dotfiles/zsh/.zshrc;
  home.file.".config/hypr" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = ./dotfiles/hypr;
  };
  home.file.".config/opencode/config.json".text = builtins.toJSON {
    provider = "ollama";
    model = "qwen2.5-coder:14b";
    ollama.host = "http://localhost:11434";
  };

  xdg.userDirs = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
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
