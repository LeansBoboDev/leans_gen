{ pkgs, lib, ... }:

# Wraps selected packages with Firejail, giving each one a fake $HOME
# (via `--env=HOME=...`) instead of letting it write its dotfolder(s)
# straight into the real $HOME. This works for any app that resolves its
# config/data paths from the HOME env var (true of basically every
# Electron/Node/GTK/Qt app) and, unlike `--bind`, never creates anything
# at the original path -- there's no placeholder to pre-create, since
# setting an env var has no filesystem requirement.
#
# These wrappers are hand-rolled shell scripts rather than
# `programs.firejail.wrappedBinaries`, because that option bakes each
# binary's `extraArgs` into the wrapper at *build* time via
# `lib.escapeShellArgs`, which always single-quotes its output -- there's
# no way to get a literal, shell-expandable `$HOME` through it (it would
# always resolve to whichever user owns the Nix build, not whoever runs
# the binary). Our own script instead resolves `$HOME` -- and does the
# one-time dotfolder migration -- at *invocation* time, as whichever user
# runs it. That means one shared wrapper in environment.systemPackages
# works correctly for every user on the system, with zero per-user Nix
# config: each user gets their own fake-home under their own $HOME the
# first time they run the app.
#
# To sandbox a new app: add an entry below with its package, the binary
# name to wrap, where its fake home should live (relative to $HOME), and
# which real-$HOME paths need migrating into it once.
let
  firejailHomeApps = {
    code = {
      package = pkgs.vscode;
      binary = "code";
      fakeHomeRel = ".local/share/vscode-home";
      migrate = [ ".vscode" ".config/Code" ];
    };

    claude = {
      package = pkgs.claude-code;
      binary = "claude";
      fakeHomeRel = ".local/share/claude-home";
      migrate = [ ".claude" ];
    };

    vesktop = {
      package = pkgs.vesktop;
      binary = "vesktop";
      fakeHomeRel = ".local/share/vesktop-home";
      migrate = [ ".config/vesktop" ];
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
      fakeHomeRel = ".local/share/steam-home";
      migrate = [ ".steam" ".local/share/Steam" ];
      extraFirejailArgs = [ "--noprofile" ];
    };
  };

  # Each app's .desktop file launches it via a bare command name (e.g.
  # `Exec=code %F`), resolved through $PATH -- so it picks up the wrapper
  # below automatically, with no need to copy/patch any .desktop file.

  mkWrapper =
    _name: app:
    (pkgs.writeShellScriptBin app.binary ''
      set -e
      fakeHome="$HOME/${app.fakeHomeRel}"
      mkdir -p "$fakeHome"

      ${lib.concatMapStrings (rel: ''
        from="$HOME/${rel}"
        to="$fakeHome/${rel}"
        if [ -e "$from" ] && [ ! -L "$from" ] && [ ! -e "$to" ]; then
          mkdir -p "$(dirname "$to")"
          mv "$from" "$to"
        fi
      '') app.migrate}

      exec /run/wrappers/bin/firejail --env=HOME="$fakeHome" ${lib.escapeShellArgs (app.extraFirejailArgs or [ ])} -- ${lib.getBin app.package}/bin/${app.binary} "$@"
    '').overrideAttrs
      (old: {
        # Takes precedence over the real package's same-named binary when
        # both land in environment.systemPackages.
        meta = old.meta // {
          priority = -1;
        };
      });
in
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "steam"
      "claude-code"
    ];

  programs.firejail.enable = true;

  environment.systemPackages =
    (lib.mapAttrsToList (_: app: app.package) firejailHomeApps)
    ++ (lib.mapAttrsToList mkWrapper firejailHomeApps);
}
