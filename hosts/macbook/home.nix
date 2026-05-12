{ lib, ... }: {
  imports = [ ../../modules/home ];
  home.username = lib.mkForce "migueltaibo";
  home.homeDirectory = lib.mkForce "/Users/migueltaibo";

  nixpkgs.config.allowUnfree = true;
}
