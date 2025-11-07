#!/bin/bash
#
# NekoDevOS Chroot Commands
# Commands to run inside the chroot environment during build
#

set -e

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}[NEKO]${NC} Starting chroot configuration..."

# Set up environment
export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

# Configure APT
echo -e "${CYAN}[NEKO]${NC} Configuring package manager..."
cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Update package lists
apt-get update

# Install wget, curl, and gnupg first (needed for adding repositories)
echo -e "${CYAN}[NEKO]${NC} Installing prerequisite tools..."
apt-get install -y wget curl gnupg2 ca-certificates software-properties-common

# Add additional repositories
echo -e "${CYAN}[NEKO]${NC} Adding additional repositories..."

# Note: VS Code removed due to network dependency during build
# Users can install it manually after installation

# Update package lists again
apt-get update

# Upgrade base system
echo -e "${CYAN}[NEKO]${NC} Upgrading base system..."
apt-get dist-upgrade -y

# Install essential packages first
echo -e "${CYAN}[NEKO]${NC} Installing essential packages..."
apt-get install -y \
    systemd \
    systemd-sysv \
    ubuntu-minimal \
    ubuntu-standard \
    casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    grub-common \
    grub-pc-bin \
    grub2-common \
    linux-generic



# Install KDE Plasma Desktop
echo -e "${CYAN}[NEKO]${NC} Installing KDE Plasma Desktop..."
apt-get install -y kde-plasma-desktop plasma-workspace sddm

# Install essential development tools
echo -e "${CYAN}[NEKO]${NC} Installing development tools..."
apt-get install -y \
    git \
    vim \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    zsh \
    fonts-noto-cjk \
    neofetch \
    firefox

# Configure system
echo -e "${CYAN}[NEKO]${NC} Configuring system..."

# Set hostname
echo "nekodeos" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   nekodeos
::1         localhost ip6-localhost ip6-loopback
EOF

# Configure OS identity
echo -e "${CYAN}[NEKO]${NC} Configuring OS identity..."
cat > /etc/os-release << EOF
NAME="NekoDevOS"
VERSION="1.0 (Neko)"
ID=nekodeos
ID_LIKE=ubuntu
PRETTY_NAME="NekoDevOS 1.0"
VERSION_ID="1.0"
HOME_URL="https://github.com/hinatanguyen/NekoDevOS"
SUPPORT_URL="https://github.com/hinatanguyen/NekoDevOS/issues"
BUG_REPORT_URL="https://github.com/hinatanguyen/NekoDevOS/issues"
PRIVACY_POLICY_URL="https://github.com/hinatanguyen/NekoDevOS"
VERSION_CODENAME=neko
UBUNTU_CODENAME=jammy
LOGO=nekodeos
EOF

cat > /etc/lsb-release << EOF
DISTRIB_ID=NekoDevOS
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=neko
DISTRIB_DESCRIPTION="NekoDevOS 1.0 - Developer Edition"
EOF

# Set locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Configure timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Create live user
echo -e "${CYAN}[NEKO]${NC} Creating live user..."
# Create necessary groups if they don't exist
groupadd -f lpadmin || true
groupadd -f plugdev || true

# Create user with basic groups first
useradd -m -s /bin/bash -G sudo,adm,cdrom -c "Neko User" neko || true

# Add user to additional groups if they exist
usermod -a -G plugdev neko 2>/dev/null || true
usermod -a -G lpadmin neko 2>/dev/null || true

# Set password
echo "neko:neko" | chpasswd 2>/dev/null || passwd -d neko

# Add sudo permissions
echo "neko ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Enable auto-login for live session
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=neko
Session=plasma
EOF

# Enable SDDM display manager service
echo -e "${CYAN}[NEKO]${NC} Enabling SDDM display manager..."
systemctl enable sddm.service || true
systemctl set-default graphical.target || true

# Disable KDE splash screen to show Plymouth instead
echo -e "${CYAN}[NEKO]${NC} Configuring to use Plymouth instead of KDE splash..."
mkdir -p /home/neko/.config
cat > /home/neko/.config/ksplashrc << EOF
[KSplash]
Engine=none
Theme=None
EOF

# Also create global KDE config to disable splash
mkdir -p /etc/xdg
cat > /etc/xdg/ksplashrc << EOF
[KSplash]
Engine=none
Theme=None
EOF

# Install and configure Plymouth (boot splash)
echo -e "${CYAN}[NEKO]${NC} Configuring boot splash..."
apt-get install -y plymouth plymouth-themes plymouth-label

# Use NekoDevOS graphical theme (copied from customization/plymouth/nekodeos/)
echo -e "${CYAN}[NEKO]${NC} Installing NekoDevOS graphical Plymouth theme..."

# Set as default theme
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/nekodeos/nekodeos.plymouth 100
update-alternatives --set default.plymouth /usr/share/plymouth/themes/nekodeos/nekodeos.plymouth

# Configure Plymouth daemon
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf << 'EOF'
[Daemon]
Theme=nekodeos
ShowDelay=0
DeviceTimeout=8
EOF

# Add Plymouth to initramfs modules
mkdir -p /etc/initramfs-tools/conf.d
echo "FRAMEBUFFER=y" > /etc/initramfs-tools/conf.d/splash

# Ensure Plymouth is in initramfs hooks
cat > /etc/initramfs-tools/hooks/plymouth-fix << 'EOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0 ;;
esac
. /usr/share/initramfs-tools/hook-functions
copy_exec /usr/bin/plymouth
copy_exec /usr/sbin/plymouthd
mkdir -p "${DESTDIR}/usr/share/plymouth/themes"
cp -a /usr/share/plymouth/themes/nekodeos "${DESTDIR}/usr/share/plymouth/themes/"
EOF
chmod +x /etc/initramfs-tools/hooks/plymouth-fix

# Update initramfs
echo -e "${CYAN}[NEKO]${NC} Updating initramfs with Plymouth theme..."
update-initramfs -u

echo -e "${GREEN}[NEKO]${NC} Plymouth theme configured!"

# Configure GRUB
echo -e "${CYAN}[NEKO]${NC} Configuring bootloader..."
cat >> /etc/default/grub << EOF

# NekoDevOS GRUB Configuration
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR="NekoDevOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
EOF

# Basic system configuration complete

# Configure NekoDevOS branding
echo -e "${CYAN}[NEKO]${NC} Setting up NekoDevOS branding..."
mkdir -p /home/neko/.config

# Simple neofetch config
mkdir -p /home/neko/.config/neofetch
cat > /home/neko/.config/neofetch/config.conf << 'EOF'
ascii_distro="arch_small"
ascii_colors=(6 6 7 1 8 6)
colors=(6 6 7 1 8 6)
EOF

# Add neofetch to bashrc
echo 'neofetch' >> /home/neko/.bashrc

chown -R neko:neko /home/neko

# Clean up
echo -e "${CYAN}[NEKO]${NC} Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/lib/apt/lists/*

# Update initramfs
echo -e "${CYAN}[NEKO]${NC} Updating initramfs..."
update-initramfs -u -k all || true

echo -e "${GREEN}[NEKO]${NC} Chroot configuration complete! ฅ^•ﻌ•^ฅ"
