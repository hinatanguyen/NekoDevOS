#!/bin/bash
#
# NekoDevOS Build Script
# Builds a custom Ubuntu-based ISO with weeb customizations
#

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
WORK_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"
UBUNTU_VERSION="jammy"  # Ubuntu 22.04 LTS
DISTRO_NAME="NekoDevOS"
ISO_NAME="nekodeos-dev-amd64.iso"
ARCH="amd64"

# Print colored messages
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_neko() {
    echo -e "${MAGENTA}"
    cat << "EOF"
    /\_/\  
   ( o.o ) 
    > ^ <   NekoDevOS Builder
   /|   |\  
  (_|   |_)
EOF
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

# Install build dependencies
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
        dosfstools \
        rsync \
        git \
        wget \
        curl
    print_success "Dependencies installed!"
}

# Create working directories
setup_directories() {
    print_info "Setting up directories..."
    mkdir -p "$WORK_DIR"/{chroot,image,scratch}
    mkdir -p "$OUTPUT_DIR"
    print_success "Directories created!"
}

# Bootstrap Ubuntu base system
bootstrap_system() {
    print_info "Bootstrapping Ubuntu $UBUNTU_VERSION base system..."
    print_warning "This may take a while (downloading packages)..."
    
    if [ ! -d "$WORK_DIR/chroot/usr" ]; then
        debootstrap \
            --arch="$ARCH" \
            --variant=minbase \
            "$UBUNTU_VERSION" \
            "$WORK_DIR/chroot" \
            http://archive.ubuntu.com/ubuntu/
        print_success "Base system bootstrapped!"
    else
        print_warning "Base system already exists, skipping bootstrap"
    fi
}

# Mount necessary filesystems
mount_filesystems() {
    print_info "Mounting filesystems..."
    mount --bind /dev "$WORK_DIR/chroot/dev"
    mount --bind /run "$WORK_DIR/chroot/run"
    mount -t devpts devpts "$WORK_DIR/chroot/dev/pts"
    mount -t proc proc "$WORK_DIR/chroot/proc"
    mount -t sysfs sysfs "$WORK_DIR/chroot/sys"
    mount -t tmpfs tmpfs "$WORK_DIR/chroot/tmp"
    print_success "Filesystems mounted!"
}

# Unmount filesystems
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

# Copy custom files to chroot
copy_custom_files() {
    print_info "Copying custom files..."
    
    # Copy chroot commands
    cp scripts/chroot-commands.sh "$WORK_DIR/chroot/tmp/" 2>/dev/null || true
    chmod +x "$WORK_DIR/chroot/tmp/chroot-commands.sh" 2>/dev/null || true
    
    # Copy custom wallpaper if exists
    if [ -f config/wallpaper/wallpaper.jpg ] || [ -f config/wallpaper/wallpaper.png ]; then
        WALLPAPER=$(ls config/wallpaper/wallpaper.* 2>/dev/null | head -1)
        if [ -n "$WALLPAPER" ]; then
            print_info "Found custom wallpaper: $WALLPAPER"
            cp "$WALLPAPER" "$WORK_DIR/chroot/tmp/wallpaper.jpg"
        fi
    fi
    
    print_success "Custom files copied!"
}

# Run commands in chroot
run_chroot_commands() {
    print_info "Running chroot commands..."
    chroot "$WORK_DIR/chroot" /tmp/chroot-commands.sh
    print_success "Chroot commands completed!"
}

# Create squashfs filesystem
create_squashfs() {
    print_info "Creating squashfs filesystem..."
    print_warning "This may take several minutes..."
    
    rm -f "$WORK_DIR/image/casper/filesystem.squashfs"
    mkdir -p "$WORK_DIR/image/casper"
    
    mksquashfs \
        "$WORK_DIR/chroot" \
        "$WORK_DIR/image/casper/filesystem.squashfs" \
        -comp xz \
        -e boot
    
    print_success "Squashfs created!"
}



# Create ISO image
create_iso() {
    print_info "Creating ISO image..."
    
    # Find and copy kernel and initrd with proper error checking
    print_info "Copying kernel and initrd..."
    KERNEL_FILE=$(ls -1 "$WORK_DIR/chroot/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -n1)
    INITRD_FILE=$(ls -1 "$WORK_DIR/chroot/boot/initrd.img-"* 2>/dev/null | sort -V | tail -n1)
    
    if [ -z "$KERNEL_FILE" ] || [ ! -f "$KERNEL_FILE" ]; then
        print_error "Kernel file not found in $WORK_DIR/chroot/boot/"
        exit 1
    fi
    
    if [ -z "$INITRD_FILE" ] || [ ! -f "$INITRD_FILE" ]; then
        print_error "Initrd file not found in $WORK_DIR/chroot/boot/"
        exit 1
    fi
    
    print_info "Found kernel: $KERNEL_FILE"
    print_info "Found initrd: $INITRD_FILE"
    
    cp "$KERNEL_FILE" "$WORK_DIR/image/casper/vmlinuz"
    cp "$INITRD_FILE" "$WORK_DIR/image/casper/initrd"
    
    print_success "Kernel and initrd copied successfully!"
    
    # Create grub configuration
    mkdir -p "$WORK_DIR/image/boot/grub"
    cat > "$WORK_DIR/image/boot/grub/grub.cfg" << EOF
set timeout=30
set default=0

insmod all_video
insmod gfxterm
insmod iso9660

set gfxmode=auto
set gfxpayload=keep

search --no-floppy --set=root --file /casper/vmlinuz

menuentry "Try NekoDevOS" {
    linux /casper/vmlinuz boot=casper union=overlay username=neko hostname=nekodeos autologin ---
    initrd /casper/initrd
}

menuentry "Try NekoDevOS (Safe Mode - AUFS)" {
    linux /casper/vmlinuz boot=casper union=aufs username=neko hostname=nekodeos autologin ---
    initrd /casper/initrd
}

menuentry "Install NekoDevOS" {
    linux /casper/vmlinuz boot=casper union=overlay only-ubiquity username=neko hostname=nekodeos ---
    initrd /casper/initrd
}

menuentry "Install NekoDevOS (Safe Mode - AUFS)" {
    linux /casper/vmlinuz boot=casper union=aufs only-ubiquity username=neko hostname=nekodeos ---
    initrd /casper/initrd
}
EOF

    # Copy GRUB boot files
    mkdir -p "$WORK_DIR/image/boot/grub/i386-pc"
    cp /usr/lib/grub/i386-pc/*.mod "$WORK_DIR/image/boot/grub/i386-pc/" 2>/dev/null || true
    cp /usr/lib/grub/i386-pc/*.lst "$WORK_DIR/image/boot/grub/i386-pc/" 2>/dev/null || true
    cp /usr/lib/grub/i386-pc/eltorito.img "$WORK_DIR/image/boot/grub/i386-pc/" 2>/dev/null || true
    
    # Generate manifest
    chroot "$WORK_DIR/chroot" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORK_DIR/image/casper/filesystem.manifest"
    
    # Create ISO using xorriso with GRUB
    print_info "Building bootable ISO with GRUB..."
    grub-mkstandalone \
        --format=i386-pc \
        --output="$WORK_DIR/image/boot/grub/core.img" \
        --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
        --modules="linux normal iso9660 biosdisk search" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=$WORK_DIR/image/boot/grub/grub.cfg"
    
    # Combine boot image
    cat /usr/lib/grub/i386-pc/cdboot.img "$WORK_DIR/image/boot/grub/core.img" > "$WORK_DIR/image/boot/grub/bios.img"
    
    # Create the ISO
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$DISTRO_NAME" \
        -eltorito-boot boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
        --grub2-boot-info \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -output "$OUTPUT_DIR/$ISO_NAME" \
        -graft-points \
        "$WORK_DIR/image" \
        /boot/grub/bios.img="$WORK_DIR/image/boot/grub/bios.img"
    
    print_success "ISO created: $OUTPUT_DIR/$ISO_NAME"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up..."
    unmount_filesystems
    print_success "Cleanup complete!"
}

# Main build process
main() {
    print_neko
    print_info "Starting NekoDevOS build process..."
    print_info "This will take some time, grab some ramen! 🍜"
    echo ""
    
    check_root
    install_dependencies
    setup_directories
    bootstrap_system
    mount_filesystems
    
    # Set trap to cleanup on exit
    trap cleanup EXIT
    
    copy_custom_files
    run_chroot_commands
    unmount_filesystems
    create_squashfs
    create_iso
    
    echo ""
    print_success "Build complete! 🎉"
    print_info "Your ISO is ready at: $OUTPUT_DIR/$ISO_NAME"
    print_info "You can now write this to a USB drive and install!"
    
    # Calculate ISO size
    if [ -f "$OUTPUT_DIR/$ISO_NAME" ]; then
        ISO_SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)
        print_info "ISO size: $ISO_SIZE"
    fi
}

# Run main function
main "$@"
