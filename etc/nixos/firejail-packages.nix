{ config, lib, pkgs, ... }:

# Wraps selected packages with Firejail, giving each one a fake $HOME
# (via `--env=HOME=...`) instead of letting it write its dotfolder(s)
# straight into the real $HOME. This works for any app that resolves its
# config/data paths from the HOME env var (true of basically every
# Electron/Node/GTK/Qt app) and, unlike `--bind`, never creates anything
# at the original path -- there's no placeholder to pre-create, since
# setting an env var has no filesystem requirement.
#
# `desktop` lets firejail hand back a copy of the package's .desktop file
# with its Exec= line pointed at the wrapped binary -- only needed when
# that line embeds the real binary's absolute store path; a bare command
# name (resolved via $PATH, like vscode's `Exec=code %F`) already picks up
# the wrapper automatically through the normal PATH priority.
#
# To sandbox a new app: add an entry below with its package, the binary
# name to wrap, where its fake home should live, and which real-$HOME
# paths need migrating into it once.
let
  home = config.users.users.leans.home;
  xdgData = "${home}/.local/share";

  firejailHomeApps = {
    code = {
      package = pkgs.vscode;
      binary = "code";
      desktopFile = "code.desktop";
      fakeHome = "${xdgData}/vscode-home";
      migrate = [ ".vscode" ".config/Code" ];
    };

    claude = {
      package = pkgs.claude-code;
      binary = "claude";
      fakeHome = "${xdgData}/claude-home";
      migrate = [ ".claude" ];
    };

    # Firejail auto-loads its own bundled steam.profile by matching the
    # wrapped binary's basename unless told not to -- that profile's extra
    # seccomp/device restrictions are a common source of games (especially
    # anti-cheat titles) refusing to start, so --noprofile keeps this to
    # just the $HOME redirect. Some anti-cheat games may still refuse to
    # launch under any namespace sandboxing at all, firejail or not --
    # that's a Proton/Linux-wide limitation, not something this file can
    # fix per game.
    steam = {
      package = pkgs.steam;
      binary = "steam";
      desktopFile = "steam.desktop";
      fakeHome = "${xdgData}/steam-home";
      migrate = [ ".steam" ".local/share/Steam" ];
      extraFirejailArgs = [ "--noprofile" ];
    };
  };

  mkWrapped = _name: app: {
    executable = "${lib.getBin app.package}/bin/${app.binary}";
    extraArgs = [ "--env=HOME=${app.fakeHome}" ] ++ (app.extraFirejailArgs or [ ]);
  } // lib.optionalAttrs (app ? desktopFile) {
    desktop = "${app.package}/share/applications/${app.desktopFile}";
  };
in
{
  environment.systemPackages = lib.mapAttrsToList (_: app: app.package) firejailHomeApps;

  programs.firejail = {
    enable = true;
    wrappedBinaries = lib.mapAttrs mkWrapped firejailHomeApps;
  };

  # One-time migration: move any pre-existing data from its old spot in
  # the real $HOME into the app's fake home, so nothing is lost and
  # nothing is left behind at the original path.
  system.activationScripts.firejailHomeMigrate = lib.mkAfter (
    lib.concatMapStrings (app: lib.concatMapStrings (rel: ''
      from='${home}/${rel}'
      to='${app.fakeHome}/${rel}'
      if [ -e "$from" ] && [ ! -L "$from" ] && [ ! -e "$to" ]; then
        install -d -o leans -g users "$(dirname "$to")"
        mv "$from" "$to"
      fi
    '') app.migrate) (lib.attrValues firejailHomeApps)
  );
}
