{ pkgs, lib, ... }: {
  imports = [ ../../modules/home ];
  home.username = lib.mkForce "migueltaibo";
  home.homeDirectory = lib.mkForce "/Users/migueltaibo";

  nixpkgs.config.allowUnfree = true;

  home.file = builtins.listToAttrs (map
    (name: {
      name = "/Library/Fonts/${name}";
      value.source = "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/${name}";
    })
    [
      "FiraCodeNerdFont-Regular.ttf"
      "FiraCodeNerdFont-Bold.ttf"
      "FiraCodeNerdFont-Medium.ttf"
      "FiraCodeNerdFont-Retina.ttf"
      "FiraCodeNerdFont-SemiBold.ttf"
      "FiraCodeNerdFont-Light.ttf"
    ]);
}
