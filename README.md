# NixOS Configurations

NixOS configuration repository. Includes setups for KDE desktop, ARM servers, and Docker images for game servers.

## Installation — KDE Desktop

### 1. Download and flash the ISO

Download the **Minimal ISO** from [nixos.org/download](https://nixos.org/download) (NixOS → Minimal ISO image).

Flash to a USB drive (replace `/dev/sdX` with your drive):

```bash
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### 2. Boot and connect to the internet

Boot from the USB drive. In the terminal that appears:

**Ethernet:** works automatically.

**Wi-Fi:**
```bash
# List available networks
nmcli device wifi list

# Connect
nmcli device wifi connect "NETWORK_NAME" password "PASSWORD"
```

Test the connection:
```bash
ping -c 3 nixos.org
```

### 3. Partition the disk

> Replace `/dev/sda` with your disk. Use `lsblk` to identify it.

**UEFI (recommended for modern PCs):**
```bash
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart primary 512MB 100%

sudo mkfs.fat -F32 -n boot /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2
```

**BIOS/Legacy (older PCs):**
```bash
sudo parted /dev/sda -- mklabel msdos
sudo parted /dev/sda -- mkpart primary 1MB 100%

sudo mkfs.ext4 -L nixos /dev/sda1
```

### 4. Mount and generate hardware configuration

```bash
# UEFI
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

# BIOS/Legacy
sudo mount /dev/disk/by-label/nixos /mnt
```

Generate hardware configuration (auto-detects your devices):
```bash
sudo nixos-generate-config --root /mnt
```

### 5. Download and apply the configurations

```bash
# Install git temporarily
nix-shell -p git

# Clone the repository
git clone https://github.com/LeandroTheDev/leans_gen /tmp/leans_gen

# Copy the KDE desktop configuration (skip hardware-configuration.nix — already generated)
cp /tmp/leans_gen/configurations/desktop_kde/etc/nixos/configuration.nix /mnt/etc/nixos/
cp /tmp/leans_gen/configurations/desktop_kde/etc/nixos/packages.nix      /mnt/etc/nixos/
cp /tmp/leans_gen/configurations/desktop_kde/etc/nixos/users.nix         /mnt/etc/nixos/
cp /tmp/leans_gen/configurations/desktop_kde/etc/nixos/nvidia.nix        /mnt/etc/nixos/
```

### 6. Customize before installing

**Required — edit `users.nix`:** replace `leans` with your username.

```bash
nano /mnt/etc/nixos/users.nix
```

**Optional — enable Nvidia drivers:** if you have an Nvidia GPU, open `configuration.nix` and uncomment the line:

```bash
nano /mnt/etc/nixos/configuration.nix
```

```nix
# Change this:
# ./nvidia.nix

# To this:
./nvidia.nix
```

**Optional — BIOS/Legacy boot:** if your PC does not use UEFI, edit `configuration.nix` and swap the bootloader:

```nix
# Comment these lines:
# boot.loader.systemd-boot.enable = true;
# boot.loader.efi.canTouchEfiVariables = true;

# And uncomment these (replace /dev/sda with your disk):
boot.loader.grub.enable = true;
boot.loader.grub.device = "/dev/sda";
```

### 7. Install

```bash
sudo nixos-install
```

You will be prompted for the root password. After the installation finishes:

```bash
sudo reboot
```

### 8. Post-installation

After rebooting and logging into KDE, open a terminal (Konsole) and set your user password:

```bash
passwd
```

---

## Maintenance

**Update the system:**
```bash
sudo nix-channel --update
sudo nixos-rebuild switch
```

**Clean old packages:**
```bash
sudo nix-collect-garbage -d
```

**Repair corrupted packages:**
```bash
sudo nix-store --verify --check-contents --repair
```

---

## Repository structure

```
configurations/
  desktop_kde/              # KDE Plasma 6 desktop
  arm_server/               # Headless ARM server
  arm_server_emulation/     # ARM server with x86 emulation
  example_nix/              # Reusable standalone modules
docker/
  images/                   # Dockerfiles for game servers (ARM)
  scripts/                  # Docker management scripts
utils/
  scripts/                  # Diagnostics and system utilities
```
