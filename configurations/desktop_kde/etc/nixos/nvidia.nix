{ config, ... }:

{
  # Nvidia proprietary drivers
  # To enable: add "./nvidia.nix" to the imports in configuration.nix
  #
  # Requirements:
  #   - nixpkgs.config.allowUnfree = true  (already set in configuration.nix)
  #   - Compatible Nvidia GPU

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for 32-bit Steam games
  };

  services.xserver.videoDrivers = [ "nvidia" ];
}
