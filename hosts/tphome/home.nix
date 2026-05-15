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

  home.file.".hushlogin".text = "";
  home.file.".config/opencode/opencode.json".source = ../../assets/opencode/opencode.json;
  home.file.".config/starship.toml".source = ../../assets/starship/starship.toml;
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;

  programs.zsh.shellAliases = {
    update = lib.mkForce "home-manager switch --flake ~/dotfiles#tphome";
  };

  programs.home-manager.enable = true;

  home.activation.setupKittyTerminfo = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p "$HOME/.terminfo/x"
    $DRY_RUN_CMD ${pkgs.ncurses}/bin/tic -x -o "$HOME/.terminfo" ${../../assets/kitty/xterm-kitty.terminfo}
  '';

  home.activation.setupSshKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.ssh"
    $DRY_RUN_CMD curl -fsSL https://github.com/mtaibo.keys -o "$HOME/.ssh/authorized_keys"
    $DRY_RUN_CMD chmod 600 "$HOME/.ssh/authorized_keys"
  '';

  home.activation.suppressMotd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD sudo -n bash -c 'printf "PrintMotd no\n" > /etc/ssh/sshd_config.d/99-no-motd.conf' 2>/dev/null || true
    $DRY_RUN_CMD sudo -n truncate -s 0 /etc/motd 2>/dev/null || true
  '';
}
