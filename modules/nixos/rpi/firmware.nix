{ config, lib, pkgs, ... }: {
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  # The RPi5 boot flow:
  #   start4.elf → reads config.txt → loads U-Boot → reads extlinux.conf
  # The armstub for RPi5 is built into start4.elf, no external file needed.
  # generic-extlinux-compatible installs U-Boot automatically.

  hardware.enableRedistributableFirmware = true;

  system.activationScripts.rpi-config = lib.mkAfter ''
    cat > /boot/config.txt << 'CONFIG'
[all]
arm_64bit=1
enable_uart=1
kernel=u-boot-rpi-arm64.bin
dtoverlay=vc4-kms-v3d
dtoverlay=
[all]
initramfs initrd followkernel
os_check=0
CONFIG
  '';
}
