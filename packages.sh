#!/usr/bin/env bash
#
# packages.sh - adds or removes entries in etc/nixos/packages.nix.
#
# Edits THIS REPO's copy, never /etc/nixos directly -- run manual_update.sh
# afterwards to push the change to the live system, then rebuild.
#
# Usage:
#   ./packages.sh list                     # show sections and their packages
#   ./packages.sh add krita vlc            # prompts for the target section
#   ./packages.sh add -s Gaming lutris     # section given up front
#   ./packages.sh add -s "Fonts" fira-code # unknown section is created
#   ./packages.sh remove krita vlc
#
# Package names are checked against nixpkgs before being added, so a typo
# is caught here instead of halfway through a rebuild (skip with -n).
# After editing, the file is validated with `nix-instantiate --parse`; on
# failure the original is restored and nothing is lost.
#
# Only simple one-name-per-line entries can be removed. Multi-line
# expressions (the wrapOBS block, the opencode writeShellScriptBin) are
# reported and left for you to edit by hand -- deleting them blindly would
# corrupt the file.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root (it edits the repo, and root would leave root-owned files behind)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGS_FILE="$SCRIPT_DIR/etc/nixos/packages.nix"

if [[ ! -f "$PKGS_FILE" ]]; then
    echo "packages.nix not found at $PKGS_FILE" >&2
    exit 1
fi

usage() {
    awk 'NR > 2 { if ($0 !~ /^#/) exit; sub(/^#[[:space:]]?/, ""); print }' "${BASH_SOURCE[0]}"
    exit "${1:-1}"
}

# ---------------------------------------------------------------------------
# Shared awk helper
# ---------------------------------------------------------------------------
#
# The systemPackages list is found by bracket depth rather than by matching
# a closing `];` literally, because the list contains nested lists (wrapOBS's
# `plugins = ... [ ... ];`) whose closer would otherwise be mistaken for the
# end of the block.
#
# A line counts as a section header when it is a comment that directly
# follows a blank line (or opens the block). That distinguishes `# Gaming`
# from in-list explanatory comments such as the two lines above the opencode
# entry, which follow a package line instead.

read -r -d '' SCAN_AWK <<'AWK_EOF' || true
function flush_section() {
    if (section != "") {
        printf "%s\t%d\t%d\t%s\n", section, sec_start, last_content, indent
    }
}
{ lines[NR] = $0 }
/environment\.systemPackages/ { in_block = 1 }
in_block {
    opens = gsub(/\[/, "&")
    closes = gsub(/\]/, "&")
    depth += opens - closes
    if (depth == 0 && started) { block_end = NR; in_block = 0; next }
    if (opens > 0 && !started) { started = 1; block_start = NR; prev_blank = 1; next }
}
started && in_block {
    if ($0 ~ /^[[:space:]]*$/) { prev_blank = 1; next }
    if ($0 ~ /^[[:space:]]*#/ && prev_blank) {
        flush_section()
        section = $0
        sub(/^[[:space:]]*#[[:space:]]*/, "", section)
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH)
        sec_start = NR
        last_content = NR
    } else {
        last_content = NR
    }
    prev_blank = 0
}
END {
    flush_section()
    printf "__BLOCK__\t%d\t%d\t\n", block_start, block_end
}
AWK_EOF

scan() { awk "$SCAN_AWK" "$PKGS_FILE"; }

section_names() { scan | grep -v '^__BLOCK__' | cut -f1; }

block_end_line() { scan | awk -F'\t' '$1 == "__BLOCK__" { print $3 }'; }

# Prints "start<TAB>last_content<TAB>indent" for a section, or nothing.
section_info() {
    scan | awk -F'\t' -v want="$1" '$1 == want { print $2 "\t" $3 "\t" $4 }'
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

valid_name() {
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]
}

exists_in_nixpkgs() {
    local pkg="$1"
    if ! command -v nix-instantiate >/dev/null 2>&1; then
        return 2
    fi
    local out
    if ! out="$(nix-instantiate --eval -E \
        "let p = import <nixpkgs> { config.allowUnfree = true; }; in p.lib.hasAttrByPath (p.lib.splitString \".\" \"$pkg\") p" \
        2>/dev/null)"; then
        return 2
    fi
    [[ "$out" == "true" ]]
}

# Restores the backup if the edited file no longer parses as Nix.
check_or_restore() {
    local backup="$1"
    if ! command -v nix-instantiate >/dev/null 2>&1; then
        echo "Warning: nix-instantiate not found, skipping syntax check." >&2
        rm -f "$backup"
        return 0
    fi
    if nix-instantiate --parse "$PKGS_FILE" >/dev/null 2>&1; then
        rm -f "$backup"
        return 0
    fi
    mv "$backup" "$PKGS_FILE"
    echo "Error: the edit produced an invalid packages.nix. Original restored, nothing changed." >&2
    exit 1
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

cmd_list() {
    local name start last indent
    while IFS=$'\t' read -r name start last indent; do
        [[ "$name" == "__BLOCK__" ]] && continue
        echo "== $name"
        sed -n "$((start + 1)),${last}p" "$PKGS_FILE" | sed 's/^[[:space:]]*/   /'
        echo
    done < <(scan)
}

# ---------------------------------------------------------------------------
# add
# ---------------------------------------------------------------------------

pick_section() {
    local names=()
    mapfile -t names < <(section_names)
    if [[ ${#names[@]} -eq 0 ]]; then
        echo "No sections found in $PKGS_FILE -- pass one with -s." >&2
        exit 1
    fi
    if [[ ! -t 0 ]]; then
        echo "No section given and no terminal to ask on. Use -s <section>." >&2
        exit 1
    fi
    echo "==> Which section should it go in?" >&2
    local choice
    select choice in "${names[@]}"; do
        if [[ -n "${choice:-}" ]]; then
            echo "$choice"
            return
        fi
        echo "Invalid option, try again." >&2
    done
}

create_section() {
    local name="$1" end backup
    end="$(block_end_line)"
    backup="$(mktemp)"
    cp "$PKGS_FILE" "$backup"
    # Insert a blank line plus the new header just above the block's `];`.
    awk -v end="$end" -v name="$name" '
        NR == end { print ""; print "    # " name }
        { print }
    ' "$backup" > "$PKGS_FILE"
    check_or_restore "$backup"
    echo "Created section '# $name'."
}

cmd_add() {
    local section="" check=1
    local pkgs=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--section) section="${2:-}"; shift 2 ;;
            -n|--no-check) check=0; shift ;;
            -h|--help) usage 0 ;;
            -*) echo "Unknown flag: $1" >&2; usage ;;
            *) pkgs+=("$1"); shift ;;
        esac
    done

    [[ ${#pkgs[@]} -eq 0 ]] && { echo "No packages given." >&2; usage; }

    for pkg in "${pkgs[@]}"; do
        if ! valid_name "$pkg"; then
            echo "Refusing '$pkg': not a plain attribute name. Add complex expressions by hand." >&2
            exit 1
        fi
    done

    if [[ -z "$section" ]]; then
        section="$(pick_section)"
    fi
    if [[ -z "$(section_info "$section")" ]]; then
        echo "Section '$section' does not exist yet."
        create_section "$section"
    fi

    for pkg in "${pkgs[@]}"; do
        if grep -qE "^[[:space:]]*${pkg}([[:space:]]*#.*)?$" "$PKGS_FILE"; then
            echo "Already present: $pkg (skipping)"
            continue
        fi

        if [[ $check -eq 1 ]]; then
            echo "==> Checking $pkg against nixpkgs..."
            set +e
            exists_in_nixpkgs "$pkg"
            local rc=$?
            set -e
            case $rc in
                0) ;;
                1)
                    echo "Error: '$pkg' is not an attribute in nixpkgs. Check the name at https://search.nixos.org/packages (or re-run with -n)." >&2
                    exit 1
                    ;;
                *) echo "Warning: could not query nixpkgs, adding '$pkg' unchecked." >&2 ;;
            esac
        fi

        local info start last indent backup
        info="$(section_info "$section")"
        IFS=$'\t' read -r start last indent <<<"$info"
        backup="$(mktemp)"
        cp "$PKGS_FILE" "$backup"
        awk -v at="$last" -v pkg="$pkg" -v indent="$indent" '
            { print }
            NR == at { print indent pkg }
        ' "$backup" > "$PKGS_FILE"
        check_or_restore "$backup"
        echo "Added $pkg to '# $section'."
    done
}

# ---------------------------------------------------------------------------
# remove
# ---------------------------------------------------------------------------

cmd_remove() {
    local pkgs=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage 0 ;;
            -*) echo "Unknown flag: $1" >&2; usage ;;
            *) pkgs+=("$1"); shift ;;
        esac
    done

    [[ ${#pkgs[@]} -eq 0 ]] && { echo "No packages given." >&2; usage; }

    for pkg in "${pkgs[@]}"; do
        if ! valid_name "$pkg"; then
            echo "Refusing '$pkg': not a plain attribute name." >&2
            exit 1
        fi

        local matches backup
        matches="$(grep -nE "^[[:space:]]*${pkg}([[:space:]]*#.*)?$" "$PKGS_FILE" || true)"
        if [[ -z "$matches" ]]; then
            # Distinguish "not there at all" from "there, but inside an expression".
            if grep -nqE "\\b${pkg}\\b" "$PKGS_FILE"; then
                echo "Not removed: '$pkg' only appears inside a larger expression --" >&2
                grep -nE "\\b${pkg}\\b" "$PKGS_FILE" >&2
                echo "Edit those lines by hand." >&2
                exit 1
            fi
            echo "Not found: $pkg (skipping)"
            continue
        fi

        backup="$(mktemp)"
        cp "$PKGS_FILE" "$backup"
        grep -vE "^[[:space:]]*${pkg}([[:space:]]*#.*)?$" "$backup" > "$PKGS_FILE"
        check_or_restore "$backup"
        echo "Removed $pkg."
    done
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

[[ $# -eq 0 ]] && usage

CMD="$1"
shift

case "$CMD" in
    list)   cmd_list ;;
    add)    cmd_add "$@" ;;
    remove|rm) cmd_remove "$@" ;;
    -h|--help|help) usage 0 ;;
    *) echo "Unknown command: $CMD" >&2; usage ;;
esac

if [[ "$CMD" != "list" ]]; then
    echo
    if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$SCRIPT_DIR" --no-pager diff -- etc/nixos/packages.nix
    fi
    echo "Repo updated. To apply it to the running system:"
    echo "  sudo $SCRIPT_DIR/manual_update.sh && sudo nixos-rebuild switch"
fi
