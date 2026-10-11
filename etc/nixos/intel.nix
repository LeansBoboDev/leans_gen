{ pkgs, ... }:

{
  # Intel GPU drivers (open-source modesetting + VA-API)

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  services.xserver.videoDrivers = [ "modesetting" ];
}
