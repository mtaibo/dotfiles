{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";
  dir = "${config.xdg.configHome}/eww";
  colors = "${dir}/colors.scss";
  # Same corners as the bar's islands.
  radius = config.wayland.windowManager.hyprland.settings.decoration.rounding + 6;
  width = 380;
  art = 84;
  defaultColors = pkgs.writeText "eww-colors.scss" ''
    $accent: ${c.withHashtag.base0D};
    $text: ${c.withHashtag.base05};
    $muted: ${c.withHashtag.base03};
  '';

  # Written by the Cider launcher (see cider.nix).
  ciderToken = "${config.xdg.configHome}/cider/api-token";

  # What's playing, as JSON for the popup, polled while it's open. For Cider
  # everything comes from its local API: its MPRIS length grows with its
  # seamless transitions on (it counts what's buffered of the next song), and
  # after a skip its MPRIS metadata can stay empty. Other players go through
  # MPRIS, whose times are in microseconds. Artwork URLs are downloaded once
  # into a cache; chromium hands a local file.
  info = pkgs.writeShellApplication {
    name = "media-info";
    runtimeInputs = with pkgs; [ playerctl jq curl coreutils ];
    text = ''
      if ! status=$(playerctl status 2>/dev/null); then
        echo '{"status":"None","title":"","artist":"","art":"","pos":"0:00","len":"0:00","percent":0}'
        exit 0
      fi

      # Fields are split on the unit separator: unlike tabs, empty ones
      # don't collapse and shift the rest.
      sep=$'\x1f'
      if [ "$(playerctl metadata --format '{{ playerName }}' 2>/dev/null)" = chromium ] \
        && [ -s ${ciderToken} ] \
        && now=$(curl -sf -m 1 -H "apptoken: $(cat ${ciderToken})" \
          http://127.0.0.1:10767/api/v1/playback/now-playing) \
        && fields=$(jq -er --arg sep "$sep" '.info | select(.name != null) | [
            .name, (.artistName // ""), (.artwork.url // ""),
            ((.durationInMillis // 0) / 1000 | floor), ((.currentPlaybackTime // 0) | floor)
          ] | map(tostring) | join($sep)' <<< "$now"); then
        IFS=$sep read -r title artist art len pos <<< "$fields"
      else
        IFS=$sep read -r title artist art len pos < <(playerctl metadata --format \
          "{{ title }}$sep{{ artist }}$sep{{ mpris:artUrl }}$sep{{ mpris:length }}$sep{{ position }}" \
          2>/dev/null) || true
        len=$(( ''${len:-0} / 1000000 )); pos=$(( ''${pos:-0} / 1000000 ))
      fi
      # Players without a track report the largest possible length.
      [ "''${len:-0}" -lt 86400 ] || len=0

      case "''${art:-}" in
        file://*) art=''${art#file://} ;;
        http*)
          cache=''${XDG_CACHE_HOME:-$HOME/.cache}/media-art
          mkdir -p "$cache"
          file="$cache/$(printf '%s' "$art" | md5sum | cut -c1-16)"
          [ -s "$file" ] || curl -sfL "$art" -o "$file" || true
          art=$file ;;
        *) art="" ;;
      esac

      mmss() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
      jq -cn --arg status "$status" --arg title "''${title:-}" --arg artist "''${artist:-}" \
        --arg art "$art" --arg pos "$(mmss "''${pos:-0}")" --arg len "$(mmss "''${len:-0}")" \
        --argjson percent "$(( ''${len:-0} > 0 ? ''${pos:-0} * 100 / len : 0 ))" \
        '{$status, $title, $artist, $art, $pos, $len, $percent}'
    '';
  };

  # Click the player island: open the popup centred under the click (the
  # cursor is on the island), or close it if it's already open. A clear
  # window behind it, covering the screen and the bar, closes it on a click
  # anywhere else.
  popup = pkgs.writeShellApplication {
    name = "media-popup";
    runtimeInputs = with pkgs; [ eww hyprland coreutils gnugrep ];
    text = ''
      close() { eww close media media-closer >/dev/null 2>&1 || true; eww update media_open=false; }
      if [ "''${1:-}" = close ] || eww active-windows 2>/dev/null | grep -q '^media:'; then
        close
        exit 0
      fi
      bluetooth-popup close
      audio-popup close
      x=$(hyprctl cursorpos | cut -d, -f1)
      x=$(( x - ${toString (width / 2)} ))
      [ "$x" -ge 10 ] || x=10
      eww update media_open=true
      eww open media-closer
      eww open media --pos "''${x}x6"
    '';
  };
in {
  home.packages = [ pkgs.eww popup info ];

  xdg.configFile."eww/eww.yuck".text = ''
    (defvar media_open false)
    (defpoll media :interval "1s" :run-while media_open :initial "{}"
      "${info}/bin/media-info")
    ; es or en, the system language (language.nix).
    (defpoll lang :interval "2s" :run-while media_open :initial "es"
      "[ \"$(cat \"$XDG_RUNTIME_DIR/system-language\" 2>/dev/null)\" = en ] && echo en || echo es")

    (defwindow media
      :monitor 0
      :geometry (geometry :x "0px" :y "6px" :width "${toString width}px" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-media"
      :exclusive false
      :focusable false
      (media))

    ; Covers the whole screen, the bar included: layer surfaces start below
    ; the bar's reserved space, so it starts well above the top edge.
    (defwindow media-closer
      :monitor 0
      :geometry (geometry :x "0px" :y "-100px" :width "100%" :height "200%" :anchor "top left")
      :stacking "overlay"
      :namespace "eww-closer"
      :exclusive false
      :focusable false
      (eventbox :onclick "${popup}/bin/media-popup close" (box)))

    (defwidget media []
      (box :class "media" :orientation "v" :space-evenly false :spacing 12
        (box :orientation "h" :space-evenly false :spacing 16
          (box :class "art ''${media.art == "" ? "empty" : ""}" :valign "center"
            :width ${toString art} :height ${toString art}
            :style "''${media.art == "" ? "" : "background-image: url('" + media.art + "');"}"
            (label :class "art-icon" :visible {media.art == ""} :text "󰝚"))
          (box :orientation "v" :space-evenly false :spacing 2 :valign "center" :hexpand true
            (label :class "title" :xalign 0 :text {media.status == "None" ? (lang == "en" ? "Nothing playing" : "Nada sonando") : media.title}
              :limit-width 28 :show-truncated true)
            (label :class "artist" :xalign 0 :text {media.artist ?: ""} :limit-width 32
              :show-truncated true :visible {(media.artist ?: "") != ""})
            (box :class "controls" :halign "start" :space-evenly false :spacing 18
              (button :onclick "${pkgs.playerctl}/bin/playerctl previous" "󰒮")
              (button :class "play" :onclick "${pkgs.playerctl}/bin/playerctl play-pause"
                {media.status == "Playing" ? "󰏤" : "󰐊"})
              (button :onclick "${pkgs.playerctl}/bin/playerctl next" "󰒭"))))
        (box :orientation "v" :space-evenly false :spacing 6
          (progress :class "progress" :value {media.percent ?: 0} :orientation "h")
          (box :class "times"
            (label :class "time" :halign "start" :text {media.pos ?: "0:00"})
            (label :class "time" :halign "end" :text {media.len ?: "0:00"})))))
  '';

  xdg.configFile."eww/eww.scss".text = ''
    @import "colors";

    * {
      all: unset;
      font-family: "JetBrainsMono Nerd Font Propo";
      font-weight: bold;
    }

    // Both windows are clear; only the popup's box is painted.
    window {
      background-color: transparent;
    }

    // Glass like the bar: Stylix's background, blurred by Hyprland.
    .media {
      background-color: rgba(${rgb "base00"}, 0.75);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: ${toString radius}px;
      padding: 16px 18px 12px 16px;
      color: $text;
    }

    .art {
      border-radius: ${toString (radius - 6)}px;
      background-size: cover;
      background-position: center;
    }

    .art.empty {
      background-color: rgba(255, 255, 255, 0.06);
    }

    .art-icon {
      font-size: 32px;
      color: $muted;
    }

    .title {
      font-size: 15px;
      color: ${c.withHashtag.base07};
    }

    .artist {
      font-size: 13px;
      color: $muted;
    }

    .controls {
      margin-top: 6px;
    }

    .controls button {
      font-size: 18px;
      color: ${c.withHashtag.base05};
    }

    .controls button:hover {
      color: $accent;
    }

    .controls .play {
      font-size: 22px;
      color: $accent;
    }

    .progress trough {
      min-height: 4px;
      border-radius: 2px;
      background-color: rgba(255, 255, 255, 0.12);
    }

    .progress progress {
      min-height: 4px;
      border-radius: 2px;
      background-color: $accent;
    }

    .time {
      font-size: 11px;
      color: $muted;
    }
  '';

  # The accent and greys come from the wallpaper (matugen, see wallpaper.nix);
  # Stylix's stand in until the first wallpaper is set.
  home.activation.ewwColorsDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! grep -qs "^\$accent" ${colors}; then
      run mkdir -p ${dir}
      run install -m 644 ${defaultColors} ${colors}
    fi
  '';

  # A running daemon makes the popup open instantly.
  systemd.user.services.eww = {
    Unit = {
      Description = "eww widgets daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.eww}/bin/eww daemon --no-daemonize";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  wayland.windowManager.hyprland.settings.layerrule = [
    "blur, eww-media"
    "ignorezero, eww-media"
  ];
}
