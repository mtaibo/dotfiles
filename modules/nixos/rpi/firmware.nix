{ config, lib, pkgs, ... }: {
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  # RPi5 boot flow: start4.elf → config.txt → kernel directly
  # extlinux writes kernel/initrd to /boot/nixos/<hash>-*
  # but does NOT update config.txt, so it becomes stale after rebuild.
  # This wraps installBootLoader to update config.txt after extlinux runs.

  hardware.enableRedistributableFirmware = true;

  system.build.installBootLoader = pkgs.writeShellScript "install-rpi-bootloader" ''
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} "$1"

    latest_kernel=$(ls -1t /boot/nixos/*-Image 2>/dev/null | head -1)
    latest_initrd=$(ls -1t /boot/nixos/*-initrd 2>/dev/null | head -1)

    if [ -n "$latest_kernel" ] && [ -n "$latest_initrd" ]; then
      {
        echo '[all]'
        echo 'arm_64bit=1'
        echo 'enable_uart=1'
        echo "kernel=nixos/$(basename "$latest_kernel")"
        echo "initramfs nixos/$(basename "$latest_initrd") followkernel"
        echo 'os_check=0'
      } > /boot/config.txt
    fi
  '';
}
