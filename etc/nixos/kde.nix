{ config, pkgs, lib, ... }:

# Declarative KDE Plasma settings via Home Manager + plasma-manager.
#
# Workflow to capture YOUR current KDE setup (theme, panels/widgets,
# shortcuts, etc.) instead of guessing values by hand:
#
#   1. Set up KDE manually on a live system the way you like it
#      (theme, widget positions, panels, shortcuts...).
#   2. Run the rc2nix tool that ships with plasma-manager:
#        nix run github:nix-community/plasma-manager#rc2nix > kde-dump.nix
#   3. Copy the relevant attributes it prints (workspace, panels,
#      shortcuts, kwin, etc.) into the `programs.plasma = { ... }`
#      block below, replacing/extending the example values.
#   4. Rebuild: sudo nixos-rebuild switch
#
# Docs: https://github.com/nix-community/plasma-manager

let
  homeManager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
  };
  plasmaManager = builtins.fetchTarball {
    url = "https://github.com/nix-community/plasma-manager/archive/trunk.tar.gz";
  };
in
{
  imports = [
    "${homeManager}/nixos"
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # Avoids activation failures if a plain dotfile already exists where
  # home-manager wants to place a symlink.
  home-manager.backupFileExtension = "hm-backup";

  home-manager.users.leans = { ... }: {
    imports = [ "${plasmaManager}/modules" ];

    # Keep in sync with system.stateVersion in configuration.nix.
    home.stateVersion = config.system.stateVersion;

    # NOTE: generated with `nix run github:nix-community/plasma-manager#rc2nix`
    # on 2026-10-11. rc2nix does NOT capture panel/widget layout
    # (plasma-org.kde.plasma.desktop-appletsrc) — add that by hand under
    # `panels = [ ... ];` below if you want panels/widgets reproduced too.
    # Re-run rc2nix any time you want to refresh this from your live system.
    programs.plasma = {
      enable = true;

      # Disable pointer acceleration on Wayland (KWin ignores
      # services.libinput.mouse.accelProfile from configuration.nix — that
      # setting only applies to X11). Per-device, by vendor/product ID from
      # `cat /proc/bus/input/devices`. "none" = flat/no acceleration curve.
      input.mice = [
        {
          name = "Logitech G403 HERO Gaming Mouse";
          vendorId = "046d";
          productId = "c08f";
          accelerationProfile = "none";
        }
        {
          name = "Kingston HyperX Alloy FPS RGB Mouse";
          vendorId = "0951";
          productId = "16dc";
          accelerationProfile = "none";
        }
      ];

      # panels = [
      #   {
      #     location = "bottom";
      #     widgets = [
      #       "org.kde.plasma.kickoff"
      #       "org.kde.plasma.taskmanager"
      #       "org.kde.plasma.systemtray"
      #       "org.kde.plasma.digitalclock"
      #     ];
      #   }
      # ];

      shortcuts = {
        ActivityManager.switch-to-activity-a5c04327-b9b8-42d8-a301-6f76e30b074e = [ ];
        "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
        "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";
        kaccess."Toggle Screen Reader On and Off" = "Meta+Alt+S";
        kmix.decrease_microphone_volume = "Microphone Volume Down";
        kmix.decrease_volume = "Volume Down";
        kmix.decrease_volume_small = "Shift+Volume Down";
        kmix.increase_microphone_volume = "Microphone Volume Up";
        kmix.increase_volume = "Volume Up";
        kmix.increase_volume_small = "Shift+Volume Up";
        kmix.mic_mute = ["Microphone Mute" "Meta+Volume Mute"];
        kmix.mute = "Volume Mute";
        ksmserver."Halt Without Confirmation" = [ ];
        ksmserver."Lock Session" = ["Meta+L" "Screensaver"];
        ksmserver."Log Out" = "Ctrl+Alt+Del";
        ksmserver."Log Out Without Confirmation" = [ ];
        ksmserver.LogOut = [ ];
        ksmserver.Reboot = [ ];
        ksmserver."Reboot Without Confirmation" = [ ];
        ksmserver."Shut Down" = [ ];
        kwin."Activate Window Demanding Attention" = "Meta+Ctrl+A";
        kwin."Cycle Overview" = [ ];
        kwin."Cycle Overview Opposite" = [ ];
        kwin."Decrease Opacity" = [ ];
        kwin."Edit Tiles" = "Meta+T";
        kwin.Expose = ["Meta+F9" "Ctrl+F9"];
        kwin.ExposeAll = ["Meta+F10" "Launch (C)" "Ctrl+F10"];
        kwin.ExposeClass = ["Meta+F7" "Ctrl+F7"];
        kwin.ExposeClassCurrentDesktop = [ ];
        kwin."Grid View" = "Meta+G";
        kwin."Increase Opacity" = [ ];
        kwin."Kill Window" = "Meta+Ctrl+Esc";
        kwin."Move Tablet to Next LogicalOutput" = [ ];
        kwin.MoveMouseToCenter = "Meta+F6";
        kwin.MoveMouseToFocus = "Meta+F5";
        kwin.MoveZoomDown = [ ];
        kwin.MoveZoomLeft = [ ];
        kwin.MoveZoomRight = [ ];
        kwin.MoveZoomUp = [ ];
        kwin.Overview = "Meta+W";
        kwin."Setup Window Shortcut" = [ ];
        kwin."Show Desktop" = "Meta+D";
        kwin."Switch One Desktop Down" = "Meta+Ctrl+Down";
        kwin."Switch One Desktop Up" = "Meta+Ctrl+Up";
        kwin."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
        kwin."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
        kwin."Switch Window Down" = "Meta+Alt+Down";
        kwin."Switch Window Left" = "Meta+Alt+Left";
        kwin."Switch Window Right" = "Meta+Alt+Right";
        kwin."Switch Window Up" = "Meta+Alt+Up";
        kwin."Switch to Desktop 1" = ["Meta+F1" "Ctrl+F1"];
        kwin."Switch to Desktop 10" = [ ];
        kwin."Switch to Desktop 11" = [ ];
        kwin."Switch to Desktop 12" = [ ];
        kwin."Switch to Desktop 13" = [ ];
        kwin."Switch to Desktop 14" = [ ];
        kwin."Switch to Desktop 15" = [ ];
        kwin."Switch to Desktop 16" = [ ];
        kwin."Switch to Desktop 17" = [ ];
        kwin."Switch to Desktop 18" = [ ];
        kwin."Switch to Desktop 19" = [ ];
        kwin."Switch to Desktop 2" = ["Meta+F2" "Ctrl+F2"];
        kwin."Switch to Desktop 20" = [ ];
        kwin."Switch to Desktop 21" = [ ];
        kwin."Switch to Desktop 22" = [ ];
        kwin."Switch to Desktop 23" = [ ];
        kwin."Switch to Desktop 24" = [ ];
        kwin."Switch to Desktop 25" = [ ];
        kwin."Switch to Desktop 3" = ["Meta+F3" "Ctrl+F3"];
        kwin."Switch to Desktop 4" = ["Meta+F4" "Ctrl+F4"];
        kwin."Switch to Desktop 5" = [ ];
        kwin."Switch to Desktop 6" = [ ];
        kwin."Switch to Desktop 7" = [ ];
        kwin."Switch to Desktop 8" = [ ];
        kwin."Switch to Desktop 9" = [ ];
        kwin."Switch to Next Desktop" = [ ];
        kwin."Switch to Next Screen" = [ ];
        kwin."Switch to Previous Desktop" = [ ];
        kwin."Switch to Previous Screen" = [ ];
        kwin."Switch to Screen 0" = [ ];
        kwin."Switch to Screen 1" = [ ];
        kwin."Switch to Screen 2" = [ ];
        kwin."Switch to Screen 3" = [ ];
        kwin."Switch to Screen 4" = [ ];
        kwin."Switch to Screen 5" = [ ];
        kwin."Switch to Screen 6" = [ ];
        kwin."Switch to Screen 7" = [ ];
        kwin."Switch to Screen Above" = [ ];
        kwin."Switch to Screen Below" = [ ];
        kwin."Switch to Screen to the Left" = [ ];
        kwin."Switch to Screen to the Right" = [ ];
        kwin."Toggle Night Color" = [ ];
        kwin."Toggle Window Raise/Lower" = [ ];
        kwin."Walk Through Windows" = ["Meta+Tab" "Alt+Tab"];
        kwin."Walk Through Windows (Reverse)" = ["Meta+Shift+Tab" "Alt+Shift+Tab"];
        kwin."Walk Through Windows Alternative" = [ ];
        kwin."Walk Through Windows Alternative (Reverse)" = [ ];
        kwin."Walk Through Windows of Current Application" = ["Meta+`" "Alt+`"];
        kwin."Walk Through Windows of Current Application (Reverse)" = ["Meta+~" "Alt+~"];
        kwin."Walk Through Windows of Current Application Alternative" = [ ];
        kwin."Walk Through Windows of Current Application Alternative (Reverse)" = [ ];
        kwin."Window Above Other Windows" = [ ];
        kwin."Window Below Other Windows" = [ ];
        kwin."Window Close" = "Alt+F4";
        kwin."Window Custom Quick Tile Bottom" = [ ];
        kwin."Window Custom Quick Tile Left" = [ ];
        kwin."Window Custom Quick Tile Right" = [ ];
        kwin."Window Custom Quick Tile Top" = [ ];
        kwin."Window Fullscreen" = [ ];
        kwin."Window Grow Horizontal" = [ ];
        kwin."Window Grow Vertical" = [ ];
        kwin."Window Lower" = [ ];
        kwin."Window Maximize" = "Meta+PgUp";
        kwin."Window Maximize Horizontal" = [ ];
        kwin."Window Maximize Vertical" = [ ];
        kwin."Window Minimize" = "Meta+PgDown";
        kwin."Window Move" = [ ];
        kwin."Window Move Center" = [ ];
        kwin."Window No Border" = [ ];
        kwin."Window On All Desktops" = [ ];
        kwin."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
        kwin."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
        kwin."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
        kwin."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
        kwin."Window One Screen Down" = [ ];
        kwin."Window One Screen Up" = [ ];
        kwin."Window One Screen to the Left" = [ ];
        kwin."Window One Screen to the Right" = [ ];
        kwin."Window Operations Menu" = "Alt+F3";
        kwin."Window Pack Down" = [ ];
        kwin."Window Pack Left" = [ ];
        kwin."Window Pack Right" = [ ];
        kwin."Window Pack Up" = [ ];
        kwin."Window Quick Tile Bottom" = "Meta+Down";
        kwin."Window Quick Tile Bottom Left" = [ ];
        kwin."Window Quick Tile Bottom Right" = [ ];
        kwin."Window Quick Tile Left" = "Meta+Left";
        kwin."Window Quick Tile Right" = "Meta+Right";
        kwin."Window Quick Tile Top" = "Meta+Up";
        kwin."Window Quick Tile Top Left" = [ ];
        kwin."Window Quick Tile Top Right" = [ ];
        kwin."Window Raise" = [ ];
        kwin."Window Resize" = [ ];
        kwin."Window Shrink Horizontal" = [ ];
        kwin."Window Shrink Vertical" = [ ];
        kwin."Window to Desktop 1" = [ ];
        kwin."Window to Desktop 10" = [ ];
        kwin."Window to Desktop 11" = [ ];
        kwin."Window to Desktop 12" = [ ];
        kwin."Window to Desktop 13" = [ ];
        kwin."Window to Desktop 14" = [ ];
        kwin."Window to Desktop 15" = [ ];
        kwin."Window to Desktop 16" = [ ];
        kwin."Window to Desktop 17" = [ ];
        kwin."Window to Desktop 18" = [ ];
        kwin."Window to Desktop 19" = [ ];
        kwin."Window to Desktop 2" = [ ];
        kwin."Window to Desktop 20" = [ ];
        kwin."Window to Desktop 21" = [ ];
        kwin."Window to Desktop 22" = [ ];
        kwin."Window to Desktop 23" = [ ];
        kwin."Window to Desktop 24" = [ ];
        kwin."Window to Desktop 25" = [ ];
        kwin."Window to Desktop 3" = [ ];
        kwin."Window to Desktop 4" = [ ];
        kwin."Window to Desktop 5" = [ ];
        kwin."Window to Desktop 6" = [ ];
        kwin."Window to Desktop 7" = [ ];
        kwin."Window to Desktop 8" = [ ];
        kwin."Window to Desktop 9" = [ ];
        kwin."Window to Next Desktop" = [ ];
        kwin."Window to Next Screen" = "Meta+Shift+Right";
        kwin."Window to Previous Desktop" = [ ];
        kwin."Window to Previous Screen" = "Meta+Shift+Left";
        kwin."Window to Screen 0" = [ ];
        kwin."Window to Screen 1" = [ ];
        kwin."Window to Screen 2" = [ ];
        kwin."Window to Screen 3" = [ ];
        kwin."Window to Screen 4" = [ ];
        kwin."Window to Screen 5" = [ ];
        kwin."Window to Screen 6" = [ ];
        kwin."Window to Screen 7" = [ ];
        kwin.disableInputCapture = "Meta+Shift+Esc";
        kwin.view_actual_size = "Meta+0";
        kwin.view_zoom_in = ["Meta++" "Meta+="];
        kwin.view_zoom_out = "Meta+-";
        mediacontrol.mediavolumedown = [ ];
        mediacontrol.mediavolumeup = [ ];
        mediacontrol.nextmedia = "Media Next";
        mediacontrol.pausemedia = "Media Pause";
        mediacontrol.playmedia = [ ];
        mediacontrol.playpausemedia = "Media Play";
        mediacontrol.previousmedia = "Media Previous";
        mediacontrol.seekbackwardmedia = "Media Rewind";
        mediacontrol.seekbackwardmedialong = [ ];
        mediacontrol.seekforwardmedia = "Media Fast Forward";
        mediacontrol.seekforwardmedialong = [ ];
        mediacontrol.stopmedia = "Media Stop";
        org_kde_powerdevil."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
        org_kde_powerdevil."Decrease Screen Brightness" = "Monitor Brightness Down";
        org_kde_powerdevil."Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
        org_kde_powerdevil.Hibernate = "Hibernate";
        org_kde_powerdevil."Increase Keyboard Brightness" = "Keyboard Brightness Up";
        org_kde_powerdevil."Increase Screen Brightness" = "Monitor Brightness Up";
        org_kde_powerdevil."Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
        org_kde_powerdevil.PowerDown = "Power Down";
        org_kde_powerdevil.PowerOff = "Power Off";
        org_kde_powerdevil.Sleep = "Sleep";
        org_kde_powerdevil."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
        org_kde_powerdevil."Turn Off Screen" = [ ];
        org_kde_powerdevil.powerProfile = ["Battery" "Meta+B"];
        plasmashell."Slideshow Wallpaper Next Image" = [ ];
        plasmashell."activate application launcher" = ["Meta" "Alt+F1"];
        plasmashell."activate task manager entry 1" = "Meta+1";
        plasmashell."activate task manager entry 10" = [ ];
        plasmashell."activate task manager entry 2" = "Meta+2";
        plasmashell."activate task manager entry 3" = "Meta+3";
        plasmashell."activate task manager entry 4" = "Meta+4";
        plasmashell."activate task manager entry 5" = "Meta+5";
        plasmashell."activate task manager entry 6" = "Meta+6";
        plasmashell."activate task manager entry 7" = "Meta+7";
        plasmashell."activate task manager entry 8" = "Meta+8";
        plasmashell."activate task manager entry 9" = "Meta+9";
        plasmashell.clear-history = [ ];
        plasmashell.clipboard_action = "Meta+Ctrl+X";
        plasmashell.cycle-panels = "Meta+Alt+P";
        plasmashell.cycleNextAction = [ ];
        plasmashell.cyclePrevAction = [ ];
        plasmashell.edit_clipboard = [ ];
        plasmashell."manage activities" = "Meta+Q";
        plasmashell."next activity" = "Meta+A";
        plasmashell."previous activity" = "Meta+Shift+A";
        plasmashell.repeat_action = [ ];
        plasmashell."show dashboard" = "Ctrl+F12";
        plasmashell.show-barcode = [ ];
        plasmashell.show-on-mouse-pos = "Meta+V";
        plasmashell."switch to next activity" = [ ];
        plasmashell."switch to previous activity" = [ ];
        plasmashell."toggle do not disturb" = [ ];
      };
      configFile = {
        baloofilerc."Basic Settings".Indexing-Enabled = false;
        baloofilerc.General.dbVersion = 2;
        dolphinrc."KFileDialog Settings"."Places Icons Auto-resize" = false;
        dolphinrc."KFileDialog Settings"."Places Icons Static Size" = 22;
        kactivitymanagerdrc.activities.a5c04327-b9b8-42d8-a301-6f76e30b074e = "Default";
        kded5rc.Module-device_automounter.autoload = false;
        kdeglobals.KDE.SingleClick = true;
        kdeglobals.KDE.contrast = 4;
        kdeglobals.KDE.frameContrast = 0.2;
        kdeglobals.WM.activeBackground = "39,44,49";
        kdeglobals.WM.activeBlend = "252,252,252";
        kdeglobals.WM.activeForeground = "252,252,252";
        kdeglobals.WM.inactiveBackground = "32,36,40";
        kdeglobals.WM.inactiveBlend = "161,169,177";
        kdeglobals.WM.inactiveForeground = "161,169,177";
        krunnerrc.Plugins.baloosearchEnabled = false;
        kwalletrc.Wallet."First Use" = false;
        kwinrc.Desktops.Id_1 = "c5553a7f-9255-41ad-9e72-020dfd869b67";
        kwinrc.Desktops.Number = 1;
        kwinrc.Desktops.Rows = 1;
        # Night Color left out on purpose — it's a personal taste setting,
        # not something every install should default to. Uncomment if you
        # want it:
        # kwinrc.NightColor.Active = true;
        # kwinrc.NightColor.Mode = "Constant";
        # kwinrc.NightColor.NightTemperature = 4100;
        kwinrc.Xwayland.Scale = 1;
        kxkbrc.Layout.LayoutList = "br";
        kxkbrc.Layout.Use = true;
        plasma-localerc.Formats.LANG = "en_US.UTF-8";
        plasmanotifyrc."Applications/firefox".Seen = true;
      };
    };
  };
}
