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

# VS Code repository (with error handling)
echo -e "${CYAN}[NEKO]${NC} Adding VS Code repository..."
if wget -O /tmp/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null; then
    if [ -s /tmp/microsoft.asc ]; then
        gpg --dearmor < /tmp/microsoft.asc > /etc/apt/trusted.gpg.d/packages.microsoft.gpg 2>/dev/null || true
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
        echo -e "${GREEN}[NEKO]${NC} VS Code repository added successfully!"
    else
        echo -e "${YELLOW}[NEKO]${NC} Warning: Could not download Microsoft GPG key, skipping VS Code repository"
    fi
    rm -f /tmp/microsoft.asc
else
    echo -e "${YELLOW}[NEKO]${NC} Warning: Could not download Microsoft GPG key, skipping VS Code repository"
fi

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

# Install packages from list (if exists)
if [ -f /tmp/packages.list ]; then
    echo -e "${CYAN}[NEKO]${NC} Installing packages from list..."
    
    # Read packages line by line, skip comments and empty lines
    while IFS= read -r package || [ -n "$package" ]; do
        # Skip comments and empty lines
        [[ "$package" =~ ^#.*$ ]] && continue
        [[ -z "$package" ]] && continue
        
        # Try to install the package
        echo "Installing: $package"
        apt-get install -y "$package" 2>/dev/null || echo "Warning: Could not install $package"
    done < /tmp/packages.list
fi

# Install KDE Plasma Desktop
echo -e "${CYAN}[NEKO]${NC} Installing KDE Plasma Desktop..."
apt-get install -y kde-plasma-desktop plasma-workspace sddm

# Install development tools
echo -e "${CYAN}[NEKO]${NC} Installing development tools..."
apt-get install -y \
    git \
    vim \
    neovim \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    code \
    zsh

# Install Oh My Zsh for root (users can install later)
echo -e "${CYAN}[NEKO]${NC} Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true

# Install Japanese fonts and input methods
echo -e "${CYAN}[NEKO]${NC} Installing Japanese language support..."
apt-get install -y \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    ibus \
    ibus-mozc

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
useradd -m -s /bin/bash -G sudo,adm,cdrom,plugdev,lpadmin -c "Neko User" neko || true
echo "neko:neko" | chpasswd
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

# Install and configure Plymouth (boot splash)
echo -e "${CYAN}[NEKO]${NC} Configuring boot splash..."
apt-get install -y plymouth plymouth-themes

# Copy custom themes if they exist
if [ -d /tmp/customization/plymouth ]; then
    cp -r /tmp/customization/plymouth/* /usr/share/plymouth/themes/ || true
    
    # Set NekoDevOS theme as default if it exists
    if [ -f /usr/share/plymouth/themes/nekodeos/nekodeos.plymouth ]; then
        update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/nekodeos/nekodeos.plymouth 100
        update-alternatives --set default.plymouth /usr/share/plymouth/themes/nekodeos/nekodeos.plymouth
        echo -e "${GREEN}[NEKO]${NC} NekoDevOS Plymouth theme installed!"
    fi
fi

# Configure GRUB
echo -e "${CYAN}[NEKO]${NC} Configuring bootloader..."
cat >> /etc/default/grub << EOF

# NekoDevOS GRUB Configuration
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR="NekoDevOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
EOF

# Copy custom GRUB theme if exists
if [ -d /tmp/customization/grub ]; then
    mkdir -p /boot/grub/themes
    cp -r /tmp/customization/grub/* /boot/grub/themes/ || true
fi

# Install custom themes
echo -e "${CYAN}[NEKO]${NC} Installing custom themes..."
if [ -d /tmp/customization/themes ]; then
    mkdir -p /usr/share/themes
    cp -r /tmp/customization/themes/* /usr/share/themes/ || true
fi

# Install custom wallpapers
if [ -d /tmp/customization/wallpapers ]; then
    mkdir -p /usr/share/wallpapers/nekodeos
    cp -r /tmp/customization/wallpapers/* /usr/share/wallpapers/nekodeos/ || true
fi

# Copy customization scripts to home directory
mkdir -p /home/neko/.config
mkdir -p /home/neko/scripts
if [ -d /tmp/scripts ]; then
    cp -r /tmp/scripts/* /home/neko/scripts/ || true
    chmod +x /home/neko/scripts/*.sh || true
fi
chown -R neko:neko /home/neko

# Create custom neofetch config with NekoDevOS logo
echo -e "${CYAN}[NEKO]${NC} Creating custom neofetch configuration..."
mkdir -p /home/neko/.config/neofetch
cat > /home/neko/.config/neofetch/config.conf << 'NEOFETCH_EOF'
# NekoDevOS neofetch config
print_info() {
    info title
    info underline

    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory

    info cols
}

# Distro name override
distro_shorthand="on"
os_arch="on"

# Kernel
kernel_shorthand="on"

# Uptime
uptime_shorthand="on"

# Memory
memory_percent="on"
memory_unit="mib"

# Packages
package_managers="on"

# Shell
shell_path="off"
shell_version="on"

# CPU
speed_type="bios_limit"
speed_shorthand="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"

# GPU
gpu_brand="on"
gpu_type="all"

# Resolution
refresh_rate="on"

# DE/WM
de_version="on"

# Colors
colors=(2 7 7 2 2 7)

# Use custom ASCII art
image_source="/home/neko/.config/neofetch/nekogirl.txt"
image_backend="ascii"
ascii_distro="auto"
ascii_colors=(2 7)
ascii_bold="on"

# Misc
stdout="off"
NEOFETCH_EOF

# Create custom cat girl ASCII art
cat > /home/neko/.config/neofetch/nekogirl.txt << 'ASCII_EOF'
${c1}                 ∧＿∧
${c1}                (｡･ω･｡)ﾉ      ${c2}╔═══════════════════╗
${c1}                /　　　 づ      ${c2}║   ${c1}NekoDevOS${c2}      ║
${c1}            ～（　　　　）～    ${c2}║   ${c1}Nya~ ฅ^•ﻌ•^ฅ${c2}  ║
${c1}              ＼＼＿／／       ${c2}╚═══════════════════╝
${c1}               ヽ|　|ノ
${c1}                  | |
${c1}                (_(_)
ASCII_EOF

chown -R neko:neko /home/neko/.config

# Create custom ASCII art for NekoDevOS
mkdir -p /usr/share/neofetch/ascii/distro
cat > /usr/share/neofetch/ascii/distro/nekodeos << 'ASCIIEOF'
${c1}         ∧＿∧
${c1}        (｡･ω･｡)ﾉ
${c1}        /　　　 づ
${c1}    ～（　　　　）～
${c1}      ＼＼＿／／
${c1}       ヽ|　|ノ
${c1}          | |
${c1}        (_(_)
${c2}     
${c2}    NekoDevOS
${c3}   Developer Edition
ASCIIEOF

chown -R neko:neko /home/neko/.config

# Install Starship prompt
echo -e "${CYAN}[NEKO]${NC} Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh -s -- -y || true

# Configure firewall
echo -e "${CYAN}[NEKO]${NC} Configuring firewall..."
apt-get install -y ufw
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh

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
