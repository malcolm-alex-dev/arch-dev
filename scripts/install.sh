#!/bin/bash
#
# Arch Linux Installation Script
# LUKS encryption + btrfs with snapshots
#
# Usage: 
#   curl -sL <url>/install.sh | bash          # Desktop install
#   curl -sL <url>/install.sh | bash -s server # Server install
#
# Run from Arch ISO after connecting to network

set -euo pipefail

#--------------------------
# Configuration
#--------------------------
VARIANT="${1:-desktop}"  # desktop or server
HOSTNAME="archbox"
USERNAME="user"
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; exit 1; }
cls() { printf '\033[2J\033[H' >/dev/tty; }

#--------------------------
# Pre-flight checks
#--------------------------
select_disk() {
    cls
    echo ""
    echo "========================================"
    echo "  Select Installation Disk"
    echo "========================================"
    echo ""
    log "Available disks:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL | grep -v "^loop"
    echo ""
    
    read -p "Enter target disk (e.g., sda, nvme0n1): " disk_input
    DISK="/dev/${disk_input}"
    
    [[ -b "$DISK" ]] || error "Disk $DISK does not exist"
}

preflight() {
    log "Running pre-flight checks..."
    
    [[ $EUID -eq 0 ]] || error "Must run as root"
    [[ -d /sys/firmware/efi ]] || error "UEFI required"
    ping -c 1 archlinux.org &>/dev/null || error "No network connection"
    
    select_disk
    
    cls
    echo ""
    echo "========================================"
    echo "  Installation Configuration"
    echo "========================================"
    echo ""
    warn "This will ERASE ${DISK}. Press Ctrl+C to abort."
    echo ""
    read -p "Enter hostname [$HOSTNAME]: " input && HOSTNAME="${input:-$HOSTNAME}"
    read -p "Enter username [$USERNAME]: " input && USERNAME="${input:-$USERNAME}"
    read -p "Enter timezone [$TIMEZONE]: " input && TIMEZONE="${input:-$TIMEZONE}"
    
    cls
    echo ""
    echo "========================================"
    echo "  Confirm Installation"
    echo "========================================"
    echo ""
    log "Configuration:"
    echo "  Variant:  $VARIANT"
    echo "  Disk:     $DISK"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Timezone: $TIMEZONE"
    echo ""
    
    read -p "Continue? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
}

#--------------------------
# Partition disk
#--------------------------
partition_disk() {
    log "Partitioning ${DISK}..."
    
    # Wipe disk
    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"
    
    # Create partitions
    # 1: 512MB EFI
    # 2: Rest for LUKS
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"
    sgdisk -n 2:0:0 -t 2:8309 -c 2:"LUKS" "$DISK"
    
    partprobe "$DISK"
    udevadm settle
    sleep 1
}

#--------------------------
# Setup LUKS encryption
#--------------------------
setup_luks() {
    local luks_part="${DISK}2"
    [[ "$DISK" == *nvme* ]] && luks_part="${DISK}p2"
    
    cls
    echo ""
    echo "========================================"
    echo "  LUKS Encryption Setup"
    echo "========================================"
    echo ""
    log "Setting up LUKS encryption on ${luks_part}..."
    echo ""
    echo "You will be asked to:"
    echo "  1. Type YES (uppercase) to confirm"
    echo "  2. Enter encryption passphrase (twice)"
    echo "  3. Enter passphrase again to unlock"
    echo ""
    
    # Close any existing mapping from previous attempts
    cryptsetup close cryptroot 2>/dev/null || true
    
    # Ensure no other process is using the partition
    # Kill any processes using the partition (e.g., udisks2 probing)
    fuser -sk "$luks_part" 2>/dev/null || true
    udevadm settle
    sleep 1
    
    cryptsetup luksFormat --type luks2 "$luks_part"
    
    cls
    echo ""
    echo "========================================"
    echo "  Unlock Encrypted Partition"
    echo "========================================"
    echo ""
    log "Enter passphrase to unlock ${luks_part}..."
    echo ""
    
    # Close any existing mapping from previous attempts
    cryptsetup close cryptroot 2>/dev/null || true
    
    cryptsetup open "$luks_part" cryptroot
}

#--------------------------
# Setup btrfs
#--------------------------
setup_btrfs() {
    log "Setting up btrfs..."
    
    local efi_part="${DISK}1"
    [[ "$DISK" == *nvme* ]] && efi_part="${DISK}p1"
    
    # Format
    mkfs.fat -F32 "$efi_part"
    mkfs.btrfs -f /dev/mapper/cryptroot
    
    # Mount and create subvolumes
    mount /dev/mapper/cryptroot /mnt
    
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@var_log
    btrfs subvolume create /mnt/@var_cache
    
    umount /mnt
    
    # Mount subvolumes
    local opts="compress=zstd,noatime,ssd,discard=async"
    
    mount -o "subvol=@,$opts" /dev/mapper/cryptroot /mnt
    
    mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
    
    mount -o "subvol=@home,$opts" /dev/mapper/cryptroot /mnt/home
    mount -o "subvol=@snapshots,$opts" /dev/mapper/cryptroot /mnt/.snapshots
    mount -o "subvol=@var_log,$opts" /dev/mapper/cryptroot /mnt/var/log
    mount -o "subvol=@var_cache,$opts" /dev/mapper/cryptroot /mnt/var/cache
    
    mount "$efi_part" /mnt/boot
}

#--------------------------
# Install base system
#--------------------------
install_base() {
    log "Installing base system..."
    
    # Update mirrorlist (use --download-timeout to avoid 5s default timeout failures)
    reflector --country US --age 12 --protocol https --sort rate --download-timeout 15 --latest 10 --save /etc/pacman.d/mirrorlist
    
    # Install base packages
    local packages=(
        base linux linux-firmware intel-ucode
        btrfs-progs cryptsetup
        grub efibootmgr
        networkmanager
        zsh
        git
        neovim
        sudo
    )
    
    pacstrap -K /mnt "${packages[@]}"
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
}

#--------------------------
# Configure system (chroot)
#--------------------------
configure_system() {
    log "Configuring system..."
    
    local luks_part="${DISK}2"
    [[ "$DISK" == *nvme* ]] && luks_part="${DISK}p2"
    local luks_uuid=$(blkid -s UUID -o value "$luks_part")
    
    arch-chroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# mkinitcpio - add encrypt and btrfs hooks
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt btrfs filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${luks_uuid}:cryptroot root=/dev/mapper/cryptroot\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel -s /bin/zsh ${USERNAME}

# Sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable services
systemctl enable NetworkManager

CHROOT

    # Set passwords outside heredoc so TTY works properly
    cls
    echo ""
    echo "========================================"
    echo "  Set password for user: ${USERNAME}"
    echo "========================================"
    echo ""
    until arch-chroot /mnt passwd ${USERNAME}; do
        echo "Password mismatch, try again..."
    done

    cls
    echo ""
    echo "========================================"
    echo "  Set password for root"
    echo "========================================"
    echo ""
    until arch-chroot /mnt passwd; do
        echo "Password mismatch, try again..."
    done
}

#--------------------------
# Install packages
#--------------------------
install_packages() {
    log "Installing packages for ${VARIANT}..."
    
    local pkg_file="packages/${VARIANT}.txt"
    
    # For now, install from embedded list based on variant
    if [[ "$VARIANT" == "desktop" ]]; then
        arch-chroot /mnt pacman -S --needed --noconfirm \
            hyprland xdg-desktop-portal-hyprland qt5-wayland qt6-wayland \
            ghostty waybar mako wofi \
            hyprlock hypridle \
            pipewire pipewire-pulse pipewire-alsa wireplumber \
            polkit-gnome \
            brightnessctl pamixer grim slurp wl-clipboard \
            ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
            snapper snap-pac grub-btrfs inotify-tools \
            iwd
    fi
    
    # Snapper config + grub-btrfs
    if [[ "$VARIANT" == "desktop" ]]; then
        arch-chroot /mnt /bin/bash <<CHROOT
# Configure snapper
umount /.snapshots || true
rm -rf /.snapshots
snapper -c root create-config /
btrfs subvolume delete /.snapshots || true
mkdir /.snapshots
mount -a
chmod 750 /.snapshots

# Enable grub-btrfs daemon to auto-update grub menu when snapshots change
systemctl enable grub-btrfsd

# Regenerate grub config to include snapshot entries
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT
    fi
}

#--------------------------
# Post-install message
#--------------------------
post_install() {
    log "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot: umount -R /mnt && reboot"
    echo "  2. Login as ${USERNAME}"
    echo "  3. Clone your dotfiles repo"
    echo "  4. Run: cd dotfiles && ./scripts/setup.sh"
    echo ""
}

#--------------------------
# Main
#--------------------------
main() {
    preflight
    partition_disk
    setup_luks
    setup_btrfs
    install_base
    configure_system
    install_packages
    post_install
}

main "$@"
