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
    docker-compose
    pkgs.opencode
    pkgs.dnsmasq
  ];

  home.file.".hushlogin".text = "";
  home.file.".config/opencode/opencode.json".source = ../../assets/opencode/opencode.json;
  home.file.".config/starship.toml".source = ../../assets/starship/starship.toml;
  home.file.".config/zsh/.zshrc".source = ../../assets/zsh/.zshrc;

  programs.zsh.shellAliases = {
    update       = lib.mkForce "home-manager switch --flake ~/dotfiles#tphome";
    tphome-up    = "~/dotfiles/scripts/tphome-docker.sh up";
    tphome-down  = "~/dotfiles/scripts/tphome-docker.sh down";
    tphome-logs  = "~/dotfiles/scripts/tphome-docker.sh logs";
    tphome-ps    = "~/dotfiles/scripts/tphome-docker.sh ps";
    tphome-rebuild = "~/dotfiles/scripts/tphome-docker.sh rebuild";
  };

  programs.home-manager.enable = true;

  home.activation.setupKittyTerminfo = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mkdir -p "$HOME/.terminfo/x"
    $DRY_RUN_CMD ${pkgs.ncurses}/bin/tic -x -o "$HOME/.terminfo" ${../../assets/kitty/xterm-kitty.terminfo}
  '';

  home.activation.setupSshKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.ssh"
    $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://github.com/mtaibo.keys -o "$HOME/.ssh/authorized_keys"
    $DRY_RUN_CMD chmod 600 "$HOME/.ssh/authorized_keys"
  '';

  home.activation.suppressMotd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD sudo -n bash -c 'printf "PrintMotd no\n" > /etc/ssh/sshd_config.d/99-no-motd.conf' 2>/dev/null || true
    $DRY_RUN_CMD sudo -n truncate -s 0 /etc/motd 2>/dev/null || true
  '';

  home.activation.setupDnsmasq = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/bin/sudo bash -c '
    mkdir -p /etc/dnsmasq.d /run/dnsmasq
    ln -sf ${pkgs.dnsmasq}/bin/dnsmasq /usr/local/bin/dnsmasq
    printf "%s\n" \
      "interface=tailscale0" \
      "bind-interfaces" \
      "domain-needed" \
      "bogus-priv" \
      "no-hosts" \
      "no-resolv" \
      "server=1.1.1.1" \
      "server=8.8.8.8" \
      "address=/tp.home/100.117.91.125" > /etc/dnsmasq.d/tphome.conf
    printf "%s\n" \
      "[Unit]" \
      "Description=dnsmasq DNS forwarder" \
      "After=tailscaled.service network-online.target" \
      "Wants=network-online.target" \
      "" \
      "[Service]" \
      "Type=simple" \
      "ExecStartPre=/usr/local/bin/dnsmasq --test -C /etc/dnsmasq.d/tphome.conf" \
      "ExecStart=/usr/local/bin/dnsmasq -k -C /etc/dnsmasq.d/tphome.conf" \
      "ExecReload=/bin/kill -HUP \$MAINPID" \
      "Restart=on-failure" \
      "RestartSec=5" \
      "" \
      "[Install]" \
      "WantedBy=multi-user.target" > /etc/systemd/system/dnsmasq.service
    systemctl daemon-reload
    systemctl enable dnsmasq
    systemctl restart dnsmasq
    '
  '';
}
