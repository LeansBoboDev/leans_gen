#!/usr/bin/env bash
#
# manual_update.sh - copies this repo's NixOS config into /etc/nixos,
# skipping kde.nix, users.nix and configuration.nix (which hold
# machine-specific settings you don't want overwritten on an
# already-installed system), and copying only the selected GPU driver
# file since intel.nix, amd.nix and nvidia.nix cannot coexist.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/etc/nixos"
DEST_DIR="/etc/nixos"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source config directory not found: $SOURCE_DIR" >&2
    exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
    echo "Destination $DEST_DIR not found." >&2
    exit 1
fi

CONFIG_FILE="$DEST_DIR/configuration.nix"

add_import() {
    local file="$1"
    local import_line="$2"
    if grep -qF "$import_line" "$file"; then
        echo "Import $import_line already present in $file, skipping."
        return
    fi
    sed -i "/\.\/users\.nix/a\\      ${import_line}" "$file"
    echo "Added $import_line to $file"
}

ensure_allow_unfree() {
    local file="$1"
    if grep -q "nixpkgs.config.allowUnfree" "$file"; then
        echo "nixpkgs.config.allowUnfree already set in $file, skipping."
        return
    fi
    sed -i "/networking\.hostName/i\\  nixpkgs.config.allowUnfree = true;\\n" "$file"
    echo "Added nixpkgs.config.allowUnfree = true; to $file"
}

SKIP_FILES=("kde.nix" "users.nix" "configuration.nix")

GPU_FILES=("intel.nix" "amd.nix" "nvidia.nix")
GPU_LABELS=("Intel" "AMD" "NVIDIA" "Skip (do not copy a GPU driver file)")

echo "==> Select your GPU driver (intel.nix, amd.nix and nvidia.nix cannot be copied together):"
select GPU_LABEL in "${GPU_LABELS[@]}"; do
    if [[ -n "${GPU_LABEL:-}" ]]; then
        break
    fi
    echo "Invalid option, try again."
done

case "$GPU_LABEL" in
    "Intel")
        SKIP_FILES+=("amd.nix" "nvidia.nix")
        if [[ -f "$CONFIG_FILE" ]]; then
            add_import "$CONFIG_FILE" "./intel.nix"
        fi
        ;;
    "AMD")
        SKIP_FILES+=("intel.nix" "nvidia.nix")
        if [[ -f "$CONFIG_FILE" ]]; then
            add_import "$CONFIG_FILE" "./amd.nix"
        fi
        ;;
    "NVIDIA")
        SKIP_FILES+=("intel.nix" "amd.nix")
        if [[ -f "$CONFIG_FILE" ]]; then
            add_import "$CONFIG_FILE" "./nvidia.nix"
            ensure_allow_unfree "$CONFIG_FILE"
        fi
        ;;
    *)
        SKIP_FILES+=("${GPU_FILES[@]}")
        ;;
esac

echo "==> Copying NixOS configuration files to $DEST_DIR..."
for f in "$SOURCE_DIR"/*; do
    name="$(basename "$f")"
    skip=false
    for skip_name in "${SKIP_FILES[@]}"; do
        if [[ "$name" == "$skip_name" ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == true ]]; then
        echo "Skipping $name"
        continue
    fi
    cp -v "$f" "$DEST_DIR/$name"
done

echo
echo "Done! Configuration updated at $DEST_DIR"
