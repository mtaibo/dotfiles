{ ... }: {
  imports = [
    ../../modules/home/shell.nix
    ../../modules/home/packages.nix
    ../../modules/home/editors/nvim.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.file.".config/kitty".source = ../../assets/kitty;
  home.file.".config/opencode/opencode.json".source = ../../assets/opencode/opencode.json;
  home.file.".config/starship.toml".source = ../../assets/starship/starship.toml;
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;
}
