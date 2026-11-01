{ pkgs, ... }:
let
  # Netflix in a small window that floats over everything, games in fullscreen
  # included. It is a whole Firefox window (own profile, no toolbars) and not
  # Firefox's Picture-in-Picture, which drops Netflix's subtitles.
  userJs = pkgs.writeText "netflix-pip-user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.aboutwelcome.enabled", false);
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
    user_pref("browser.sessionstore.resume_from_crash", false);
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("media.eme.enabled", true);
    user_pref("media.gmp-widevinecdm.enabled", true);
    user_pref("media.gmp-widevinecdm.visible", true);
    user_pref("media.ffmpeg.vaapi.enabled", true);
    user_pref("layout.css.prefers-color-scheme.content-override", 0);
    // No fullscreen button: it would blow the small window up to the screen.
    user_pref("full-screen-api.enabled", false);
  '';
  userChrome = pkgs.writeText "netflix-pip-userChrome.css" ''
    #navigator-toolbox { visibility: collapse !important; }
  '';

  netflix-pip = pkgs.writeShellApplication {
    name = "netflix-pip";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      # Already open: just bring it to the front.
      if hyprctl clients -j | jq -e 'any(.[]; .class == "netflix-pip")' >/dev/null; then
        exec hyprctl dispatch focuswindow 'class:^(netflix-pip)$'
      fi
      # Data dir, not cache: it holds the Netflix login.
      profile=''${XDG_DATA_HOME:-$HOME/.local/share}/netflix-pip-firefox
      mkdir -p "$profile/chrome"
      install -m 644 ${userJs} "$profile/user.js"
      install -m 644 ${userChrome} "$profile/chrome/userChrome.css"
      exec firefox --profile "$profile" --no-remote --new-instance --name netflix-pip \
        https://www.netflix.com
    '';
  };
in {
  home.packages = [ netflix-pip ];

  wayland.windowManager.hyprland.settings = {
    # Pinned = on every workspace and above fullscreen windows.
    windowrule = [
      "float, class:^(netflix-pip)$"
      "pin, class:^(netflix-pip)$"
      "size 480 270, class:^(netflix-pip)$"
      "move 100%-500 100%-290, class:^(netflix-pip)$"
      "opacity 1.0 override, class:^(netflix-pip)$"
    ];

    bindd = [
      "SUPER, P, Netflix en ventana pequeña, exec, netflix-pip"
      "SUPER SHIFT, P, Cerrar la ventana de Netflix, closewindow, class:^(netflix-pip)$"
    ];
  };

  dotfiles.english = {
    "Netflix en ventana pequeña" = "Netflix in a small window";
    "Cerrar la ventana de Netflix" = "Close the Netflix window";
  };
}
