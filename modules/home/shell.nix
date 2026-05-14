{ pkgs, ... }: {
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      update = if pkgs.stdenv.hostPlatform.isDarwin
        then "sudo darwin-rebuild switch --flake ~/Dotfiles#macbook"
        else "sudo nixos-rebuild switch --flake ~/dotfiles#nixos";
      close = "curl -X POST http://192.168.1.160/api/commands/B0301/down";
    };

    initContent = ''
      fastfetch --pipe false
      source ~/.config/zsh/.zshrc
    '';
  };
}
