{ config, lib, ... }:
let
  c = config.lib.stylix.colors;
  font = config.stylix.fonts.sansSerif.name;
in {
  # Wallpaper and base colours come from Stylix; this adds a macOS-like
  # layout: date + big clock on top, name and a glass pill input below.
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
        animation = [ "fade, 1, 4, ease" ];
      };

      background = {
        blur_passes = 3;
        blur_size = 8;
        brightness = 0.7;
        vibrancy = 0.2;
      };

      label = [
        {
          text = ''cmd[update:60000] date +"%A, %e de %B"'';
          font_family = font;
          font_size = 22;
          color = "rgba(${c.base07}dd)";
          position = "0, 330";
          halign = "center";
          valign = "center";
        }
        {
          text = "$TIME";
          font_family = "${font} Bold";
          font_size = 110;
          color = "rgba(${c.base07}ee)";
          position = "0, 220";
          halign = "center";
          valign = "center";
        }
        {
          text = "$DESC";
          font_family = "${font} SemiBold";
          font_size = 15;
          color = "rgba(${c.base07}ee)";
          position = "0, -160";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = {
        size = "260, 44";
        rounding = -1;
        outline_thickness = 1;
        # Translucent glass instead of Stylix's solid fill.
        inner_color = lib.mkForce "rgba(ffffff1a)";
        outer_color = lib.mkForce "rgba(ffffff26)";
        dots_size = 0.25;
        dots_spacing = 0.3;
        fade_on_empty = false;
        placeholder_text = ''<span foreground="##${c.base07}99">Contraseña</span>'';
        font_family = font;
        position = "0, -215";
        halign = "center";
        valign = "center";
      };
    };
  };
}
