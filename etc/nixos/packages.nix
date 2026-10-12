{ pkgs, lib, ... }:

{
	services.desktopManager.plasma6.enable = true;
	services.displayManager.sddm.enable = true;
	services.xserver.enable = true;

	virtualisation.virtualbox.host.enable = true;

	programs.nix-ld.enable = true;
	programs.appimage = {
	  enable = true;
	  binfmt = true;
	};

	environment.sessionVariables = {
	  # WebKitGTK's DMA-BUF renderer crashes with EGL_SUCCESS/no-display errors
	  # on the NVIDIA proprietary driver under Wayland. Affects Tauri apps
	  # (e.g. Samira) and other webkit2gtk-based software.
	  WEBKIT_DISABLE_DMABUF_RENDERER = "1";
	};

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
