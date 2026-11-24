{ pkgs, ... }:
let
  # Opens the GTA V collectibles map in ~/workspace/achievement-guide (not part of this repo) after
  # reading the latest save, so what's done in game shows up already marked.
  # It also leaves `sync-save.js --watch` running in the background (once):
  # it re-reads the save every time the game writes it, and the open map
  # reloads progress.js on its own, so it follows the game live. A watcher
  # started before sync-save.js last changed runs the old code, so it's
  # restarted.
  # It opens the file directly: the map keeps its marks in the browser under
  # the file:// origin, so a local server would start from scratch.
  guide = pkgs.writeShellApplication {
    name = "guide";
    runtimeInputs = [ pkgs.nodejs pkgs.xdg-utils pkgs.procps pkgs.coreutils ];
    text = ''
      dir="$HOME/workspace/achievement-guide"
      [ -f "$dir/index.html" ] || { echo "guide: no encuentro $dir/index.html" >&2; exit 1; }
      running=
      for pid in $(pgrep -f "sync-save.js --watch" || true); do
        started=$(( $(date +%s) - $(ps -o etimes= -p "$pid") ))
        if [ "$(stat -c %Y "$dir/sync-save.js")" -gt "$started" ]; then
          kill "$pid"
        else
          running=1
        fi
      done
      if [ -z "$running" ]; then
        node "$dir/sync-save.js" || echo "guide: no se pudo leer la partida, abro el mapa igualmente" >&2
        log="''${XDG_STATE_HOME:-$HOME/.local/state}/guide.log"
        mkdir -p "$(dirname "$log")"
        setsid node "$dir/sync-save.js" --watch >"$log" 2>&1 &
      fi
      setsid xdg-open "$dir/index.html" >/dev/null 2>&1 &
    '';
  };
in {
  home.packages = [ guide ];
}
