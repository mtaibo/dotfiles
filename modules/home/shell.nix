{ ... }: {
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      update = "sudo nixos-rebuild switch --flake .#nixos";
    };

    initExtra = ''
      fastfetch --pipe false
      source ~/.config/zsh/.zshrc
    '';
  };
}
