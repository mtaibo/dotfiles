{ config, lib, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  # Translucent fill + faint white edge, same glass as the bar.
  glass = {
    background = lib.mkForce "${c.base00}99";
    frame_color = lib.mkForce "#ffffff26";
  };
in {
  # Font and text colours come from Stylix; Hyprland blurs the
  # "notifications" layer behind them.
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "(12, 52)";
        width = 360;
        height = "(0, 160)";
        notification_limit = 5;
        gap_size = 8;
        padding = 12;
        horizontal_padding = 14;
        frame_width = 1;
        corner_radius = 14;
        separator_color = lib.mkForce "frame";
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 48;
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        ellipsize = "end";
        show_age_threshold = -1;
        mouse_left_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low = glass // { timeout = 4; };
      urgency_normal = glass // { timeout = 6; };
      # Critical keeps Stylix's red frame so it stands out.
      urgency_critical = {
        background = lib.mkForce "${c.base00}cc";
        timeout = 0;
      };
    };
  };
}
