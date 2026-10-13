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
      # Firejail's bundled vesktop.profile does `whitelist
      # ${HOME}/.config/vesktop`. Firejail's own ${HOME} macro is resolved
      # from /etc/passwd -- it ignores our --env=HOME= override -- so that
      # whitelist targets the *real* $HOME/.config/vesktop and puts the rest
      # of the real $HOME tree (including our fake home, which lives under
      # it) behind an empty, session-only overlay. The app happily writes
      # its settings there during the session, but none of it survives past
      # the sandbox exiting. --noprofile skips the bundled profile (and its
      # whitelist) the same way steam does below.
      extraFirejailArgs = [ "--noprofile" ];
    };

    sunshine = {
      package = pkgs.sunshine;
      binary = "sunshine";
      fakeHomeRel = ".local/share/sunshine-home";
      migrate = [ ".config/sunshine" ];
      # Unlike the other apps here, Sunshine isn't just sandboxed for a fake
      # $HOME -- it fundamentally needs host-level access to capture the
      # screen and inject input: firejail's default.profile (applied because
      # no bundled sunshine.profile exists) drops CAP_SYS_ADMIN, hides
      # /dev/uinput and the DRI/NVIDIA device nodes behind private-dev, and
      # blocks /dev/input via noinput. Without them Sunshine can't grab a
      # display (every encoder fails to init) or create the virtual
      # mouse/keyboard moonlight clients need to control this PC.
      # --noprofile skips default.profile the same way it does for
      # steam/vesktop above, restoring caps and real /dev access.
      extraFirejailArgs = [ "--noprofile" ];
      # KWin's screencast portal checks the requesting process's exe path
      # against its permission desktop file; running sunshine through this
      # firejail wrapper changes that path enough that the check fails
      # (zkde_screencast_unstable_v1 not found in registry), so every
      # encoder falls through to "Unable to find display". Sunshine's own
      # log points at this exact env var to bypass the check.
      extraEnv = [ "KWIN_WAYLAND_NO_PERMISSION_CHECKS=1" ];
    };

    godot = {
      package = pkgs.godot;
      binary = "godot";
      fakeHomeRel = ".local/share/godot-home";
      migrate = [ ".cache/godot" ".config/godot" ".local/share/godot" ];
    };

    moonlight = {
      package = pkgs.moonlight-qt;
      binary = "moonlight";
      fakeHomeRel = ".local/share/moonlight-home";
      migrate = [
        ".config/Moonlight Game Streaming Project"
        ".local/share/Moonlight Game Streaming Project"
        ".cache/Moonlight Game Streaming Project"
      ];
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
      # Steam (and anything it launches, including games/Proton) inherits
      # the fake $HOME above, so MangoHud's default per-user config lookup
      # ($HOME/.config/MangoHud/MangoHud.conf) would miss the config
      # home-manager writes into the real $HOME. Point it there directly
      # instead -- this is a raw, unescaped env assignment (unlike
      # extraFirejailArgs) because $HOME needs to expand at invocation
      # time, not build time.
      extraEnv = [ ''MANGOHUD_CONFIGFILE="$HOME/.config/MangoHud/MangoHud.conf"'' ];
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

      exec /run/wrappers/bin/firejail --env=HOME="$fakeHome" ${lib.concatMapStrings (e: "--env=" + e + " ") (app.extraEnv or [ ])}${lib.escapeShellArgs (app.extraFirejailArgs or [ ])} -- ${lib.getBin app.package}/bin/${app.binary} "$@"
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
