{ config, lib, pkgs, ... }: {
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  # RPi5 boot flow: start4.elf → config.txt → kernel directly
  # The extlinux module writes kernel/initrd to /boot/nixos/<hash>-*
  # but does NOT update config.txt, so it becomes stale after rebuild.
  # This activation script rewrites config.txt with the latest paths.

  hardware.enableRedistributableFirmware = true;

  system.activationScripts.rpi-config = lib.mkAfter ''
    latest_kernel=$(ls -1t /boot/nixos/*-Image 2>/dev/null | head -1)
    latest_initrd=$(ls -1t /boot/nixos/*-initrd 2>/dev/null | head -1)

    if [ -n "$latest_kernel" ] && [ -n "$latest_initrd" ]; then
      cat > /boot/config.txt << CONFIG
[all]
arm_64bit=1
enable_uart=1
kernel=nixos/$(basename "$latest_kernel")
initramfs nixos/$(basename "$latest_initrd") followkernel
os_check=0
CONFIG
    fi
  '';
}
