{ ... }:

{
  programs.firefox = {
    enable = true;

    policies = {
      # Privacy & telemetry
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxScreenshots = true;
      OfferToSaveLogins = false;
      OfferToSaveLoginsDefault = false;
      PasswordManagerEnabled = false;

      # Appearance
      ShowHomeButton = true;
      HomepageUrl = "about:blank";
      HomepageStartPage = "homepage";
      NewTabPage = false;

      # UX
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      HardwareAcceleration = true;
      BackgroundMode = false;

      # Force-installed extensions (from Mozilla CDN)
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
          private_browsing = true;
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
          private_browsing = true;
        };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      name = "default";

      settings = {
        "ui.systemUsesDarkTheme" = 1;
        "widget.content.gtk-theme-override" = "Adwaita:dark";
        "browser.aboutConfig.showWarning" = false;
        "media.ffmpeg.vaapi.enabled" = true;
        "extensions.pocket.enabled" = false;
      };
    };
  };
}
