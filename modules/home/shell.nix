{ pkgs, lib, ... }: {
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
      # remote-control (not plain claude) is what shows up in the Claude app.
      # The pane stays after an early exit so its error can be shown here.
      tmux new-session -d -s "$session" -- claude remote-control "$@"
      tmux set-option -t "$session" remain-on-exit on
      sleep 3
      if [ "$(tmux display-message -p -t "$session" '#{pane_dead}')" = 1 ]; then
        tmux capture-pane -p -J -S - -t "$session" | grep -v -e '^$' -e '^Pane is dead' || true
        tmux kill-session -t "$session"
        echo "crc: claude remote-control exited, nothing left running"
        exit 1
      fi
      tmux set-option -t "$session" remain-on-exit off
      if tmux capture-pane -p -J -t "$session" | grep -q 'Trust .*?'; then
        echo "crc: this folder isn't trusted yet; attach, answer y, then detach (Ctrl+B D)"
      fi
      echo "crc: running in background (tmux session: $session)"
      echo "crc: attach with: tmux attach -t $session"
      echo "crc: close all with: crc --close"
    '')
    (let
      dir = if pkgs.stdenv.hostPlatform.isDarwin
        then "$HOME/Workspace/udc-ec"
        else "$HOME/workspace/udc-ec";
    in pkgs.writeShellScriptBin "simula" ''
      set -euo pipefail

      if [ "''${1:-}" = "--close" ]; then
        sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^simula-' || true)
        if [ -z "$sessions" ]; then
          echo "simula: no sessions running"
          exit 0
        fi
        echo "$sessions" | while IFS= read -r session; do
          tmux kill-session -t "$session"
          echo "simula: closed $session"
        done
        exit 0
      fi

      # One tmux session per window. The session's only command is the jar, so
      # closing the Simula window ends java and tmux drops the session with it.
      session="simula-$(date +%s)-$$"
      tmux new-session -d -s "$session" -c "${dir}" -- ${pkgs.jdk21}/bin/java -jar "${dir}/Simula3MSv4_13.jar"
      sleep 2
      if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "simula: Simula3MS exited right away (try: java -jar ${dir}/Simula3MSv4_13.jar)"
        exit 1
      fi
      echo "simula: opened (tmux session: $session)"
      echo "simula: close all with: simula --close"
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

    initContent = let
      # eza and ls in the terminal's accent colours only: ANSI blue, magenta and
      # cyan (which follow the wallpaper on the desktop, see wallpaper.nix) plus
      # greys. Red is left for the exceptional cases: broken links and deleted
      # or conflicted files in git. `reset` drops eza's built-in per-extension
      # colours; exported here because NixOS's /etc/zshrc runs dircolors first.
      lsColors = "di=1;34:ln=36:or=31:ex=1;35:pi=35:so=35:bd=35:cd=35";
      ezaColors = lib.concatStringsSep ":" [
        "reset"
        lsColors
        "fi=0:mp=1;34:sp=35:lp=36:cc=36"
        # permissions: read / write / execute in the three accent tones
        "ur=34:uw=35:ux=36:ue=36:gr=34:gw=35:gx=36:tr=34:tw=35:tx=36"
        "su=35:sf=35:xa=90:oc=34"
        # size in white with grey units, then owner, links, dates, chrome
        "sn=37:sb=90:df=37:ds=90"
        "uu=34:uR=35:un=90:gu=34:gR=35:gn=90"
        "lc=90:lm=36:da=90:xx=90:hd=4;90"
        # git column and branch
        "ga=36:gm=34:gd=31:gv=35:gt=35:gi=90:gc=31"
        "Gm=34:Go=35:Gc=36:Gd=35"
        # file kinds
        "im=35:vi=35:mu=35:lo=35:cr=36:do=37:co=35:tm=90:cm=90:bu=1;36:sc=0"
      ];
    in ''
      export LS_COLORS='${lsColors}'
      export EZA_COLORS='${ezaColors}'

      # The image logo needs kitty itself, not tmux. Locally fastfetch passes
      # kitty the file path (kitty-direct); over SSH the file isn't on kitty's
      # machine, so the `kitty` type sends the pixels through the terminal.
      # A function so typing `fastfetch` later picks the same logo, and the
      # English labels when the desktop's system language is (language.nix).
      fastfetch() {
        local lang=()
        if [ "$(cat "''${XDG_RUNTIME_DIR:-/nonexistent}/system-language" 2>/dev/null)" = en ]; then
          lang=(--config ~/.config/fastfetch/config-en.jsonc)
        fi
        if [ "$TERM" = xterm-kitty ] && [ -z "$TMUX" ] && [ -z "$SSH_CONNECTION" ]; then
          command fastfetch "''${lang[@]}" --pipe false "$@"
        ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        elif [ "$TERM" = xterm-kitty ] && [ -z "$TMUX" ]; then
          command fastfetch "''${lang[@]}" --pipe false --logo-type kitty "$@"
        ''}else
          command fastfetch "''${lang[@]}" --pipe false --logo-type builtin --logo ${if pkgs.stdenv.hostPlatform.isDarwin
            then "macos_small"
            else ''"$([ -e /etc/NIXOS ] && echo NixOS_small || echo raspbian_small)"''} "$@"
        fi
      }
      fastfetch
      source ~/.config/zsh/.zshrc
      if command -v opam &>/dev/null && [ -f "$HOME/.opam/config" ]; then
        eval $(opam env)
      fi
    '';
  };
}
