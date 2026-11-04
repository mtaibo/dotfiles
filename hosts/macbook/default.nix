{ pkgs, inputs, ... }:
let
  androidSdk = (pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "35" ];
    buildToolsVersions = [ "35.0.0" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "arm64-v8a" ];
  }).androidsdk;
  # Apple's SF Mono with Fira Code's ligatures and Nerd Font icons. Every glyph
  # is one cell wide but the font doesn't say so, and kitty only sees fonts macOS
  # reports as monospaced, so it would fall back to Menlo without this flag.
  sfMonoLiga = pkgs.runCommand "sf-mono-liga" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
  } ''
    mkdir -p $out/share/fonts/opentype
    python3 - ${inputs.sf-mono-liga}/*.otf <<EOF
    import os, sys
    from fontTools.ttLib import TTFont
    for path in sys.argv[1:]:
        font = TTFont(path)
        font["post"].isFixedPitch = 1
        font["CFF "].cff.topDictIndex[0].isFixedPitch = 1
        font.save(os.path.join("$out/share/fonts/opentype", os.path.basename(path)))
    EOF
  '';
in {
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;

  networking.hostName = "macbook";

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.android_sdk.accept_license = true;
  nixpkgs.config.permittedInsecurePackages = [
    "lima-full-1.2.2"
    "lima-additional-guestagents-1.2.2"
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    sfMonoLiga
  ];

  # `crc` turns lid sleep off and on without a password prompt.
  security.sudo.extraConfig = ''
    migueltaibo ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1
  '';

  imports = [ ../../modules/darwin/batt.nix ];

  environment.systemPackages = with pkgs; [
    git
    gh
    colima
    docker-client
    xcodegen
    androidSdk
  ];

  environment.variables.ANDROID_HOME = "${androidSdk}/libexec/android-sdk";

}
