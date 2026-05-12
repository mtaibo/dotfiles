{ pkgs, ... }: {
  home.packages = with pkgs; [
    eza
    bat
    fastfetch
    opencode
    grim
    slurp
  ];
}
