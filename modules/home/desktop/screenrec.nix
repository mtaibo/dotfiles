{ config, pkgs, ... }:
let
  pidFile = "\"$XDG_RUNTIME_DIR/screen-record.pid\"";
  lastFile = "\"$XDG_RUNTIME_DIR/screen-record.last\"";
  c = config.lib.stylix.colors;

  # SUPER+J starts recording the focused screen and again stops it, saving an
  # mp4 in ~/downloads. wf-recorder runs in the background; stopping it with
  # SIGINT lets it finish the file before the notification says it's saved.
  # The bar's red dot (waybar.nix) follows the pid file.
  screenRecord = pkgs.writeShellApplication {
    name = "screen-record";
    runtimeInputs = with pkgs; [ wf-recorder jq coreutils procps libnotify hyprland ];
    text = ''
      en=$([ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ] && echo 1 || true)
      refresh() { pkill -RTMIN+11 -x .waybar-wrapped || true; }

      pid=$(cat ${pidFile} 2>/dev/null || true)
      if [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = wf-recorder ]; then
        kill -INT "$pid"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        rm -f ${pidFile}
        refresh
        notify-send -i media-record "$([ -n "$en" ] && echo "Recording saved" || echo "Grabación guardada")" \
          "$(cat ${lastFile})"
        exit 0
      fi

      file="$HOME/downloads/$([ -n "$en" ] && echo recording || echo grabacion)-$(date +%F_%H-%M-%S).mp4"
      output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
      echo "$file" > ${lastFile}
      setsid wf-recorder -o "$output" -f "$file" >/dev/null 2>&1 &
      echo $! > ${pidFile}
      refresh
    '';
  };

  # The red dot: shown while recording, nothing (so the island hides) otherwise.
  indicator = pkgs.writeShellApplication {
    name = "waybar-recording";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      pid=$(cat ${pidFile} 2>/dev/null || true)
      if [ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = wf-recorder ]; then
        tip=$([ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ] && echo "Recording · SUPER+J to stop" || echo "Grabando · SUPER+J para parar")
        printf '{"text":"●","class":"recording","tooltip":"%s"}\n' "$tip"
      else
        echo '{"text":""}'
      fi
    '';
  };
in {
  home.packages = [ screenRecord ];

  programs.waybar.settings.main = {
    "custom/recording" = {
      exec = "${indicator}/bin/waybar-recording";
      return-type = "json";
      interval = "once";
      signal = 11;
    };
  };

  programs.waybar.style = ''
    #custom-recording {
      background: alpha(@island, 0.75);
      border-radius: ${toString (config.wayland.windowManager.hyprland.settings.decoration.rounding + 6)}px;
      padding: 12px 20px;
      margin-left: 5px;
      color: ${c.withHashtag.base08};
    }
  '';

  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, J, Grabar la pantalla (otra vez para parar), exec, screen-record"
  ];
  dotfiles.english."Grabar la pantalla (otra vez para parar)" = "Record the screen (again to stop)";
}
