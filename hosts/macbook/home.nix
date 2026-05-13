{ pkgs, lib, pkgsUnstable, ... }: {
  imports = [ ../../modules/home ];
  home.homeDirectory = lib.mkForce "/Users/migueltaibo";
  services.ollama = {
    enable = true;
    package = pkgsUnstable.ollama;
  };
  home.file = (builtins.listToAttrs (map
    (name: {
      name = "/Library/Fonts/${name}";
      value.source = "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/${name}";
    })
    [
      "FiraCodeNerdFont-Regular.ttf"
      "FiraCodeNerdFont-Bold.ttf"
      "FiraCodeNerdFont-Medium.ttf"
      "FiraCodeNerdFont-Retina.ttf"
      "FiraCodeNerdFont-SemiBold.ttf"
      "FiraCodeNerdFont-Light.ttf"
    ]))
    // {
      "Library/Services/OpenKittyFullscreen.workflow".source =
        ../../modules/home/dotfiles/macOS/OpenKittyFullscreen.workflow;
    };
  home.activation.setKittyIcon = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KITTY_APP="/Users/migueltaibo/Applications/Home Manager Apps/kitty.app"
    if [ -d "$KITTY_APP" ]; then
      $DRY_RUN_CMD cp ${../../modules/home/dotfiles/macOS/kitty-icon.icns} \
        "$KITTY_APP/Contents/Resources/kitty.icns"
      $DRY_RUN_CMD touch "$KITTY_APP"
      $DRY_RUN_CMD rm -f /var/folders/*/*/*/com.apple.dock.iconcache 2>/dev/null || true
      $DRY_RUN_CMD killall Dock 2>/dev/null || true
    fi
  '';
  home.activation.registerKittyShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/libexec/PlistBuddy -c "Add NSServicesStatus:'(Open Kitty Fullscreen - runWorkflowAsService - com.migueltaibo.OpenKittyFullscreen)' dict" \
      ~/Library/Preferences/pbs.plist 2>/dev/null || true
    $DRY_RUN_CMD /usr/libexec/PlistBuddy -c "Add NSServicesStatus:'(Open Kitty Fullscreen - runWorkflowAsService - com.migueltaibo.OpenKittyFullscreen)':key_equivalent string @K" \
      ~/Library/Preferences/pbs.plist 2>/dev/null || \
      /usr/libexec/PlistBuddy -c "Set NSServicesStatus:'(Open Kitty Fullscreen - runWorkflowAsService - com.migueltaibo.OpenKittyFullscreen)':key_equivalent @K" \
      ~/Library/Preferences/pbs.plist 2>/dev/null || true
    $DRY_RUN_CMD killall pbs 2>/dev/null || true
  '';
}