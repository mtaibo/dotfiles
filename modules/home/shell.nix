{ pkgs, ... }: {
  programs.starship.enable = true;

  home.file.".hushlogin".text = "";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      update = if pkgs.stdenv.hostPlatform.isDarwin
        then "sudo darwin-rebuild switch --flake ~/Dotfiles#macbook"
        else "sudo nixos-rebuild switch --flake ~/dotfiles#desktop";
      close = "curl -s -X POST http://192.168.1.160/api/commands/B0301/down > /dev/null";
      icloud = "cd ~/Library/Mobile\\ Documents/com\\~apple\\~CloudDocs";
      mount-storage = if pkgs.stdenv.hostPlatform.isDarwin
        then "mkdir -p ~/Storage && mount_smbfs //tp.home/storage ~/Storage"
        else "mkdir -p ~/storage && sudo mount.cifs //tp.home/storage ~/storage -o username=migueltaibo,uid=$(id -u),gid=$(id -g)";
      open = if pkgs.stdenv.hostPlatform.isDarwin
        then "open"
        else "setsid xdg-open";
    };

    initContent = ''
      fastfetch --pipe false
      source ~/.config/zsh/.zshrc
      eval $(opam env)
    '';
  };
}
