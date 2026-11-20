{ pkgs, ... }:
let
  # Opens the GTA V collectibles map in ~/gta (not part of this repo) after
  # reading the latest save, so what's done in game shows up already marked.
  # It opens the file directly: the map keeps its marks in the browser under
  # the file:// origin, so a local server would start from scratch.
  gta-map = pkgs.writeShellApplication {
    name = "gta-map";
    runtimeInputs = [ pkgs.nodejs pkgs.xdg-utils ];
    text = ''
      dir="$HOME/gta"
      [ -f "$dir/index.html" ] || { echo "gta-map: no encuentro $dir/index.html" >&2; exit 1; }
      node "$dir/sync-save.js" || echo "gta-map: no se pudo leer la partida, abro el mapa igualmente" >&2
      setsid xdg-open "$dir/index.html" >/dev/null 2>&1 &
    '';
  };
in {
  home.packages = [ gta-map ];
}
