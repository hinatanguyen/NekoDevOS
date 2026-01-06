#!/bin/bash
#
# NekoDevOS Installer Test Script
# Tests the installer in a QEMU virtual machine
#

set -e

# Configuration
ISO_PATH="$(pwd)/output/nekodeos-dev-amd64.iso"
VM_DISK="$(pwd)/output/test-vm-disk.qcow2"
DISK_SIZE="20G"
RAM="4G"
CPUS="2"

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
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

print_neko() {
    echo -e "${MAGENTA}"
    cat << "EOF"
    /\_/\  
   ( o.o ) 
    > ^ <   Testing NekoDevOS!
   /|   |\  
  (_|   |_)
EOF
    echo -e "${NC}"
}

# Check if ISO exists
if [ ! -f "$ISO_PATH" ]; then
    print_error "ISO not found at $ISO_PATH"
    print_info "Please run ./build.sh first"
    exit 1
fi

print_neko
print_info "Starting NekoDevOS installer test..."
echo ""

# Create virtual disk if it doesn't exist
if [ ! -f "$VM_DISK" ]; then
    print_info "Creating virtual disk ($DISK_SIZE)..."
    qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"
    print_success "Virtual disk created"
else
    print_warning "Virtual disk already exists at $VM_DISK"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$VM_DISK"
        qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"
        print_success "Virtual disk recreated"
    fi
fi

echo ""
print_info "VM Configuration:"
echo "  - RAM: $RAM"
echo "  - CPUs: $CPUS"
echo "  - Disk: $DISK_SIZE"
echo "  - ISO: $ISO_PATH"
echo ""
print_info "Booting VM with installer..."

# Check if display is available
DISPLAY_MODE="none"
if [ -n "$DISPLAY" ]; then
    print_info "X11 display detected: $DISPLAY"
    DISPLAY_MODE="gtk"
    print_warning "Press Ctrl+Alt+G to release mouse capture"
    print_warning "Press Ctrl+Alt+F to toggle fullscreen"
elif command -v Xvfb &> /dev/null; then
    print_info "Using virtual display (Xvfb)"
    DISPLAY_MODE="xvfb"
    export DISPLAY=:99
    Xvfb $DISPLAY -screen 0 1024x768x24 &
    XVFB_PID=$!
else
    print_warning "No graphical display available, using VNC display"
    DISPLAY_MODE="vnc"
    print_warning "VNC server will be available at localhost:5900"
fi

echo ""

# Boot the VM with the ISO
QEMU_ARGS=(
    "-enable-kvm"
    "-m" "$RAM"
    "-smp" "$CPUS"
    "-boot" "d"
    "-cdrom" "$ISO_PATH"
    "-drive" "file=$VM_DISK,format=qcow2,if=virtio"
    "-vga" "qxl"
)

# Add display-specific arguments
case $DISPLAY_MODE in
    gtk)
        QEMU_ARGS+=("-display" "sdl")
        QEMU_ARGS+=("-audio" "pa,model=hda")
        ;;
    xvfb)
        QEMU_ARGS+=("-display" "gtk")
        QEMU_ARGS+=("-audio" "none")
        ;;
    vnc)
        QEMU_ARGS+=("-display" "vnc=localhost:0")
        QEMU_ARGS+=("-audio" "none")
        ;;
    none)
        QEMU_ARGS+=("-display" "none")
        QEMU_ARGS+=("-audio" "none")
        print_warning "Running in headless mode. No graphical display available."
        print_info "You can still monitor serial output and manage the VM via monitor interface."
        ;;
esac

# Add network configuration
QEMU_ARGS+=(
    "-net" "nic,model=virtio"
    "-net" "user"
    "-serial" "file:/tmp/qemu-serial.log"
)

print_info "Starting QEMU with display mode: $DISPLAY_MODE"
qemu-system-x86_64 "${QEMU_ARGS[@]}"

# Clean up Xvfb if we started it
if [ -n "$XVFB_PID" ]; then
    kill $XVFB_PID 2>/dev/null || true
fi

print_success "VM session ended"
if [ -f "/tmp/qemu-serial.log" ]; then
    print_info "Serial output saved to: /tmp/qemu-serial.log"
fi
