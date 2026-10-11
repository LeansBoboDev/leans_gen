#!/usr/bin/env bash
#
# leans_gen.sh - interactive disk installer for NixOS
#
# Lists available disks, asks the user to pick one,
# partitions it (GPT: ESP + nixos), formats, mounts, and runs
# nixos-generate-config.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

echo "==> Available disks:"
echo
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E 'disk$' || true
echo

mapfile -t DISKS < <(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print $1}')

if [[ ${#DISKS[@]} -eq 0 ]]; then
    echo "No disks found." >&2
    exit 1
fi

echo "Select the disk where NixOS will be installed:"
select DISK_NAME in "${DISKS[@]}"; do
    if [[ -n "${DISK_NAME:-}" ]]; then
        break
    fi
    echo "Invalid option, try again."
done

DISK="/dev/${DISK_NAME}"

if [[ ! -b "$DISK" ]]; then
    echo "Disk $DISK not found." >&2
    exit 1
fi

# nvme/mmcblk use a 'p' suffix before the partition number (e.g. nvme0n1p1)
if [[ "$DISK_NAME" =~ ^(nvme|mmcblk) ]]; then
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
fi

echo
echo "!!! WARNING !!!"
echo "All data on $DISK will be ERASED."
lsblk "$DISK"
echo
read -rp "Type 'yes' to confirm and continue: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cancelled."
    exit 1
fi

echo "==> Partitioning $DISK..."
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart nixos ext4 1GiB 100%

partprobe "$DISK"
udevadm settle

echo "==> Formatting partitions..."
mkfs.fat -F 32 -n BOOT "$PART_BOOT"
mkfs.ext4 -L nixos "$PART_ROOT"

echo "==> Mounting partitions..."
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot

echo "==> Generating NixOS configuration..."
nixos-generate-config --root /mnt

echo
echo "Done! Disk: $DISK"
echo "Boot: $PART_BOOT  |  Root: $PART_ROOT"
echo "Configuration generated at /mnt/etc/nixos"
