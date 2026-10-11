{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./packages.nix
      ./users.nix
      # Uncomment the line below to enable Nvidia drivers:
      # ./nvidia.nix
    ];

  nix.settings = {
    max-jobs = "auto";
    cores = 0;
  };

  # UEFI bootloader (default for modern PCs)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # If your PC uses BIOS/Legacy instead of UEFI, comment the 2 lines above
  # and uncomment the 2 below (replace /dev/sda with your disk):
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";

  # KDE Plasma 6
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Audio via PipeWire (PulseAudio + ALSA compatible)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Required for Chrome and Nvidia drivers
  nixpkgs.config.allowUnfree = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.printing.enable = true;

  # services.openssh.enable = true;

  security.sudo.wheelNeedsPassword = true;

  system.stateVersion = "26.05";
}
