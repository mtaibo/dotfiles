{ config, lib, pkgs, ... }: {
  boot.loader.grub.enable = false;

  # RPi5 boot flow: start4.elf → config.txt → kernel directly.
  # No U-Boot/extlinux needed — the RPi firmware loads the kernel directly.
  # This module handles copying kernel/initrd to /boot and writing config.txt.

  hardware.enableRedistributableFirmware = true;

  system.build.installBootLoader = pkgs.writeShellScript "install-rpi-bootloader" ''
    set -e

    kernel_src="${config.system.build.kernel}/${config.system.boot.loader.kernelFile}"
    initrd_src="${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}"

    cp -f "$kernel_src" /boot/rpi5-Image
    cp -f "$initrd_src" /boot/rpi5-initrd

    {
      echo '[all]'
      echo 'arm_64bit=1'
      echo 'enable_uart=1'
      echo 'kernel=rpi5-Image'
      echo 'initramfs rpi5-initrd followkernel'
      echo 'os_check=0'
    } > /boot/config.txt

    echo "${lib.concatStringsSep " " config.boot.kernelParams}" > /boot/cmdline.txt
  '';
}
