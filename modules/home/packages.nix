{ pkgs, lib, pkgsUnstable, ... }: {
  home.packages = with pkgs; [
    eza
    bat
    fastfetch
    pkgs.opencode
    pkgsUnstable.claude-code
    nodejs_22
    ocaml
    opam
    jdk21
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    kitty
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    bibata-cursors
    grim
    slurp
  ];
}