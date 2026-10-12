{ pkgs, lib, ... }:

{
	services.desktopManager.plasma6.enable = true;
	services.displayManager.sddm.enable = true;
	services.xserver.enable = true;

	virtualisation.virtualbox.host.enable = true;

	programs.nix-ld.enable = true;

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
    appimage-run

    # Multimedia
    vlc
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-pipewire-audio-capture
      ];
    })

    # Gaming
    mangohud
    goverlay

	  # Libraries
	  direnv # per-project env loading, used by VSCode's direnv extension
	  speechd # speech-dispatcher, needed by Vesktop's text-to-speech feature
  ];
}
