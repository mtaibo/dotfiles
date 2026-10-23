{ pkgs, ... }: {
  programs.starship.enable = true;

  home.packages = [
    pkgs.tmux
    (pkgs.writeShellScriptBin "crc" ''
      set -euo pipefail

      if [ "''${1:-}" = "--close" ]; then
        sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^crc-' || true)
        if [ -z "$sessions" ]; then
          echo "crc: no background sessions running"
          exit 0
        fi
        echo "$sessions" | while IFS= read -r session; do
          tmux kill-session -t "$session"
          echo "crc: closed $session"
        done
        exit 0
      fi

      session="crc-$(date +%s)-$$"
      tmux new-session -d -s "$session" -- claude "$@"
      echo "crc: running in background (tmux session: $session)"
      echo "crc: attach with: tmux attach -t $session"
      echo "crc: close all with: crc --close"
    '')
  ];

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
      if command -v opam &>/dev/null && [ -f "$HOME/.opam/config" ]; then
        eval $(opam env)
      fi
    '';
  };
}
