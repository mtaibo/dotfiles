{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    kitty
    eza
    bat
    fastfetch
    opencode
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    bibata-cursors
    grim
    slurp
  ];
}
