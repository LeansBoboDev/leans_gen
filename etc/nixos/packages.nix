{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Browsers
    firefox
    google-chrome

    # System
    vim
    wget
    curl
    htop
    git
    unzip
    p7zip

    # KDE apps
    kate
    ark
    dolphin
    konsole
    spectacle

    # Multimedia
    vlc
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
  ];
}
