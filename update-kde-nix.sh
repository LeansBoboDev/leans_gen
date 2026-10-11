#!/usr/bin/env bash
#
# update-kde-nix.sh - bakes your LIVE KDE settings into etc/nixos/kde.nix.
#
# Workflow: change whatever you want in KDE System Settings, then run this
# script. It dumps your current config with plasma-manager's rc2nix,
# drops the stuff that should never be hardcoded (hardware-specific input
# device entries, random per-install UUIDs — see etc/nixos/KDE.md), and
# replaces the `shortcuts` and `configFile` blocks in kde.nix with the
# result. Everything else in kde.nix (input.mice, the panels example,
# comments) is left alone.
#
# `nix-instantiate --parse` validates the rewritten file before this
# script keeps it; on failure the original kde.nix is restored.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user (it reads your live KDE config in \$HOME), not root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KDE_NIX="$SCRIPT_DIR/etc/nixos/kde.nix"

if [[ ! -f "$KDE_NIX" ]]; then
    echo "kde.nix not found at $KDE_NIX" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DUMP="$WORKDIR/dump.nix"

echo "==> Dumping current KDE config with rc2nix..."
nix --extra-experimental-features "nix-command flakes" run \
    github:nix-community/plasma-manager#rc2nix > "$DUMP"

# Lines that should never be baked in permanently, per etc/nixos/KDE.md:
#   - hardware-specific per-device entries (kcminputrc."Libinput/<vendorId>/...")
#   - random per-install UUIDs (activity ids, kwinrc Tiling layouts, etc.)
EXCLUDE_RE='kcminputrc\."Libinput/|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# rc2nix (without -n) emits exactly one flat "a.b.c = value;" statement per
# line inside `shortcuts`/`configFile`, with no nested braces in between -
# so grabbing everything between the opening line and the next bare "};"
# is a safe, exact extraction (no brace-counting needed).
extract_section() {
    local section="$1" file="$2"
    awk -v sec="$section" '
        $0 ~ "^[[:space:]]*" sec "[[:space:]]*=[[:space:]]*\\{[[:space:]]*$" { grab=1; next }
        grab && $0 ~ "^[[:space:]]*\\};[[:space:]]*$" { exit }
        grab { print }
    ' "$file" | grep -vE "$EXCLUDE_RE" || true
}

# Re-indent two extra spaces: kde.nix nests shortcuts/configFile one level
# deeper (under home-manager.users.leans.programs.plasma) than rc2nix's
# raw top-level dump does.
SHORTCUTS_CONTENT="$WORKDIR/shortcuts.nix"
CONFIGFILE_CONTENT="$WORKDIR/configFile.nix"
extract_section "shortcuts" "$DUMP" | sed 's/^/  /' > "$SHORTCUTS_CONTENT"
extract_section "configFile" "$DUMP" | sed 's/^/  /' > "$CONFIGFILE_CONTENT"

count_nonblank() {
    grep -c '[^[:space:]]' "$1" || true
}

# rc2nix silently skips any rc file it can't find (e.g. if $HOME is wrong, or
# this runs outside your real KDE session) and happily prints empty
# `shortcuts {}` / `configFile {}` blocks with exit code 0. A lone blank line
# inside such a block is enough to pass a plain "-s" non-empty check, so we
# instead require the new content to have at least half as many non-blank
# lines as what's already in kde.nix - a near-empty dump gets caught here
# instead of silently gutting your real config.
NEW_SHORTCUTS_LINES="$(count_nonblank "$SHORTCUTS_CONTENT")"
NEW_CONFIGFILE_LINES="$(count_nonblank "$CONFIGFILE_CONTENT")"
OLD_SHORTCUTS_LINES="$(extract_section "shortcuts" "$KDE_NIX" | count_nonblank -)"
OLD_CONFIGFILE_LINES="$(extract_section "configFile" "$KDE_NIX" | count_nonblank -)"

if [[ "$NEW_SHORTCUTS_LINES" -eq 0 || "$NEW_CONFIGFILE_LINES" -eq 0 ]]; then
    echo "Could not extract shortcuts/configFile from rc2nix output - aborting without touching kde.nix." >&2
    exit 1
fi

if [[ "$OLD_SHORTCUTS_LINES" -gt 0 && "$NEW_SHORTCUTS_LINES" -lt $((OLD_SHORTCUTS_LINES / 2)) ]] ||
   [[ "$OLD_CONFIGFILE_LINES" -gt 0 && "$NEW_CONFIGFILE_LINES" -lt $((OLD_CONFIGFILE_LINES / 2)) ]]; then
    echo "rc2nix output looks suspiciously small (shortcuts: $OLD_SHORTCUTS_LINES -> $NEW_SHORTCUTS_LINES lines, configFile: $OLD_CONFIGFILE_LINES -> $NEW_CONFIGFILE_LINES lines)." >&2
    echo "This usually means rc2nix couldn't see your real KDE config (wrong \$HOME, sandboxed shell, missing rc files)." >&2
    echo "Aborting without touching kde.nix - run this script directly in your own terminal, not through an agent's sandbox." >&2
    exit 1
fi

replace_section() {
    local section="$1" content_file="$2" target="$3" out="$4"
    awk -v sec="$section" -v contentfile="$content_file" '
        BEGIN {
            content = ""
            while ((getline line < contentfile) > 0) {
                content = content line "\n"
            }
        }
        $0 ~ "^[[:space:]]*" sec "[[:space:]]*=[[:space:]]*\\{[[:space:]]*$" {
            print
            printf "%s", content
            grab = 1
            next
        }
        grab && $0 ~ "^[[:space:]]*\\};[[:space:]]*$" {
            print
            grab = 0
            next
        }
        grab { next }
        { print }
    ' "$target" > "$out"
}

BACKUP="$WORKDIR/kde.nix.orig"
cp "$KDE_NIX" "$BACKUP"

STEP1="$WORKDIR/kde.step1.nix"
STEP2="$WORKDIR/kde.step2.nix"
replace_section "shortcuts" "$SHORTCUTS_CONTENT" "$KDE_NIX" "$STEP1"
replace_section "configFile" "$CONFIGFILE_CONTENT" "$STEP1" "$STEP2"

sed -i "s/# Last refreshed: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}/# Last refreshed: $(date +%F)/" "$STEP2"

cp "$STEP2" "$KDE_NIX"

echo "==> Validating Nix syntax..."
if ! nix-instantiate --parse "$KDE_NIX" > /dev/null; then
    echo "Generated kde.nix failed to parse - restoring original." >&2
    cp "$BACKUP" "$KDE_NIX"
    exit 1
fi

echo
echo "Done! kde.nix updated at $KDE_NIX"
echo "Review the diff (git diff etc/nixos/kde.nix) before committing."
