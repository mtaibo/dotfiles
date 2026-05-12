{ pkgs, ... }:

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

      extensions.packages = with pkgs.firefox-addons; [
        ublock-origin
        dark-reader
      ];
    };
  };
}
