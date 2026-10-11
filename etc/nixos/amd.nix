{ pkgs, ... }:

{
  # AMD GPU drivers (open-source amdgpu, included in the kernel)

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # required for 32-bit Steam games
  };

  services.xserver.videoDrivers = [ "amdgpu" ];
}
