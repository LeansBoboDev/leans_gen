{ pkgs, lib, ... }:

{
	services.desktopManager.plasma6.enable = true;
	services.displayManager.sddm.enable = true;
	services.xserver.enable = true;

	virtualisation.virtualbox.host.enable = true;

	nixpkgs.config.allowUnfreePredicate = pkg:
		builtins.elem (lib.getName pkg) [
			"vscode"
	];

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

	  # Libraries
	  direnv
  ];
}
