{ ... }: {
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake .#nixos";
      conf = "nvim ~/Workspace/dotfiles/hosts/desktop/default.nix";
      hconf = "nvim ~/Workspace/dotfiles/modules/home/default.nix";
    };

    initContent = ''
      fastfetch
      eval "$(starship init zsh)"
    '';
  };
}
