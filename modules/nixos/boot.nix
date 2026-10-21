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
  };

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
