{ pkgs, lib, pkgsUnstable, ... }: {
  home.packages = with pkgs; [
    kitty
    eza
    bat
    fastfetch
    pkgs.opencode
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    bibata-cursors
    grim
    slurp
  ];
}