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

      ShowHomeButton = false;
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
        # Old theme add-on; blocked so Firefox removes it and Stylix's theme shows.
        "{73a6fe31-595d-460b-a920-fcc0f8843232}".installation_mode = "blocked";
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      name = "default";

      settings = {
        "ui.systemUsesDarkTheme" = 1;
        "browser.aboutConfig.showWarning" = false;
        "media.ffmpeg.vaapi.enabled" = true;
        "extensions.pocket.enabled" = false;
        "layout.css.devPixelsPerPx" = "1.2";
        "browser.toolbars.bookmarks.visibility" = "never";
        # Minimal chrome: no Firefox View, account or extensions buttons, and no
        # tab strip while only one tab is open.
        "browser.tabs.firefox-view" = false;
        "identity.fxaccounts.enabled" = false;
        "gnomeTheme.hideSingleTab" = true;
        "gnomeTheme.hideUnifiedExtensions" = true;
        # Lets pages without a background (the new tab) show the glass behind.
        "browser.tabs.allow_transparent_browser" = true;
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
            name = "Bookmarks Toolbar";
            toolbar = true;
            bookmarks = [
              {
                name = "GitHub";
                url = "https://github.com/mtaibo";
              }
              {
                name = "TPHome";
                url = "http://tp.home";
              }
              {
                name = "Claude";
                url = "https://claude.ai/new";
              }
              {
                name = "Gemini";
                url = "https://gemini.google.com";
              }
              {
                name = "YouTube";
                url = "https://youtube.com";
              }
            ];
          }
        ];
      };
    };
  };
}
