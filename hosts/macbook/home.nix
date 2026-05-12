{ pkgs, lib, ... }: {
  imports = [ ../../modules/home ];
  home.homeDirectory = lib.mkForce "/Users/migueltaibo";

  home.file = builtins.listToAttrs (map
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
    ])
    // {
      # macOS Service: ⌘K → Kitty fullscreen (macOS only, not NixOS)
      "Library/Services/OpenKittyFullscreen.workflow".source =
        ../../modules/home/dotfiles/macOS/OpenKittyFullscreen.workflow;
    };

  # Register ⌘K shortcut for the service after linking
  home.activation.registerKittyShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Register ⌘K for the Open Kitty Fullscreen service
    $DRY_RUN_CMD defaults write pbs NSServicesStatus -dict-add \
      "(Open Kitty Fullscreen - runWorkflowAsService - com.migueltaibo.OpenKittyFullscreen)" \
      '{ key_equivalent = "@K"; }' 2>/dev/null || true
    # Flush services database so the shortcut takes effect immediately
    if [ -x /System/Library/CoreServices/pbs ]; then
      $DRY_RUN_CMD /System/Library/CoreServices/pbs -flush 2>/dev/null || true
    fi
  '';
}
