{ pkgs, lib, ... }: {
  imports = [
    ../../modules/home/shell.nix
    ../../modules/home/editors/nvim.nix
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

  programs.gh.enable = true;

  home.packages = with pkgs; [
    eza
    bat
    fastfetch
    pkgs.opencode
  ];

  home.file.".config/opencode/opencode.json".source = ../../assets/opencode/opencode.json;
  home.file.".config/starship.toml".source = ../../assets/starship/starship.toml;
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;

  programs.zsh.shellAliases = {
    dotfiles = "home-manager switch --flake ~/dotfiles#tphome";
    update = lib.mkForce "echo 'on rpi use: dotfiles (not update)'";
  };

  programs.home-manager.enable = true;

  home.activation.setupKittyTerminfo = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p "$HOME/.terminfo/x"
    $DRY_RUN_CMD ${pkgs.ncurses}/bin/tic -x -o "$HOME/.terminfo" ${../../assets/kitty/xterm-kitty.terminfo}
  '';
}
