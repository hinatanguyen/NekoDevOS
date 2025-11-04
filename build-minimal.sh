#!/bin/bash
#
# NekoDevOS Minimal Build Script
# Creates a minimal bootable ISO for testing (much faster than full build)
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
WORK_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"
UBUNTU_VERSION="jammy"
DISTRO_NAME="NekoDevOS"
ISO_NAME="nekodeos-minimal-amd64.iso"
ARCH="amd64"

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_neko() {
    echo -e "${MAGENTA}"
    cat << "EOF"
    /\_/\  
   ( o.o ) 
    > ^ <   NekoDevOS Minimal Builder
   /|   |\  
  (_|   |_)
EOF
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

install_dependencies() {
    print_info "Installing build dependencies..."
    apt-get update
    apt-get install -y \
        debootstrap \
        squashfs-tools \
        xorriso \
        isolinux \
        syslinux-efi \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        dosfstools
    print_success "Dependencies installed!"
}

setup_directories() {
    print_info "Setting up directories..."
    mkdir -p "$WORK_DIR"/{chroot,image/{casper,isolinux,install},scratch}
    mkdir -p "$OUTPUT_DIR"
    print_success "Directories created!"
}

bootstrap_system() {
    print_info "Bootstrapping minimal Ubuntu system..."
    if [ ! -d "$WORK_DIR/chroot/usr" ]; then
        debootstrap \
            --arch="$ARCH" \
            --variant=minbase \
            "$UBUNTU_VERSION" \
            "$WORK_DIR/chroot" \
            http://archive.ubuntu.com/ubuntu/
        print_success "Base system bootstrapped!"
    else
        print_info "Base system already exists, skipping..."
    fi
}

mount_filesystems() {
    print_info "Mounting filesystems..."
    mount --bind /dev "$WORK_DIR/chroot/dev" 2>/dev/null || true
    mount --bind /run "$WORK_DIR/chroot/run" 2>/dev/null || true
    mount -t devpts devpts "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
    mount -t proc proc "$WORK_DIR/chroot/proc" 2>/dev/null || true
    mount -t sysfs sysfs "$WORK_DIR/chroot/sys" 2>/dev/null || true
    mount -t tmpfs tmpfs "$WORK_DIR/chroot/tmp" 2>/dev/null || true
    print_success "Filesystems mounted!"
}

unmount_filesystems() {
    print_info "Unmounting filesystems..."
    umount -lf "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/dev" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/run" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/proc" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/sys" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/tmp" 2>/dev/null || true
    print_success "Filesystems unmounted!"
}

configure_minimal_system() {
    print_info "Configuring minimal system..."
    
    cat > "$WORK_DIR/chroot/tmp/minimal-setup.sh" << 'CHROOT_EOF'
#!/bin/bash
set -e
export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

# Configure sources
cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

# Update and install minimal packages
apt-get update
apt-get install -y --no-install-recommends \
    linux-generic \
    systemd \
    systemd-sysv \
    casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    grub-common \
    grub-pc-bin \
    grub2-common \
    locales \
    sudo \
    kbd \
    console-setup

# Set hostname
echo "nekodeos" > /etc/hostname

# Set locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Create user
useradd -m -s /bin/bash -G sudo neko || true
echo "neko:live" | chpasswd
echo "neko ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Clean up
apt-get clean
rm -rf /tmp/*
CHROOT_EOF

    chmod +x "$WORK_DIR/chroot/tmp/minimal-setup.sh"
    chroot "$WORK_DIR/chroot" /tmp/minimal-setup.sh
    print_success "System configured!"
}

create_squashfs() {
    print_info "Creating squashfs filesystem..."
    
    rm -f "$WORK_DIR/image/casper/filesystem.squashfs"
    
    mksquashfs \
        "$WORK_DIR/chroot" \
        "$WORK_DIR/image/casper/filesystem.squashfs" \
        -comp xz \
        -e boot
    
    # Create filesystem size file
    printf $(du -sx --block-size=1 "$WORK_DIR/chroot" | cut -f1) > "$WORK_DIR/image/casper/filesystem.size"
    
    print_success "Squashfs created!"
}

create_iso_structure() {
    print_info "Creating ISO structure..."
    
    # Copy kernel and initrd
    cp "$WORK_DIR/chroot/boot/vmlinuz-"* "$WORK_DIR/image/casper/vmlinuz" 2>/dev/null || true
    cp "$WORK_DIR/chroot/boot/initrd.img-"* "$WORK_DIR/image/casper/initrd" 2>/dev/null || true
    
    # Create manifest
    chroot "$WORK_DIR/chroot" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORK_DIR/image/casper/filesystem.manifest"
    
    # Setup ISOLINUX for BIOS boot
    mkdir -p "$WORK_DIR/image/isolinux"
    cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/image/isolinux/" || true
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$WORK_DIR/image/isolinux/" || true
    cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$WORK_DIR/image/isolinux/" || true
    cp /usr/lib/syslinux/modules/bios/libutil.c32 "$WORK_DIR/image/isolinux/" || true
    cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "$WORK_DIR/image/isolinux/" || true
    
    # Create ISOLINUX configuration
    cat > "$WORK_DIR/image/isolinux/isolinux.cfg" << 'EOF'
DEFAULT live
LABEL live
  MENU LABEL ^Start NekoDevOS
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper quiet splash ---

LABEL live-safe
  MENU LABEL ^NekoDevOS (safe graphics)
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper xforcevesa quiet splash ---

LABEL check
  MENU LABEL ^Check disc for defects
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper integrity-check quiet splash ---

DISPLAY isolinux.txt
TIMEOUT 300
PROMPT 1
EOF

    # Create boot splash text
    cat > "$WORK_DIR/image/isolinux/isolinux.txt" << 'EOF'
 
  /\_/\  
 ( o.o ) 
  > ^ <   

NekoDevOS - Weeb Dev Linux

Press ENTER to boot or wait 30 seconds...
EOF
    
    # Create GRUB configuration for UEFI boot
    mkdir -p "$WORK_DIR/image/boot/grub"
    cat > "$WORK_DIR/image/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Start NekoDevOS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "NekoDevOS (safe graphics)" {
    linux /casper/vmlinuz boot=casper xforcevesa quiet splash ---
    initrd /casper/initrd
}

menuentry "Check disc for defects" {
    linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
    initrd /casper/initrd
}
EOF
    
    # Create disk info directory first
    mkdir -p "$WORK_DIR/image/.disk"
    
    # Create disk info
    cat > "$WORK_DIR/image/.disk/info" << EOF
NekoDevOS Minimal $(date +%Y%m%d)
EOF
    
    touch "$WORK_DIR/image/.disk/base_installable"
    echo "full_cd/single" > "$WORK_DIR/image/.disk/cd_type"
    echo "NekoDevOS Minimal" > "$WORK_DIR/image/.disk/release_notes_url"
    
    print_success "ISO structure created!"
}

create_iso() {
    print_info "Creating ISO image..."
    
    # Create hybrid BIOS/UEFI bootable ISO
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$DISTRO_NAME" \
        -output "$OUTPUT_DIR/$ISO_NAME" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -eltorito-boot isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/boot.cat \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -append_partition 2 0xef "$WORK_DIR/scratch/efiboot.img" \
        "$WORK_DIR/image" 2>/dev/null || {
        
        # Fallback: Create BIOS-only bootable ISO
        print_info "Using fallback BIOS boot method..."
        mkisofs -rational-rock \
            -volid "$DISTRO_NAME" \
            -cache-inodes \
            -joliet \
            -full-iso9660-filenames \
            -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -output "$OUTPUT_DIR/$ISO_NAME" \
            "$WORK_DIR/image"
    }
    
    # Make ISO hybrid (bootable from USB)
    isohybrid "$OUTPUT_DIR/$ISO_NAME" 2>/dev/null || true
    
    print_success "ISO created: $OUTPUT_DIR/$ISO_NAME"
}

cleanup() {
    print_info "Cleaning up..."
    unmount_filesystems
    print_success "Cleanup complete!"
}

main() {
    print_neko
    print_info "Building minimal NekoDevOS ISO..."
    echo ""
    
    check_root
    install_dependencies
    setup_directories
    bootstrap_system
    mount_filesystems
    
    trap cleanup EXIT
    
    configure_minimal_system
    unmount_filesystems
    create_squashfs
    create_iso_structure
    create_iso
    
    echo ""
    print_success "Minimal build complete! 🎉"
    print_info "ISO location: $OUTPUT_DIR/$ISO_NAME"
    
    if [ -f "$OUTPUT_DIR/$ISO_NAME" ]; then
        ISO_SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)
        print_info "ISO size: $ISO_SIZE"
    fi
}

main "$@"
