{ pkgs, lib, ... }:

{
	services.desktopManager.plasma6.enable = true;
	services.displayManager.sddm.enable = true;
	services.displayManager.sddm.autoNumlock = true;
	services.xserver.enable = true;
	services.flatpak.enable = true;

	virtualisation.virtualbox.host.enable = true;
	virtualisation.docker.enable = true;

	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
	  libx11
	  libxcursor
	  libxext
	  libxrandr
	  libxinerama
	  libxi
	  libxrender
	  libxfixes
	  wayland
	  libxkbcommon
	  libdecor
	  libglvnd      # libGL / libEGL
	  vulkan-loader
	  alsa-lib
	  pulseaudio    # fornece libpulse.so, usado pelo compat do PipeWire
	];
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
    zip
    p7zip
    python3
    docker

    # Multimedia
    vlc
    blender
    flameshot
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
