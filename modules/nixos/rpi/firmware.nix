{ config, lib, pkgs, ... }: {
  boot.loader.grub.enable = false;

  # RPi5 boot flow: start4.elf → config.txt → kernel directly.
  # No U-Boot/extlinux needed — the RPi firmware loads the kernel directly.
  # This activation script copies kernel/initrd to /boot and writes config.txt
  # every time the system activates (nixos-rebuild switch / nixos-install).

  hardware.enableRedistributableFirmware = true;

  system.activationScripts.rpi-bootloader = {
    deps = [ "specialfs" ];
    text = ''
      export PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:$PATH
      set -e

      kernel_src="${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}"
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
        echo "cmdline=${lib.concatStringsSep " " config.boot.kernelParams}"
      } > /boot/config.txt

      rm -f /boot/cmdline.txt
    '';
  };
}
