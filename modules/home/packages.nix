{ pkgs, lib, pkgsUnstable, ... }: {
  home.packages = with pkgs; [
    kitty
    eza
    bat
    fastfetch
    pkgsUnstable.claude-code
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    bibata-cursors
    grim
    slurp
  ];
}