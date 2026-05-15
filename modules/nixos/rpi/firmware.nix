{ config, lib, pkgs, ... }: {
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  hardware.enableRedistributableFirmware = true;

  # Write a correct config.txt and install RPi5 armstub on every rebuild.
  # generic-extlinux-compatible handles U-Boot installation automatically.
  system.activationScripts.rpi-boot = lib.mkAfter ''
    cp -f ${pkgs.raspberrypifw}/share/raspberrypi/boot/armstub8-2712.bin /boot/armstub8-2712.bin

    cat > /boot/config.txt << 'CONFIG'
[all]
arm_64bit=1
enable_uart=1
kernel=u-boot-rpi-arm64.bin
armstub=armstub8-2712.bin
dtoverlay=vc4-kms-v3d
dtoverlay=
[all]
initramfs initrd followkernel
os_check=0
CONFIG
  '';
}
