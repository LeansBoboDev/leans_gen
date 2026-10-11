{ pkgs, lib, ... }:

{
	services.desktopManager.plasma6.enable = true;
	services.displayManager.sddm.enable = true;
	services.xserver.enable = true;

	virtualisation.virtualbox.host.enable = true;

  environment.systemPackages = with pkgs; [
    # Browsers
    firefox

    # System
    vim
    wget
    curl
    htop
    git
    unzip
    p7zip

    # Multimedia
    vlc
    obs-studio

	  # Libraries
	  direnv # per-project env loading, used by VSCode's direnv extension
	  speechd # speech-dispatcher, needed by Vesktop's text-to-speech feature
  ];
}
