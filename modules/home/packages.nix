{ pkgs, lib, pkgsUnstable, ... }: {
  home.packages = with pkgs; [
    eza
    bat
    unzip
    zip
    pkgs.opencode
    pkgsUnstable.claude-code
    nodejs_22
    ocaml
    opam
    jdk21
    maven
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    kitty
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    # C from any terminal, not only inside Neovim (the Mac has Xcode's).
    gcc
    gnumake
    # Memory leak checks (Linux only: it doesn't run on Apple Silicon).
    valgrind
    bibata-cursors
    grim
    slurp
  ];
}