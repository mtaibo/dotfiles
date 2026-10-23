{ config, lib, pkgs, ... }:
let
  walls = import ../../wallpapers.nix pkgs;
  c = config.lib.stylix.colors;
  rgb = name: "${c."${name}-rgb-r"}, ${c."${name}-rgb-g"}, ${c."${name}-rgb-b"}";

  # The picker, modelled on Hyprlust's rofi wallpaper menu: a wide glass
  # window with one row of five large previews, ". random" first. The accent
  # (selected border) comes from the wallpaper through matugen.
  pickerTheme = pkgs.writeText "wallpaper-picker.rasi" ''
    @import "${config.xdg.configHome}/rofi/matugen-colors.rasi"

    configuration {
      show-icons: true;
      hover-select: true;
      me-select-entry: "MouseSecondary";
      me-accept-entry: "MousePrimary";
      font: "${config.stylix.fonts.sansSerif.name} 12";
    }

    * {
      background-color: transparent;
      text-color: ${c.withHashtag.base05};
    }

    window {
      location: center;
      anchor: center;
      width: 75%;
      transparency: "real";
      border-radius: 16px;
      border: 1px;
      border-color: rgba(255, 255, 255, 0.08);
      background-color: rgba(${rgb "base00"}, 0.6);
    }

    mainbox {
      children: [ "inputbar", "listview" ];
    }

    inputbar {
      margin: 20px 36px 0 36px;
      padding: 10px 18px;
      border-radius: 999px;
      background-color: rgba(255, 255, 255, 0.08);
      children: [ "entry" ];
    }

    entry {
      placeholder: "Buscar fondo…";
      placeholder-color: rgba(255, 255, 255, 0.4);
    }

    listview {
      columns: 5;
      lines: 1;
      padding: 26px 36px;
      spacing: 20px;
      cycle: true;
      dynamic: true;
      scrollbar: false;
      layout: vertical;
      fixed-height: true;
      fixed-columns: true;
    }

    element {
      orientation: vertical;
      padding: 10px;
      spacing: 8px;
      border-radius: 12px;
      border: 2px;
      border-color: transparent;
      background-color: rgba(0, 0, 0, 0.2);
      cursor: pointer;
    }

    element selected.normal {
      background-color: rgba(255, 255, 255, 0.12);
      border-color: @accent;
    }

    element-icon {
      size: 280px;
      cursor: inherit;
    }

    element-text {
      horizontal-align: 0.5;
      cursor: inherit;
    }
  '';

  # wallpaper next|prev|random|pick|restore|set FILE
  # Draws with swww (a circle growing from the cursor), recolours the terminal
  # and the picker from the wallpaper with matugen, and records the choice in
  # ${walls.current}, which hyprlock and the login screen also read.
  wallpaper = pkgs.writeShellApplication {
    name = "wallpaper";
    runtimeInputs = with pkgs; [ swww coreutils findutils procps hyprland rofi matugen ];
    text = ''
      dir=${walls.collection}
      thumbs=${walls.thumbnails}
      current=${walls.current}

      list() { find -L "$dir" -maxdepth 1 -type f | sort; }

      # Compared by resolved path: the link may point into the collection or
      # straight at the image (the initial default does).
      active() { readlink -f "$current" 2>/dev/null || true; }

      show() {
        # Grow the new wallpaper out from wherever the cursor is.
        pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ' || echo 0,0)
        swww img "$1" \
          --transition-type grow --transition-pos "$pos" --invert-y \
          --transition-duration 1.2 --transition-fps 144
      }

      # Writes the accent colours for kitty and rofi, then makes every open
      # kitty window reload its config so they change right away.
      recolour() {
        matugen image "$1" --quiet
        pkill -USR1 -x .kitty-wrapped || true
      }

      set_wallpaper() {
        show "$1"
        ln -sfn "$1" "$current"
        recolour "$1"
      }

      step() {
        mapfile -t all < <(list)
        now=$(active)
        i=0
        for n in "''${!all[@]}"; do
          if [ "$(readlink -f "''${all[$n]}")" = "$now" ]; then i=$n; fi
        done
        set_wallpaper "''${all[$(( (i + $1 + ''${#all[@]}) % ''${#all[@]} ))]}"
      }

      others() {
        now=$(active)
        list | while read -r f; do
          if [ "$(readlink -f "$f")" != "$now" ]; then echo "$f"; fi
        done
      }

      name() { basename "''${1%.*}"; }

      pick() {
        random=$(others | shuf -n 1)
        choice=$(
          {
            printf '%s\0icon\x1f%s\n' ". random" "$thumbs/$(name "$random").jpg"
            list | while read -r f; do
              printf '%s\0icon\x1f%s\n' "$(name "$f")" "$thumbs/$(name "$f").jpg"
            done
          } | rofi -dmenu -i -p "" -theme ${pickerTheme}
        ) || exit 0
        case "$choice" in
          "") exit 0 ;;
          ". random") set_wallpaper "$random" ;;
          *) set_wallpaper "$(list | while read -r f; do
               if [ "$(name "$f")" = "$choice" ]; then echo "$f"; fi
             done)" ;;
        esac
      }

      case "''${1:-next}" in
        next) step 1 ;;
        prev) step -1 ;;
        random) set_wallpaper "$(others | shuf -n 1)" ;;
        pick) pick ;;
        restore)
          # Wait for the daemon, then put back the last choice without
          # animation and regenerate its colours (templates may have changed).
          until swww query >/dev/null 2>&1; do sleep 0.1; done
          f=$(active)
          if [ ! -e "$f" ]; then f=${walls.default}; fi
          swww img "$f" --transition-type none
          recolour "$f"
          ;;
        set) set_wallpaper "$(realpath "$2")" ;;
        *) echo "usage: wallpaper next|prev|random|pick|restore|set FILE" >&2; exit 1 ;;
      esac
    '';
  };
in {
  home.packages = [ wallpaper ];

  services.swww.enable = true;

  # Puts the remembered wallpaper back as soon as swww starts with the session.
  systemd.user.services.wallpaper-restore = {
    Unit = {
      Description = "Restore the last wallpaper";
      After = [ "swww.service" ];
      Requires = [ "swww.service" ];
      PartOf = [ "swww.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${wallpaper}/bin/wallpaper restore";
    };
    Install.WantedBy = [ "swww.service" ];
  };

  # matugen turns the wallpaper into a Material You palette; only its accent
  # tones are used. They replace the terminal's blue, magenta and cyan (so
  # `ls`, the prompt and fastfetch take the wallpaper's colour) and give the
  # picker its accent. Red, green and yellow keep their meaning (errors,
  # git diff, warnings) and the greys stay Stylix's so text stays readable.
  xdg.configFile = {
    "matugen/config.toml".source = (pkgs.formats.toml { }).generate "matugen.toml" {
      config = { };
      templates = {
        kitty = {
          input_path = "${config.xdg.configHome}/matugen/templates/kitty.conf";
          output_path = "${config.xdg.configHome}/kitty/matugen-colors.conf";
        };
        rofi = {
          input_path = "${config.xdg.configHome}/matugen/templates/rofi.rasi";
          output_path = "${config.xdg.configHome}/rofi/matugen-colors.rasi";
        };
      };
    };
    "matugen/templates/kitty.conf".text = ''
      # Generated by matugen from the current wallpaper (see wallpaper.nix).
      color4  {{colors.primary.default.hex}}
      color12 {{colors.primary_fixed.default.hex}}
      color5  {{colors.tertiary.default.hex}}
      color13 {{colors.tertiary_fixed.default.hex}}
      color6  {{colors.secondary.default.hex}}
      color14 {{colors.secondary_fixed.default.hex}}
    '';
    "matugen/templates/rofi.rasi".text = ''
      * { accent: {{colors.primary.default.hex}}; }
    '';
  };

  # Loaded after Stylix's colours so the wallpaper's accents win; `globinclude`
  # doesn't complain before the first wallpaper has been set.
  programs.kitty.extraConfig = lib.mkAfter "globinclude matugen-colors.conf";

  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, W, exec, wallpaper next"
      "SUPER SHIFT, W, exec, wallpaper pick"
    ];
    layerrule = [
      "blur, rofi"
      "ignorealpha 0, rofi"
    ];
    # No Hyprland mascot/logo flashing in the moment before swww draws.
    misc = {
      disable_hyprland_logo = true;
      force_default_wallpaper = 0;
    };
  };

  # swww replaces the hyprpaper Stylix would otherwise run, and the lock screen
  # follows whatever wallpaper is current instead of Stylix's fixed image.
  stylix.targets.hyprland.hyprpaper.enable = false;
  stylix.targets.hyprlock.useWallpaper = false;
  programs.hyprlock.settings.background.path = walls.current;
}
