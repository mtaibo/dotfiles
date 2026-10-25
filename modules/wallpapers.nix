# The wallpapers SUPER+W cycles through (modules/home/desktop/wallpaper.nix).
# Mostly dark, low-colour pictures that ship in nixpkgs (KDE Plasma, GNOME and
# NixOS artwork, all freely licensed), plus my own picks in assets/wallpapers/.
# `default` is what Stylix, the lock screen and the login screen fall back to.
pkgs:
let
  kde = name: file: "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/${name}/contents/${file}";

  # swww can't decode JPEG XL, so GNOME's wallpapers are converted once at build time.
  fromJxl = name: src: pkgs.runCommandLocal "${name}.png" { } ''
    ${pkgs.imagemagick}/bin/magick ${src} $out
  '';

  images = {
    "mountain.png" = kde "Mountain" "images_dark/5120x2880.png";
    "darkest-hour.jpg" = kde "DarkestHour" "images/2560x1440.jpg";
    "forest-path.jpg" = kde "Path" "images/2560x1440.jpg";
    "curvy.png" = fromJxl "curvy" "${pkgs.gnome-backgrounds}/share/backgrounds/gnome/curvy-d.jxl";
    "nineish-dark-gray.png" = pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath;
    "lake.jpg" = ../assets/wallpapers/lake.jpg;
    "hollow-knight-cliffs.jpg" = ../assets/wallpapers/hollow-knight-cliffs.jpg;
    "hollow-knight-city.jpg" = ../assets/wallpapers/hollow-knight-city.jpg;
    "hollow-knight-nail.jpg" = ../assets/wallpapers/hollow-knight-nail.jpg;
    "hollow-knight-pharloom.jpg" = ../assets/wallpapers/hollow-knight-pharloom.jpg;
    "hollow-knight-garden.jpg" = ../assets/wallpapers/hollow-knight-garden.jpg;
  };
in {
  default = images."mountain.png";

  # Symlink to the wallpaper in use. It lives outside $HOME (which is 0700) so
  # the SDDM greeter, running as its own user, can read it too.
  current = "/var/lib/wallpaper/current";

  collection = pkgs.linkFarm "wallpapers"
    (pkgs.lib.mapAttrsToList (name: path: { inherit name path; }) images);

  # 500 px tall previews for the picker carousel, made once at build time so
  # it doesn't decode 5K images every time it opens. Named after the
  # wallpaper minus its extension: thumbnails/mountain.jpg is the preview of
  # mountain.png.
  thumbnails = pkgs.runCommandLocal "wallpaper-thumbnails" { } ''
    mkdir $out
    ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (name: path: ''
      ${pkgs.imagemagick}/bin/magick ${path} -thumbnail x500 -strip -quality 85 $out/${pkgs.lib.removeSuffix ".png" (pkgs.lib.removeSuffix ".jpg" name)}.jpg
    '') images)}
  '';
}
