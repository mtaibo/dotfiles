{ config, lib, pkgs, ... }:
let
  # Shared with the SDDM login theme so both screens look the same.
  s = import ../../lockscreen.nix {
    colors = config.lib.stylix.colors;
    font = config.stylix.fonts.sansSerif.name;
  };
  family = weight: if weight == "Regular" then s.font else "${s.font} ${weight}";
  pos = y: "0, ${toString y}";
  label = item: text: {
    inherit text;
    font_family = family item.weight;
    font_size = item.size;
    color = "rgba(${item.color})";
    position = pos item.y;
    halign = "center";
    valign = "center";
  };
  date = locale: strftime: label s.date "cmd[update:60000] LC_TIME=${locale} date +\"${strftime}\"";
  placeholder = text: "<span foreground=\"##${s.input.placeholderColor}\">${text}</span>";

  # The same lock screen with its texts in English, for when the system
  # language is (language.nix): the Spanish one with the texts swapped.
  englishConf = pkgs.writeText "hyprlock-en.conf" (lib.hm.generators.toHyprconf {
    attrs = lib.recursiveUpdate config.programs.hyprlock.settings {
      label = [ (date "en_US.UTF-8" s.english.strftime) ] ++ lib.tail config.programs.hyprlock.settings.label;
      input-field = {
        placeholder_text = placeholder s.english.placeholder;
        fail_text = s.english.failText;
      };
    };
    inherit (config.programs.hyprlock) importantPrefixes;
  });

  # SUPER+L: hyprlock in the system language.
  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    text = ''
      if [ "$(cat "$XDG_RUNTIME_DIR/system-language" 2>/dev/null)" = en ]; then
        exec hyprlock --config ${englishConf}
      fi
      exec hyprlock
    '';
  };
in {
  home.packages = [ lockScreen ];

  # Wallpaper comes from Stylix; layout and colours from modules/lockscreen.nix:
  # date + big clock on top, name and a glass pill input below.
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      animations = {
        enabled = true;
        bezier = [ "ease, 0.25, 0.1, 0.25, 1" ];
        # hyprlock counts animation speed in tenths of a second.
        animation = [ "fade, 1, ${toString (s.fadeMs / 100)}, ease" ];
      };

      background = {
        blur_passes = s.background.blurPasses;
        blur_size = s.background.blurSize;
        inherit (s.background) brightness vibrancy;
      };

      label = [
        (date "es_ES.UTF-8" s.date.strftime)
        (label s.clock "$TIME")
        (label s.name "$DESC")
      ];

      input-field = {
        size = "${toString s.input.width}, ${toString s.input.height}";
        rounding = -1;
        outline_thickness = 1;
        inner_color = lib.mkForce "rgba(${s.input.fill})";
        outer_color = lib.mkForce "rgba(${s.input.outline})";
        font_color = lib.mkForce "rgb(${s.input.textColor})";
        check_color = lib.mkForce "rgb(${s.input.checkColor})";
        fail_color = lib.mkForce "rgb(${s.input.failColor})";
        dots_size = s.input.dotsSize;
        dots_spacing = s.input.dotsSpacing;
        dots_center = true;
        fade_on_empty = false;
        placeholder_text = placeholder s.input.placeholder;
        fail_text = s.input.failText;
        fail_timeout = s.input.failTimeoutMs;
        font_family = s.font;
        position = pos s.input.y;
        halign = "center";
        valign = "center";
      };
    };
  };
}
