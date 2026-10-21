{ pkgs, ... }: {
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 2;
      extraInstallCommands = ''
        default=""
        while read -r key val; do
          [ "$key" = "default" ] && default=$val
        done < /boot/loader/loader.conf
        for f in /boot/loader/entries/nixos-generation-*.conf; do
          [ -e "$f" ] || continue
          if [ "''${f##*/}" = "$default" ]; then
            ${pkgs.gnused}/bin/sed -i 's/^title .*/title NixOS/' "$f"
          else
            ${pkgs.gnused}/bin/sed -i 's/^title .*/title NixOS-Backup/' "$f"
          fi
        done
      '';
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

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
