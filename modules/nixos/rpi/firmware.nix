{ config, lib, pkgs, nixos-raspberrypi, ... }:
let
  firmwarePkg = nixos-raspberrypi.packages.aarch64-linux.raspberrypifw;
  firmwareDir = "${firmwarePkg}/share/raspberrypi/boot";
in
{
  boot.loader.grub.enable = false;

  # RPi5 boot flow: start4.elf → config.txt → kernel directly.
  # No U-Boot/extlinux needed — the RPi firmware loads the kernel directly.
  # This activation script copies kernel/initrd, DTBs, firmware, and writes
  # config.txt every time the system activates (nixos-rebuild switch).
  #
  # The DTB (bcm2712-rpi-5-b.dtb) is CRITICAL — without it the kernel
  # can't init hardware (no HDMI, no networking).

  hardware.enableRedistributableFirmware = true;

  system.activationScripts.rpi-bootloader = {
    deps = [ "specialfs" ];
    text = ''
      export PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:$PATH
      set -e

      echo "rpi-bootloader: installing firmware + DTB + kernel + config.txt"

      # --- Firmware boot files (start4.elf, fixup4.dat, bootcode.bin) ---
      for f in "${firmwareDir}"/start*.elf "${firmwareDir}"/fixup*.dat "${firmwareDir}"/bootcode.bin; do
        [ -f "$f" ] && cp -f "$f" /boot/
      done

      # --- Device Tree Blobs ---
      for f in "${firmwareDir}"/*.dtb; do
        [ -f "$f" ] && cp -f "$f" /boot/
      done

      # --- Device Tree Overlays ---
      mkdir -p /boot/overlays
      for f in "${firmwareDir}"/overlays/*; do
        [ -f "$f" ] && cp -f "$f" /boot/overlays/
      done

      # --- Kernel + initrd ---
      kernel_src="${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}"
      initrd_src="${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}"

      cp -f "$kernel_src" /boot/rpi5-Image
      cp -f "$initrd_src" /boot/rpi5-initrd

      # --- config.txt ---
      {
        echo '[all]'
        echo 'arm_64bit=1'
        echo 'enable_uart=1'
        echo 'kernel=rpi5-Image'
        echo 'initramfs rpi5-initrd followkernel'
        echo 'os_check=0'
        echo "cmdline=${lib.concatStringsSep " " config.boot.kernelParams}"
      } > /boot/config.txt

      rm -f /boot/cmdline.txt
    '';
  };
}
