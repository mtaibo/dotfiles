{ config, lib, pkgs, ... }:
let
  # The choice lives in $XDG_RUNTIME_DIR, so every login starts in Spanish.
  # Scripts elsewhere (bar, cheatsheet, popup, lock screen, fastfetch) read
  # this file to pick their texts.
  state = ''"$XDG_RUNTIME_DIR/system-language"'';

  # system-language [toggle|apply|get|status]
  # Spanish or English, keyboard and language together. toggle (the bar's
  # ES/EN island) flips it; apply sets the current one again, on every
  # Hyprland start and reload, since a reload brings back kb_layout from the
  # config; get prints es or en; status is the island's JSON.
  # The layout is a single kb_layout ("es" or "us") rather than "es,us" and an
  # index: every keyboard Hyprland adds later (Vicinae's virtual one after its
  # restart, the Bluetooth keyboard reconnecting) starts on index 0, so the
  # index drifted between devices and the bar showed the wrong one.
  # Apps opened afterwards (from Hyprland, Vicinae or D-Bus) start in the new
  # language; open ones keep theirs.
  systemLanguage = pkgs.writeShellApplication {
    name = "system-language";
    runtimeInputs = with pkgs; [ coreutils util-linux systemd dbus procps ];
    text = ''
      get() { [ "$(cat ${state} 2>/dev/null)" = en ] && echo en || echo es; }

      apply() {
        if [ "$(get)" = en ]; then layout=us locale=en_US.UTF-8; else layout=es locale=es_ES.UTF-8; fi
        hyprctl --batch "keyword input:kb_layout $layout; keyword env LANG,$locale; keyword env LC_TIME,$locale" >/dev/null
        export LANG="$locale" LC_TIME="$locale"
        dbus-update-activation-environment --systemd LANG LC_TIME
        # The bar's clock and language island.
        pkill -RTMIN+8 -x .waybar-wrapped || true
        pkill -RTMIN+9 -x .waybar-wrapped || true
      }

      case "''${1:-toggle}" in
        toggle)
          # A second click while the first is still running is ignored.
          exec 9> "$XDG_RUNTIME_DIR/system-language.lock"
          flock -n 9 || exit 0
          if [ "$(get)" = en ]; then echo es > ${state}; else echo en > ${state}; fi
          apply
          # Vicinae launches apps from its daemon, so it needs the new language too.
          systemctl --user restart vicinae.service || true
          ;;
        apply) apply ;;
        get) get ;;
        status)
          if [ "$(get)" = en ]; then
            printf '%s\n' '{"text":"EN","class":"en","tooltip":"Keyboard and language: English\nClick: Spanish"}'
          else
            printf '%s\n' '{"text":"ES","class":"es","tooltip":"Teclado e idioma: español\nClic: inglés"}'
          fi
          ;;
        *) echo "usage: system-language [toggle|apply|get|status]" >&2; exit 1 ;;
      esac
    '';
  };

  # "MODS, key, description, dispatcher, args" -> description
  describe = bind: lib.trim (builtins.elemAt (lib.splitString "," bind) 2);
  untranslated = lib.filter (d: !(config.dotfiles.english ? ${d}))
    (map describe config.wayland.windowManager.hyprland.settings.bindd);
in {
  # English for the Spanish texts, mainly the shortcut descriptions: each
  # module adds its own next to its binds, and SUPER+H shows them in English
  # when the system language is.
  options.dotfiles.english = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "English translation of each Spanish text, keyed by the Spanish one.";
  };

  config = {
    home.packages = [ systemLanguage ];

    wayland.windowManager.hyprland.settings.exec = [ "system-language apply" ];

    assertions = [{
      assertion = untranslated == [ ];
      message = "dotfiles.english is missing these shortcut descriptions: ${lib.concatStringsSep "; " untranslated}";
    }];
  };
}
