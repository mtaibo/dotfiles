{ pkgs, lib, ... }:
with lib;
{
  programs.firefox = mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxScreenshots = true;
      OfferToSaveLogins = false;
      OfferToSaveLoginsDefault = false;
      PasswordManagerEnabled = false;

      ShowHomeButton = true;
      HomepageUrl = "about:blank";
      HomepageStartPage = "none";
      NewTabPage = false;

      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      HardwareAcceleration = true;
      BackgroundMode = false;

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
          private_browsing = true;
        };
        "{cebd391d-f568-473f-bb6e-698d08ec81ec}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tokyo-night-dark-theme/latest.xpi";
          installation_mode = "force_installed";
          default_area = "navbar";
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
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "layout.css.devPixelsPerPx" = "1.2";
        "browser.tabs.allowTransparentBrowser" = true;
        "widget.allow-background-blur" = true;
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "GitHub";
            url = "https://github.com/mtaibo";
          }
          {
            name = "Gemini";
            url = "https://gemini.google.com";
          }
          {
            name = "TPHome";
            url = "http://tp.home";
          }
          {
            name = "YouTube";
            url = "https://youtube.com";
          }
          {
            name = "OpenCode";
            url = "https://opencode.ai";
          }
        ];
      };

      userChrome = builtins.readFile ../../../assets/firefox/userChrome.css;
      userContent = builtins.readFile ../../../assets/firefox/userContent.css;
    };
  };
}
