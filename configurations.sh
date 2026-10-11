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

# ---------------------------------------------------------------------------
# Night Color
# ---------------------------------------------------------------------------

KDE_FILE="$DEST_DIR/kde.nix"

echo
echo "==> Night Color (blue light filter)"
read -rp "Enable Night Color? [Y/n]: " NC_ENABLE

if [[ "$NC_ENABLE" =~ ^[Nn] ]]; then
    NC_ACTIVE="false"
else
    NC_ACTIVE="true"
    read -rp "Color temperature in Kelvin, lower = warmer (2500-6500) [default: 4100]: " NC_TEMP
    NC_TEMP="${NC_TEMP:-4100}"
    if ! [[ "$NC_TEMP" =~ ^[0-9]+$ ]] || (( NC_TEMP < 2500 || NC_TEMP > 6500 )); then
        echo "Invalid value, using default 4100."
        NC_TEMP=4100
    fi
fi

if [[ -f "$KDE_FILE" ]]; then
    # Drop the commented template lines shipped in the repo, then insert
    # the real values right after the kwinrc.Xwayland.Scale anchor.
    sed -i '/# kwinrc\.NightColor\./d' "$KDE_FILE"
    if [[ "$NC_ACTIVE" == "true" ]]; then
        sed -i "/kwinrc\.Xwayland\.Scale = 1;/a\\        kwinrc.NightColor.Active = true;\\n        kwinrc.NightColor.Mode = \"Constant\";\\n        kwinrc.NightColor.NightTemperature = ${NC_TEMP};" "$KDE_FILE"
    else
        sed -i "/kwinrc\.Xwayland\.Scale = 1;/a\\        kwinrc.NightColor.Active = false;" "$KDE_FILE"
    fi
else
    echo "Warning: $KDE_FILE not found, skipping Night Color configuration."
fi

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

USERS_FILE="$DEST_DIR/users.nix"

USERNAMES=()
DESCRIPTIONS=()
ADMIN_FLAGS=()

echo
echo "==> User accounts"
while true; do
    read -rp "Username to create (leave empty to finish): " USERNAME
    if [[ -z "$USERNAME" ]]; then
        if [[ ${#USERNAMES[@]} -eq 0 ]]; then
            echo "You must create at least one user."
            continue
        fi
        break
    fi
    if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Invalid username. Use lowercase letters, digits, '-' and '_', starting with a letter or '_'."
        continue
    fi
    if printf '%s\n' "${USERNAMES[@]}" | grep -qx "$USERNAME"; then
        echo "User '$USERNAME' was already added."
        continue
    fi

    read -rp "Full name for $USERNAME [default: $USERNAME]: " DESCRIPTION
    DESCRIPTION="${DESCRIPTION:-$USERNAME}"
    DESCRIPTION="${DESCRIPTION//\\/\\\\}"
    DESCRIPTION="${DESCRIPTION//\"/\\\"}"

    read -rp "Should $USERNAME be an administrator (wheel group)? [Y/n]: " IS_ADMIN

    USERNAMES+=("$USERNAME")
    DESCRIPTIONS+=("$DESCRIPTION")
    if [[ "$IS_ADMIN" =~ ^[Nn] ]]; then
        ADMIN_FLAGS+=("no")
    else
        ADMIN_FLAGS+=("yes")
    fi
done

echo "==> Writing $USERS_FILE"
{
    echo "{ pkgs, ... }:"
    echo
    echo "{"
    for i in "${!USERNAMES[@]}"; do
        uname="${USERNAMES[$i]}"
        desc="${DESCRIPTIONS[$i]}"
        admin="${ADMIN_FLAGS[$i]}"

        groups=(networkmanager audio video vboxusers)
        if [[ "$admin" == "yes" ]]; then
            groups=(wheel "${groups[@]}")
        fi
        groups_nix=""
        for g in "${groups[@]}"; do
            groups_nix+="\"$g\" "
        done
        groups_nix="${groups_nix% }"

        echo "  users.users.$uname = {"
        echo "    isNormalUser = true;"
        echo "    description = \"$desc\";"
        echo "    extraGroups = [ $groups_nix ];"
        echo "    # Set password after install with: passwd $uname"
        echo "    # Or generate a hash with: mkpasswd -m sha-512"
        echo "    # initialHashedPassword = \"HASH_HERE\";"
        echo "  };"
        echo
    done
    echo "}"
} > "$USERS_FILE"

echo
echo "Configuration copied and updated at $DEST_DIR"

# ---------------------------------------------------------------------------
# Auto-mount disks
# ---------------------------------------------------------------------------

MOUNT_POINTS_FILE="$DEST_DIR/mount-points.nix"

echo
echo "==> Additional disks to auto-mount at boot"

mapfile -t CANDIDATE_PARTS < <(lsblk -rno NAME,TYPE,MOUNTPOINT | awk '$2=="part"{print $1"|"$3}')

MOUNT_ENTRIES=()

for entry in "${CANDIDATE_PARTS[@]}"; do
    PART_NAME="${entry%%|*}"
    PART_MOUNT="${entry#*|}"
    DEV="/dev/$PART_NAME"

    # Skip partitions already in use for this install (mounted under /mnt)
    case "$PART_MOUNT" in
        /mnt|/mnt/*) continue ;;
    esac

    FSTYPE="$(lsblk -no FSTYPE "$DEV" 2>/dev/null)"
    [[ -z "$FSTYPE" || "$FSTYPE" == "swap" ]] && continue

    UUID="$(blkid -s UUID -o value "$DEV" 2>/dev/null || true)"
    [[ -z "$UUID" ]] && continue

    LABEL="$(lsblk -no LABEL "$DEV" 2>/dev/null)"
    SIZE="$(lsblk -no SIZE "$DEV" 2>/dev/null)"

    DESC="$DEV ($SIZE, $FSTYPE${LABEL:+, label: $LABEL})"
    read -rp "Auto-mount $DESC at boot? [y/N]: " DO_MOUNT
    if [[ ! "$DO_MOUNT" =~ ^[Yy] ]]; then
        continue
    fi

    DEFAULT_MP="/mnt/$(echo "${LABEL:-$PART_NAME}" | tr '[:upper:] ' '[:lower:]-')"
    read -rp "Mount point for $DEV [default: $DEFAULT_MP]: " MP
    MP="${MP:-$DEFAULT_MP}"

    case "$FSTYPE" in
        ntfs) NIX_FSTYPE="ntfs-3g" ;;
        *) NIX_FSTYPE="$FSTYPE" ;;
    esac

    MOUNT_ENTRIES+=("$MP|$UUID|$NIX_FSTYPE")
done

echo "==> Writing $MOUNT_POINTS_FILE"
{
    echo "{ ... }:"
    echo
    echo "{"
    for entry in "${MOUNT_ENTRIES[@]}"; do
        IFS='|' read -r mp uuid fstype <<< "$entry"
        echo "  fileSystems.\"$mp\" = {"
        echo "    device = \"/dev/disk/by-uuid/$uuid\";"
        echo "    fsType = \"$fstype\";"
        echo "    options = [ \"nofail\" ];"
        echo "  };"
        echo
    done
    echo "}"
} > "$MOUNT_POINTS_FILE"

add_import "$CONFIG_FILE" "./mount-points.nix"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

echo
echo "==> Ready to install NixOS using this configuration."
read -rp "Run nixos-install now? [Y/n]: " DO_INSTALL

if [[ "$DO_INSTALL" =~ ^[Nn] ]]; then
    echo "Skipping install. Run 'nixos-install' manually when ready."
    exit 0
fi

if nixos-install; then
    echo
    echo "==> Install succeeded."
    # kde.nix stays wired into configuration.nix's imports permanently (it
    # also carries session-wide environment variables like XCURSOR_THEME
    # that need to keep applying on every rebuild, not just at first boot).
    echo
    echo "Done! Set a password for each created user, then reboot:"
    for uname in "${USERNAMES[@]}"; do
        echo "  nixos-enter --root /mnt -c 'passwd $uname'"
    done
else
    echo "nixos-install failed. $CONFIG_FILE was left unchanged so you can fix the issue and retry." >&2
    exit 1
fi
