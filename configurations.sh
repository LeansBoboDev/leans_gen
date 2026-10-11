#!/usr/bin/env bash
#
# configurations.sh - copies this repo's NixOS config into /mnt/etc/nixos
# and interactively configures it. Run this after leans_gen.sh.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/etc/nixos"
DEST_DIR="/mnt/etc/nixos"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source config directory not found: $SOURCE_DIR" >&2
    exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
    echo "Destination $DEST_DIR not found. Did you run leans_gen.sh first?" >&2
    exit 1
fi

echo "==> Copying NixOS configuration files to $DEST_DIR..."
for f in "$SOURCE_DIR"/*; do
    name="$(basename "$f")"
    if [[ "$name" == "hardware-configuration.nix" ]]; then
        echo "Skipping $name (keeping the machine-generated version)"
        continue
    fi
    cp -v "$f" "$DEST_DIR/$name"
done

CONFIG_FILE="$DEST_DIR/configuration.nix"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "configuration.nix not found at $CONFIG_FILE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Timezone
# ---------------------------------------------------------------------------

TZ_LABELS=(
    "UTC"
    "New York (US Eastern)"
    "Chicago (US Central)"
    "Denver (US Mountain)"
    "Los Angeles (US Pacific)"
    "Sao Paulo"
    "London"
    "Amsterdam / Berlin / Paris"
    "Moscow"
    "Dubai"
    "Kolkata (India)"
    "Shanghai"
    "Tokyo"
    "Sydney"
    "Manual (type your own)"
)
TZ_VALUES=(
    "UTC"
    "America/New_York"
    "America/Chicago"
    "America/Denver"
    "America/Los_Angeles"
    "America/Sao_Paulo"
    "Europe/London"
    "Europe/Amsterdam"
    "Europe/Moscow"
    "Asia/Dubai"
    "Asia/Kolkata"
    "Asia/Shanghai"
    "Asia/Tokyo"
    "Australia/Sydney"
    "MANUAL"
)

echo
echo "==> Select your timezone:"
TZ_CHOICE=""
select TZ_LABEL in "${TZ_LABELS[@]}"; do
    if [[ -n "${TZ_LABEL:-}" ]]; then
        TZ_CHOICE="${TZ_VALUES[$((REPLY-1))]}"
        break
    fi
    echo "Invalid option, try again."
done

if [[ "$TZ_CHOICE" == "MANUAL" ]]; then
    read -rp "Enter timezone (e.g. Europe/Amsterdam): " TZ_CHOICE
    if command -v timedatectl >/dev/null 2>&1; then
        if ! timedatectl list-timezones | grep -qx "$TZ_CHOICE"; then
            echo "Warning: '$TZ_CHOICE' is not a recognized timezone, proceeding anyway."
        fi
    fi
fi

echo "==> Setting timezone to $TZ_CHOICE"
sed -i "s|time\.timeZone = \".*\";|time.timeZone = \"$TZ_CHOICE\";|" "$CONFIG_FILE"

# ---------------------------------------------------------------------------
# GPU driver
# ---------------------------------------------------------------------------

add_import() {
    local file="$1"
    local import_line="$2"
    if grep -qF "$import_line" "$file"; then
        echo "Import $import_line already present, skipping."
        return
    fi
    sed -i "/\.\/users\.nix/a\\      ${import_line}" "$file"
}

ensure_allow_unfree() {
    local file="$1"
    if grep -q "nixpkgs.config.allowUnfree" "$file"; then
        echo "nixpkgs.config.allowUnfree already set, skipping."
        return
    fi
    sed -i "/networking\.hostName/i\\  nixpkgs.config.allowUnfree = true;\\n" "$file"
}

GPU_LABELS=(
    "Intel"
    "AMD"
    "NVIDIA"
    "Skip (do not configure a GPU driver)"
)

echo
echo "==> Select your GPU driver:"
select GPU_LABEL in "${GPU_LABELS[@]}"; do
    if [[ -n "${GPU_LABEL:-}" ]]; then
        break
    fi
    echo "Invalid option, try again."
done

case "$GPU_LABEL" in
    "Intel")
        add_import "$CONFIG_FILE" "./intel.nix"
        ;;
    "AMD")
        add_import "$CONFIG_FILE" "./amd.nix"
        ;;
    "NVIDIA")
        add_import "$CONFIG_FILE" "./nvidia.nix"
        ensure_allow_unfree "$CONFIG_FILE"
        ;;
    "Skip (do not configure a GPU driver)")
        echo "Skipping GPU driver configuration."
        ;;
esac

echo
echo "Done! Configuration copied and updated at $DEST_DIR"
