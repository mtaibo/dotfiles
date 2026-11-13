{ pkgs, ... }:
let
  # cloud.migueltaibo.com as an app of its own: a Firefox window with its own
  # profile, class and icon, no tabs or toolbars, so it tiles, shows in
  # Vicinae and stays apart from the normal Firefox.
  userJs = pkgs.writeText "tpcloud-user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.aboutwelcome.enabled", false);
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
    user_pref("browser.sessionstore.resume_from_crash", false);
    user_pref("browser.tabs.warnOnClose", false);
    // The page is laid out for phones and looks tiny at 1:1 on the desktop.
    user_pref("layout.css.devPixelsPerPx", "1.25");
  '';
  userChrome = pkgs.writeText "tpcloud-userChrome.css" ''
    #navigator-toolbox { visibility: collapse !important; }
  '';

  tpcloud = pkgs.writeShellApplication {
    name = "tpcloud";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      # Already open: just bring it to the front.
      if hyprctl clients -j | jq -e 'any(.[]; .class == "tpcloud")' >/dev/null; then
        exec hyprctl dispatch focuswindow 'class:^(tpcloud)$'
      fi
      # Data dir, not cache: it holds the login.
      profile=''${XDG_DATA_HOME:-$HOME/.local/share}/tpcloud-firefox
      mkdir -p "$profile/chrome"
      install -m 644 ${userJs} "$profile/user.js"
      install -m 644 ${userChrome} "$profile/chrome/userChrome.css"
      exec firefox --profile "$profile" --no-remote --new-instance --name tpcloud \
        https://cloud.migueltaibo.com
    '';
  };
in {
  home.packages = [ tpcloud ];

  xdg.desktopEntries.tpcloud = {
    name = "Cloud";
    genericName = "cloud.migueltaibo.com";
    exec = "tpcloud";
    icon = "${../../../assets/icons/tpcloud.svg}";
    categories = [ "Network" ];
    settings.StartupWMClass = "tpcloud";
  };

  wayland.windowManager.hyprland.settings.bindd = [
    "SUPER, T, Abrir Cloud, exec, tpcloud"
  ];
  dotfiles.english."Abrir Cloud" = "Open Cloud";
}
