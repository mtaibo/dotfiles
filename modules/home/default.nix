{ pkgs, lib, ... }: {
  imports = [
    ./shell.nix
    ./packages.nix
    ./editors/nvim.nix
    ./editors/vscode.nix
    ./browsers/firefox.nix
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
  home.file.".config/kitty".source = if pkgs.stdenv.hostPlatform.isLinux
    then ../../assets/kitty-linux
    else ../../assets/kitty;
  home.file.".config/opencode/opencode.json" = {
    source = ../../assets/opencode/opencode.json;
    force = true;
  };
  home.file.".config/starship.toml".source = ../../assets/starship/starship.toml;
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;
  home.file.".config/fastfetch/config.jsonc".source = ../../assets/fastfetch/config.jsonc;
  home.file.".config/hypr" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = ../../assets/hypr;
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