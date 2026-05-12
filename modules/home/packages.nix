{ pkgs, ... }: {
  home.packages = with pkgs; [
    eza
    bat
    fastfetch
    opencode
    bibata-cursors
    grim
    slurp
  ];
}
