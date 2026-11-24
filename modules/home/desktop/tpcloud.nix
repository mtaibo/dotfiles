{
  # SUPER+T: the terminal app of the tpcloud binary installed from
  # tpcloud.migueltaibo.com/get (in /usr/local/bin, outside Nix).
  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, T, Abrir TPCloud, exec, kitty --class tpcloud -e /usr/local/bin/tpcloud"
  ];
  dotfiles.english."Abrir TPCloud" = "Open TPCloud";
}
