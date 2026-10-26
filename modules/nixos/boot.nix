{ pkgs, lib, ... }: {
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 2;
    # Disable auto-discovery of other OS loaders (Windows), otherwise it
    # would show up a second time at the bottom of the menu alongside the
    # static entry added below.
    settings.auto-entries = false;
  };

  # Lanzaboote has no equivalent of systemd-boot's `extraEntries`, so add a
  # static boot entry for Windows ourselves. Its sort-key ("windows") sorts
  # alphabetically after lanzaboote's own sort-key ("lanza"), which is what
  # puts Windows below every NixOS generation in the menu.
  system.activationScripts.windowsBootEntry = ''
    mkdir -p /boot/loader/entries
    cp ${pkgs.writeText "windows.conf" ''
      title Windows 11
      sort-key windows
      efi /EFI/Microsoft/Boot/bootmgfw.efi
    ''} /boot/loader/entries/windows.conf
  '';

  system.nixos.label = "";

  environment.systemPackages = [ pkgs.sbctl ];

  time.hardwareClockInLocalTime = true;

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
}
