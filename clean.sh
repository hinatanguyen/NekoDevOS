#!/bin/bash
#
# NekoDevOS Clean Build Script
# Removes all build artifacts to start fresh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}[ERROR]${NC} Please run as root (use sudo)"
        exit 1
    fi
}

WORK_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"

echo "🧹 NekoDevOS Build Cleanup"
echo ""
print_warning "This will remove:"
echo "  - build/ directory (all build artifacts)"
echo "  - output/*.iso (generated ISO files)"
echo ""
echo -n "Continue? (yes/no): "
read -r response

if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

check_root

# Unmount any mounted filesystems
print_info "Unmounting filesystems (if any)..."
umount -lf "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
umount -lf "$WORK_DIR/chroot/dev" 2>/dev/null || true
umount -lf "$WORK_DIR/chroot/run" 2>/dev/null || true
umount -lf "$WORK_DIR/chroot/proc" 2>/dev/null || true
umount -lf "$WORK_DIR/chroot/sys" 2>/dev/null || true
umount -lf "$WORK_DIR/chroot/tmp" 2>/dev/null || true

# Remove build directory
if [ -d "$WORK_DIR" ]; then
    print_info "Removing build directory..."
    rm -rf "$WORK_DIR"
    print_success "Build directory removed!"
fi

# Remove ISO files
if [ -d "$OUTPUT_DIR" ]; then
    print_info "Removing ISO files..."
    rm -f "$OUTPUT_DIR"/*.iso
    print_success "ISO files removed!"
fi

echo ""
print_success "Cleanup complete! You can now run build.sh fresh. ✨"
