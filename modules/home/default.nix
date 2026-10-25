{ pkgs, lib, ... }: {
  imports = [
    ./shell.nix
    ./starship.nix
    ./packages.nix
    ./fastfetch.nix
    ./editors/nvim.nix
    ./editors/vscode.nix
    ./browsers/firefox.nix
  ];
  home.username = lib.mkDefault "migueltaibo";
  home.homeDirectory = lib.mkDefault "/home/migueltaibo";
  home.stateVersion = "25.11";
  programs.git = {
    enable = true;
    settings = {
      user.name = "Miguel Taibo";
      user.email = "dev@migueltaibo.com";
      init.defaultBranch = "main";
    };
  };
  programs.gh = {
    enable = true;
  };
  xdg.configFile."gh/config.yml".force = true;
  home.file.".config/kitty" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = ../../assets/kitty;
  };
  home.file.".config/opencode/opencode.json" = {
    source = ../../assets/opencode/opencode.json;
    force = true;
  };
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;
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
  manual.html.enable = false;
  manual.json.enable = false;
  manual.manpages.enable = false;
}