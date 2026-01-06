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

# Configure debconf to prevent interactive prompts
echo -e "${CYAN}[NEKO]${NC} Configuring debconf..."
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
echo 'debconf debconf/priority select critical' | debconf-set-selections

# Reconfigure debconf and locales if they exist
dpkg-reconfigure -f noninteractive debconf 2>/dev/null || true

# Patch debconf.py to handle empty string errors gracefully
echo -e "${CYAN}[NEKO]${NC} Patching debconf to handle communication errors..."
if [ -f /usr/lib/python3/dist-packages/debconf.py ]; then
    # Create a backup
    cp /usr/lib/python3/dist-packages/debconf.py /usr/lib/python3/dist-packages/debconf.py.bak
    
    # Comprehensive patch for debconf.py to handle:
    # 1. Empty status strings in command()
    # 2. Empty version strings in setUp()
    cat > /tmp/debconf_patch.py << 'PYPATCH'
import sys
import re

with open('/usr/lib/python3/dist-packages/debconf.py', 'r') as f:
    content = f.read()

patched = False

# Patch 1: Fix status = int(status) to handle empty strings
old_status = 'status = int(status)'
new_status = 'status = int(status) if status and str(status).strip() else 0'
if old_status in content:
    content = content.replace(old_status, new_status)
    patched = True
    print("Patched status parsing")

# Patch 2: Fix setUp() version check to handle empty version strings
# Original: if self.version[:2] != '2.':
#           raise DebconfError(256, "wrong version: %s" % self.version)
old_version_check = "if self.version[:2] != '2.':\n            raise DebconfError(256, \"wrong version: %s\" % self.version)"
new_version_check = '''if not self.version or self.version[:2] != '2.':
            # Handle empty or invalid version - assume compatible version for live environment
            self.version = '2.0'
            # Don't raise error, just continue with assumed version'''
if old_version_check in content:
    content = content.replace(old_version_check, new_version_check)
    patched = True
    print("Patched version check")

# Patch 3: Fix version assignment line to handle empty responses
old_version_assign = 'self.version = self.version(2)'
new_version_assign = '''try:
            self.version = self.version(2) or '2.0'
        except Exception:
            self.version = '2.0\''''
if old_version_assign in content:
    content = content.replace(old_version_assign, new_version_assign)
    patched = True
    print("Patched version assignment")

if patched:
    with open('/usr/lib/python3/dist-packages/debconf.py', 'w') as f:
        f.write(content)
    print("debconf.py patched successfully")
else:
    print("No patterns matched - file may already be patched or has different format")
PYPATCH
    
    python3 /tmp/debconf_patch.py 2>/dev/null || true
    rm -f /tmp/debconf_patch.py
    
    # Fallback: Use sed for simpler replacements if Python patch didn't work
    sed -i 's/status = int(status)/status = int(status) if status and str(status).strip() else 0/g' /usr/lib/python3/dist-packages/debconf.py 2>/dev/null || true
fi

# Also create a completely safe debconf wrapper module
mkdir -p /usr/lib/python3/dist-packages
cat > /usr/lib/python3/dist-packages/debconf_safe.py << 'PYSAFE'
"""Safe wrapper for debconf that handles empty responses"""
import sys
import os

# Set environment to prevent interactive mode
os.environ['DEBIAN_FRONTEND'] = 'noninteractive'
os.environ['DEBCONF_NONINTERACTIVE_SEEN'] = 'true'

# Monkey-patch debconf before it's imported elsewhere
try:
    import debconf
    original_init = debconf.Debconf.__init__
    
    def safe_init(self, *args, **kwargs):
        try:
            return original_init(self, *args, **kwargs)
        except (ValueError, AttributeError) as e:
            # Silently ignore debconf initialization errors
            pass
    
    debconf.Debconf.__init__ = safe_init
except:
    pass
PYSAFE

chmod 644 /usr/lib/python3/dist-packages/debconf_safe.py

# Note: The actual debconfcommunicator.py patch happens AFTER ubiquity is installed
# This early check is just a placeholder - ubiquity isn't installed yet at this point

# Configure APT
echo -e "${CYAN}[NEKO]${NC} Configuring package manager..."
cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Configure APT to avoid interactive prompts
cat > /etc/apt/apt.conf.d/00-neko-noninteractive << EOF
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
APT::Get::Assume-Yes "true";
APT::Get::allow-downgrades "true";
APT::Get::allow-remove-essential "false";
APT::Get::allow-change-held-packages "false";
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

# Install essential packages first (skip dist-upgrade for speed)
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

# Install linux-modules-extra for overlay filesystem support
echo -e "${CYAN}[NEKO]${NC} Installing kernel modules for overlay filesystem..."
# Get kernel version from installed package
KERNEL_VERSION=$(dpkg -l | grep 'linux-image-[0-9]' | grep -v 'linux-image-generic' | awk '{print $2}' | sed 's/linux-image-//' | head -n1)
if [ -n "$KERNEL_VERSION" ]; then
    echo -e "${CYAN}[NEKO]${NC} Found kernel version: $KERNEL_VERSION"
    apt-get install -y linux-modules-extra-${KERNEL_VERSION} 2>/dev/null || {
        echo -e "${CYAN}[NEKO]${NC} Trying alternative method..."
        apt-cache search linux-modules-extra | grep generic | head -n1 | awk '{print $1}' | xargs apt-get install -y
    }
else
    echo -e "${CYAN}[NEKO]${NC} Installing linux-modules-extra-generic..."
    apt-cache search linux-modules-extra | grep generic | head -n1 | awk '{print $1}' | xargs apt-get install -y
fi

# Install aufs as backup union filesystem
echo -e "${CYAN}[NEKO]${NC} Installing AUFS as backup union filesystem..."
apt-get install -y aufs-tools aufs-dkms 2>/dev/null || {
    echo -e "${CYAN}[NEKO]${NC} AUFS not available in repos, overlay will be primary option"
}

# Verify overlay module exists
if [ -f /lib/modules/*/kernel/fs/overlayfs/overlay.ko* ] || [ -f /lib/modules/*/kernel/fs/overlay/overlay.ko* ]; then
    echo -e "${GREEN}[NEKO]${NC} Overlay module found!"
else
    echo -e "${CYAN}[NEKO]${NC} Warning: Overlay module not found in expected location"
    echo -e "${CYAN}[NEKO]${NC} Checking available filesystem modules..."
    find /lib/modules -name "overlay.ko*" -o -name "overlayfs.ko*" -o -name "aufs.ko*" | head -5
fi



# Install XFCE Desktop (minimal)
echo -e "${CYAN}[NEKO]${NC} Installing XFCE Desktop..."
apt-get install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter --no-install-recommends

# Install Firefox from Mozilla PPA for proper non-snap version
echo -e "${CYAN}[NEKO]${NC} Adding Mozilla Firefox PPA..."
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || true
cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF
apt-get update

# Install essential development tools
echo -e "${CYAN}[NEKO]${NC} Installing development tools..."
apt-get install -y --no-install-recommends \
    git \
    vim \
    python3 \
    python3-pip \
    build-essential \
    fonts-noto-cjk \
    neofetch \
    firefox

# Install macOS-like dock and additional tools
echo -e "${CYAN}[NEKO]${NC} Installing Plank dock and desktop tools..."
apt-get install -y --no-install-recommends \
    plank \
    thunar \
    xfce4-appfinder \
    xfce4-screenshooter \
    papirus-icon-theme \
    adwaita-icon-theme-full \
    gnome-icon-theme \
    hicolor-icon-theme

# Install Calamares installer (more stable than ubiquity for custom distros)
echo -e "${CYAN}[NEKO]${NC} Installing system installer (Calamares)..."
apt-get install -y --no-install-recommends \
    calamares \
    partitionmanager \
    os-prober \
    grub-efi-amd64 \
    grub-pc-bin \
    policykit-1 \
    policykit-1-gnome \
    xdg-utils \
    desktop-file-utils \
    squashfs-tools \
    rsync

# Configure Calamares for NekoDevOS installation
echo -e "${CYAN}[NEKO]${NC} Configuring Calamares installer..."
mkdir -p /etc/calamares/modules

# Create main Calamares settings file
cat > /etc/calamares/settings.conf << 'CALAMARES_SETTINGS'
---
branding: nekodevos

modules-search: [ local, /usr/lib/x86_64-linux-gnu/calamares/modules ]

sequence:
    - show:
        - welcome
        - locale
        - keyboard
        - partition
        - users
        - summary
    - exec:
        - partition
        - mount
        - unpackfs
        - machineid
        - fstab
        - locale
        - keyboard
        - localecfg
        - users
        - displaymanager
        - networkcfg
        - hwclock
        - grubcfg
        - bootloader
        - umount
    - show:
        - finished

CALAMARES_SETTINGS

# Create module configuration files
cat > /etc/calamares/modules/welcome.conf << 'MODULE_WELCOME'
---
showSupportUrl: false
showKnownIssuesUrl: false
showReleaseNotesUrl: false
showDonateUrl: false

# Requirements checking - set all to false to allow installation in any environment
requirements:
    requiredStorage: 5
    requiredRam: 1.0
    internetCheckUrl: ""
    check:
        - storage
        - ram
        - root
    required:
        - storage
        - ram
        - root

# GeoIP disabled
geoip:
    style: "none"
MODULE_WELCOME

cat > /etc/calamares/modules/locale.conf << 'MODULE_LOCALE'
---
localeGenPath: /etc/locale.gen
LANG: en_US.UTF-8
LC_NUMERIC: en_US.UTF-8
LC_TIME: en_US.UTF-8
LC_MONETARY: en_US.UTF-8
LC_PAPER: en_US.UTF-8
LC_NAME: en_US.UTF-8
LC_ADDRESS: en_US.UTF-8
LC_TELEPHONE: en_US.UTF-8
LC_MEASUREMENT: en_US.UTF-8
LC_IDENTIFICATION: en_US.UTF-8
MODULE_LOCALE

cat > /etc/calamares/modules/keyboard.conf << 'MODULE_KEYBOARD'
---
Model: pc105
Layout: us
Variant: ''
OPTIONS: ''
MODULE_KEYBOARD

cat > /etc/calamares/modules/partition.conf << 'MODULE_PARTITION'
---
efiSystemPartition: /boot/efi
efiSystemPartitionSize: 512M
efiSystemPartitionName: EFI

userSwapChoices:
    - none
    - small
    - suspend
    - file

drawNestedPartitions: false
alwaysShowPartitionLabels: true
allowManualPartitioning: true

initialPartitioningChoice: erase
initialSwapChoice: small

defaultFileSystemType: ext4
availableFileSystemTypes:
    - ext4
    - btrfs
    - xfs

MODULE_PARTITION

cat > /etc/calamares/modules/users.conf << 'MODULE_USERS'
---
defaultGroups:
    - name: sudo
      must_exist: true
      system: true
    - name: cdrom
      must_exist: false
      system: true
    - name: floppy
      must_exist: false
      system: true
    - name: audio
      must_exist: false
      system: true
    - name: dip
      must_exist: false
      system: true
    - name: video
      must_exist: false
      system: true
    - name: plugdev
      must_exist: false
      system: true
    - name: netdev
      must_exist: false
      system: true
    - name: lpadmin
      must_exist: false
      system: true

autologinGroup: autologin
sudoersGroup: sudo
setRootPassword: true
doAutologin: false
MODULE_USERS

cat > /etc/calamares/modules/displaymanager.conf << 'MODULE_DM'
---
displaymanagers:
  - lightdm
defaultSession: xfce
SESSION: xfce
MODULE_DM

cat > /etc/calamares/modules/grubcfg.conf << 'MODULE_GRUB'
---
installEfi: true
installMbr: true
MODULE_GRUB

cat > /etc/calamares/modules/bootloader.conf << 'MODULE_BL'
---
efiBootLoader: grub
kernel: /vmlinuz-linux
img: /initramfs-linux.img
fallback: /initramfs-linux-fallback.img
timeout: 5
grubInstall: grub-install
grubMkconfig: grub-mkconfig
grubCfg: /boot/grub/grub.cfg
grubProbe: grub-probe
efiBootloaderId: NekoDevOS
installEFIFallback: true
MODULE_BL

# Create unpackfs configuration (CRITICAL - tells Calamares where the squashfs is)
# Casper mounts the ISO at /cdrom or /run/live/medium
cat > /etc/calamares/modules/unpackfs.conf << 'MODULE_UNPACKFS'
---
unpack:
  - source: /cdrom/casper/filesystem.squashfs
    sourcefs: squashfs
    destination: ""
    weight: 4
  - source: /run/live/medium/casper/filesystem.squashfs
    sourcefs: squashfs
    destination: ""
    weight: 4
    condition: "not exists /cdrom/casper/filesystem.squashfs"
MODULE_UNPACKFS

# Create a script to find and symlink the squashfs at boot
mkdir -p /usr/lib/live/config
cat > /usr/lib/live/config/9999-fix-squashfs-path.sh << 'FIXSQUASH'
#!/bin/bash
# Ensure squashfs is accessible at expected path
if [ ! -f /cdrom/casper/filesystem.squashfs ]; then
    if [ -f /run/live/medium/casper/filesystem.squashfs ]; then
        mkdir -p /cdrom/casper
        ln -sf /run/live/medium/casper/filesystem.squashfs /cdrom/casper/filesystem.squashfs
    elif [ -f /lib/live/mount/medium/casper/filesystem.squashfs ]; then
        mkdir -p /cdrom/casper
        ln -sf /lib/live/mount/medium/casper/filesystem.squashfs /cdrom/casper/filesystem.squashfs
    fi
fi
FIXSQUASH
chmod +x /usr/lib/live/config/9999-fix-squashfs-path.sh

# Also run fix at calamares start via the launcher
cat > /usr/local/bin/fix-squashfs-path << 'FIXSQUASH2'
#!/bin/bash
# Ensure squashfs is accessible at expected path before Calamares starts
for src in /run/live/medium/casper/filesystem.squashfs \
           /lib/live/mount/medium/casper/filesystem.squashfs \
           /live/image/casper/filesystem.squashfs; do
    if [ -f "$src" ]; then
        mkdir -p /cdrom/casper
        ln -sf "$src" /cdrom/casper/filesystem.squashfs 2>/dev/null || true
        break
    fi
done
FIXSQUASH2
chmod +x /usr/local/bin/fix-squashfs-path

# Create mount configuration
cat > /etc/calamares/modules/mount.conf << 'MODULE_MOUNT'
---
extraMounts:
  - device: proc
    fs: proc
    mountPoint: /proc
  - device: sys
    fs: sysfs
    mountPoint: /sys
  - device: /dev
    mountPoint: /dev
    options: bind
  - device: tmpfs
    fs: tmpfs
    mountPoint: /run
  - device: /run/udev
    mountPoint: /run/udev
    options: bind
btrfsSubvolumes:
  - mountPoint: /
    subvolume: /@
  - mountPoint: /home
    subvolume: /@home
mountOptions:
  - filesystem: default
    options: [ defaults, noatime ]
  - filesystem: btrfs
    options: [ defaults, noatime, compress=zstd ]
MODULE_MOUNT

# Create machineid configuration
cat > /etc/calamares/modules/machineid.conf << 'MODULE_MACHINEID'
---
systemd: true
dbus: true
symlink: true
MODULE_MACHINEID

# Create fstab configuration
cat > /etc/calamares/modules/fstab.conf << 'MODULE_FSTAB'
---
mountOptions:
  default: defaults,noatime
  btrfs: defaults,noatime,compress=zstd
ssdExtraMountOptions:
  btrfs: discard=async,ssd
crypttabOptions: luks
MODULE_FSTAB

# Create localecfg configuration
cat > /etc/calamares/modules/localecfg.conf << 'MODULE_LOCALECFG'
---
# No specific configuration needed, uses defaults
MODULE_LOCALECFG

# Create networkcfg configuration
cat > /etc/calamares/modules/networkcfg.conf << 'MODULE_NETWORKCFG'
---
# NetworkManager is used by default
MODULE_NETWORKCFG

# Create hwclock configuration  
cat > /etc/calamares/modules/hwclock.conf << 'MODULE_HWCLOCK'
---
hwclock: utc
MODULE_HWCLOCK

# Create finished configuration
cat > /etc/calamares/modules/finished.conf << 'MODULE_FINISHED'
---
restartNowEnabled: true
restartNowChecked: true
restartNowCommand: "systemctl reboot"
notifyOnFinished: true
MODULE_FINISHED

# Create branding configuration
mkdir -p /etc/calamares/branding/nekodevos
cat > /etc/calamares/branding/nekodevos/branding.desc << 'BRANDING'
---
componentName: nekodevos

welcomeStyleCalamares: true
welcomeExpandingLogo: false

windowExpanding: noexpand
windowSize: 900px,550px
windowPlacement: center

sidebar: widget

strings:
    productName:         NekoDevOS
    shortProductName:    NekoDevOS
    version:             1.0
    shortVersion:        1.0
    versionedName:       NekoDevOS 1.0
    shortVersionedName:  NekoDevOS 1.0
    bootloaderEntryName: NekoDevOS
    productUrl:          https://github.com/hinatanguyen/NekoDevOS
    supportUrl:          https://github.com/hinatanguyen/NekoDevOS/issues
    knownIssuesUrl:      https://github.com/hinatanguyen/NekoDevOS/issues
    releaseNotesUrl:     https://github.com/hinatanguyen/NekoDevOS/releases

images:
    productLogo:         "logo.png"
    productIcon:         "icon.png"
    productWelcome:      "wallpaper.png"

slideshow:               "show.qml"
slideshowAPI: 2

style:
   SidebarBackground:    "#331144"
   SidebarText:          "#FFFFFF"
   SidebarTextSelect:    "#331144"
   SidebarTextHighlight: "#FF69B4"
BRANDING

# Create slideshow QML
cat > /etc/calamares/branding/nekodevos/show.qml << 'SHOWQML'
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#331144"
            Text {
                anchors.centerIn: parent
                text: "Installing NekoDevOS..."
                color: "#FFFFFF"
                font.pixelSize: 32
            }
        }
    }
}
SHOWQML

# Create basic placeholder images
touch /etc/calamares/branding/nekodevos/{logo.png,wallpaper.png,icon.png}

# Create a robust launcher script that chooses the right elevation method
install -d /usr/local/bin
cat > /usr/local/bin/launch-calamares << 'LAUNCH'
#!/bin/bash
# Don't use set -e here - we need all the elif checks to work properly

# First, fix the squashfs path
/usr/local/bin/fix-squashfs-path 2>/dev/null || true

if command -v calamares_polkit >/dev/null 2>&1; then
    exec calamares_polkit "$@"
elif command -v pkexec >/dev/null 2>&1; then
    exec pkexec /usr/bin/calamares "$@"
else
    # Fallback: try sudo if available
    if command -v sudo >/dev/null 2>&1; then
        exec sudo -E /usr/bin/calamares "$@"
    else
        # Last resort: run directly (may not have proper privileges)
        exec /usr/bin/calamares "$@"
    fi
fi
LAUNCH
chmod +x /usr/local/bin/launch-calamares

# Create desktop launcher for Calamares
mkdir -p /usr/share/applications
cat > /usr/share/applications/calamares.desktop << 'CALAMARES_DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Exec=/usr/local/bin/launch-calamares
Name=Install NekoDevOS
Comment=Install NekoDevOS to your computer
Icon=system-software-install
Terminal=false
Categories=System;Settings;
NoDisplay=false
StartupNotify=true
Keywords=installer;setup;system;install;NekoDevOS;
X-GNOME-Autostart-enabled=false
CALAMARES_DESKTOP

# Ensure the desktop file is valid
desktop-file-validate /usr/share/applications/calamares.desktop 2>/dev/null || true

# Create the installer icon on the live desktop
mkdir -p /root/Desktop
cp /usr/share/applications/calamares.desktop /root/Desktop/
chmod +x /root/Desktop/calamares.desktop

# Mark desktop file as trusted for XFCE (prevents "untrusted application" dialog)
mkdir -p /root/.local/share/glib-2.0/schemas
gio set /root/Desktop/calamares.desktop metadata::trusted true 2>/dev/null || true

# Create launcher for all users (in case multiple users boot the live session)
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/calamares.desktop /etc/skel/Desktop/
chmod +x /etc/skel/Desktop/calamares.desktop

# Make sure Calamares binary is executable
chmod +x /usr/bin/calamares

# Create Polkit rule to allow live user to run Calamares without password
echo -e "${CYAN}[NEKO]${NC} Configuring Polkit for passwordless installer access..."
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-nopasswd-calamares.rules << 'POLKIT_RULES'
/* Allow members of the sudo group to run Calamares without authentication */
polkit.addRule(function(action, subject) {
    if (action.id == "com.github.calamares.calamares.pkexec.run" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
POLKIT_RULES

# Also create a local authority file for older polkit versions
mkdir -p /etc/polkit-1/localauthority/50-local.d
cat > /etc/polkit-1/localauthority/50-local.d/calamares.pkla << 'POLKIT_PKLA'
[Allow calamares without password]
Identity=unix-group:sudo
Action=com.github.calamares.calamares.pkexec.run
ResultAny=yes
ResultInactive=yes
ResultActive=yes
POLKIT_PKLA

echo -e "${CYAN}[NEKO]${NC} Calamares installer desktop shortcut created."

# Create a wrapper for ubiquity that fixes debconf before launching
if [ -f /usr/bin/ubiquity ]; then
    mv /usr/bin/ubiquity /usr/bin/ubiquity-real
    cat > /usr/bin/ubiquity << 'UBIQUITY_WRAPPER'
#!/bin/bash
# Wrapper to fix debconf before launching ubiquity

# Set environment
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes
export PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH

# Preload safe debconf module
export PYTHONSTARTUP=/usr/lib/python3/dist-packages/debconf_safe.py

# Fix debconf
/usr/local/sbin/fix-debconf-live.sh

# Patch debconf.py on-the-fly if needed to fix "wrong version" error
if [ -f /usr/lib/python3/dist-packages/debconf.py ]; then
    python3 << 'PATCH_SCRIPT'
import re

try:
    with open('/usr/lib/python3/dist-packages/debconf.py', 'r') as f:
        content = f.read()
    
    modified = False
    
    # Fix 1: status = int(status) handling
    if 'status = int(status)' in content and 'if status and str(status)' not in content:
        content = content.replace('status = int(status)', 'status = int(status) if status and str(status).strip() else 0')
        modified = True
    
    # Fix 2: Version check - handle empty version string
    old_check = "if self.version[:2] != '2.':"
    new_check = "if not self.version or self.version[:2] != '2.':"
    if old_check in content and "if not self.version" not in content:
        content = content.replace(old_check, new_check)
        modified = True
    
    # Fix 3: Handle the DebconfError raise by making version default to '2.0'
    old_raise = 'raise DebconfError(256, "wrong version: %s" % self.version)'
    new_raise = 'self.version = "2.0"  # Default to compatible version instead of raising'
    if old_raise in content:
        content = content.replace(old_raise, new_raise)
        modified = True
    
    # Fix 4: Handle version() call returning empty
    old_version_call = 'self.version = self.version(2)'
    new_version_call = '''try:
            self.version = self.version(2) or "2.0"
        except:
            self.version = "2.0"'''
    if old_version_call in content and 'try:' not in content[content.find('setUp'):content.find('setUp')+200]:
        content = content.replace(old_version_call, new_version_call)
        modified = True
    
    if modified:
        with open('/usr/lib/python3/dist-packages/debconf.py', 'w') as f:
            f.write(content)
except Exception as e:
    pass  # Silently continue if patching fails
PATCH_SCRIPT
fi

# Launch real ubiquity
exec /usr/bin/ubiquity-real "$@"
UBIQUITY_WRAPPER
    chmod +x /usr/bin/ubiquity
fi

# Rename the installer application system-wide and hide by default
echo -e "${CYAN}[NEKO]${NC} Customizing installer name..."
if [ -f /usr/share/applications/ubiquity.desktop ]; then
    sed -i 's/^Name=.*/Name=Install NekoDevOS/' /usr/share/applications/ubiquity.desktop
    sed -i 's/^Comment=.*/Comment=Install NekoDevOS to your computer/' /usr/share/applications/ubiquity.desktop
    sed -i 's/^Icon=.*/Icon=system-software-install/' /usr/share/applications/ubiquity.desktop
    # Hide installer from menu by default (will be shown only in install mode)
    sed -i '/^NoDisplay=/d' /usr/share/applications/ubiquity.desktop
    echo "NoDisplay=true" >> /usr/share/applications/ubiquity.desktop
fi

# Customize Ubiquity installer text to replace "Ubuntu" with "NekoDevOS"
echo -e "${CYAN}[NEKO]${NC} Customizing Ubiquity installer branding..."
# Only replace user-facing strings, not technical identifiers
if [ -d /usr/share/ubiquity ]; then
    # Replace in UI/GTK files only (not Python code)
    find /usr/share/ubiquity -type f \( -name "*.ui" -o -name "*.glade" \) -exec sed -i 's/>Ubuntu</>NekoDevOS</g' {} \; 2>/dev/null || true
    # Replace in template files
    find /usr/share/ubiquity -type f -name "*.xml" -exec sed -i 's/>Ubuntu</>NekoDevOS</g' {} \; 2>/dev/null || true
fi

# Replace in slideshow (safe as it's only user-facing content)
if [ -d /usr/share/ubiquity-slideshow ]; then
    find /usr/share/ubiquity-slideshow -type f \( -name "*.html" -o -name "*.txt" \) -exec sed -i 's/Ubuntu/NekoDevOS/g' {} \; 2>/dev/null || true
fi

# Replace Ubuntu branding in locale/translation files
echo -e "${CYAN}[NEKO]${NC} Updating installer translations..."
if [ -d /usr/lib/ubiquity ]; then
    # Create custom branding override
    mkdir -p /usr/lib/ubiquity/branding
    cat > /usr/lib/ubiquity/branding/nekodeos.py << 'PYEOF'
# NekoDevOS Branding Override
import os
import sys

def get_release():
    return {
        'name': 'NekoDevOS',
        'version': '1.0',
        'codename': 'neko'
    }

def get_distribution():
    return 'NekoDevOS'

PYEOF
    
    # Patch ubiquity to use our branding
    if [ -f /usr/lib/ubiquity/ubiquity/misc.py ]; then
        # Create backup
        cp /usr/lib/ubiquity/ubiquity/misc.py /usr/lib/ubiquity/ubiquity/misc.py.bak 2>/dev/null || true
        # Inject our branding at the top
        sed -i '/^import/a try:\n    from branding.nekodeos import get_distribution, get_release\n    DISTRIBUTION = get_distribution()\n    RELEASE = get_release()\nexcept:\n    pass' /usr/lib/ubiquity/ubiquity/misc.py 2>/dev/null || true
    fi
fi

# Replace in D-Bus and PolicyKit files
if [ -d /usr/share/polkit-1 ]; then
    find /usr/share/polkit-1 -type f -name "*.policy" -exec sed -i 's/Ubuntu/NekoDevOS/g' {} \; 2>/dev/null || true
fi

# Patch Ubiquity partition page strings directly
echo -e "${CYAN}[NEKO]${NC} Patching installer dialog strings..."

# Patch all Python files in ubiquity for user-facing strings
find /usr/lib/ubiquity -type f -name "*.py" -exec sed -i \
    -e "s/'Ubuntu'/'NekoDevOS'/g" \
    -e 's/"Ubuntu"/"NekoDevOS"/g' \
    -e "s/Erase disk and install Ubuntu/Erase disk and install NekoDevOS/g" \
    -e "s/Install Ubuntu/Install NekoDevOS/g" \
    -e "s/install Ubuntu/install NekoDevOS/g" \
    -e "s/for Ubuntu/for NekoDevOS/g" \
    -e "s/to Ubuntu/to NekoDevOS/g" \
    -e "s/ Ubuntu/ NekoDevOS/g" \
    {} \; 2>/dev/null || true

# Patch gettext translation files (.po and .mo)
echo -e "${CYAN}[NEKO]${NC} Patching translation catalogs..."
if [ -d /usr/share/locale ]; then
    # Find and patch .po files if they exist
    find /usr/share/locale -type f -name "ubiquity.po" -exec sed -i \
        -e 's/msgstr "Ubuntu"/msgstr "NekoDevOS"/g' \
        -e 's/msgstr "install Ubuntu"/msgstr "install NekoDevOS"/g' \
        -e 's/msgstr "Erase disk and install Ubuntu"/msgstr "Erase disk and install NekoDevOS"/g' \
        -e 's/msgstr "for Ubuntu"/msgstr "for NekoDevOS"/g' \
        {} \; 2>/dev/null || true
    
    # Decompile, patch, and recompile .mo files
    for mofile in $(find /usr/share/locale -type f -name "ubiquity.mo" 2>/dev/null); do
        pofile="${mofile%.mo}.po"
        # Decompile .mo to .po
        msgunfmt "$mofile" -o "$pofile" 2>/dev/null || continue
        # Patch the .po file
        sed -i \
            -e 's/msgstr "Ubuntu"/msgstr "NekoDevOS"/g' \
            -e 's/msgstr "install Ubuntu"/msgstr "install NekoDevOS"/g' \
            -e 's/msgstr "Erase disk and install Ubuntu"/msgstr "Erase disk and install NekoDevOS"/g' \
            -e 's/msgstr "for Ubuntu"/msgstr "for NekoDevOS"/g' \
            -e 's/msgstr ".*Ubuntu\."/msgstr "NekoDevOS."/g' \
            "$pofile" 2>/dev/null || continue
        # Recompile .po to .mo
        msgfmt "$pofile" -o "$mofile" 2>/dev/null || continue
        # Clean up temporary .po file
        rm -f "$pofile"
    done
fi

# Patch GTK UI files directly
find /usr/share/ubiquity -type f \( -name "*.ui" -o -name "*.glade" \) -exec sed -i \
    -e 's/>Ubuntu</>NekoDevOS</g' \
    -e 's/"Ubuntu"/"NekoDevOS"/g' \
    -e "s/'Ubuntu'/'NekoDevOS'/g" \
    {} \; 2>/dev/null || true

# Patch hostname generation in ubiquity
echo -e "${CYAN}[NEKO]${NC} Patching hostname generation..."
if [ -f /usr/lib/ubiquity/ubiquity/misc.py ]; then
    # Replace Ubuntu in hostname suggestions with NekoDev
    sed -i \
        -e "s/Ubuntu/NekoDev/g" \
        -e "s/ubuntu/nekodev/g" \
        /usr/lib/ubiquity/ubiquity/misc.py 2>/dev/null || true
fi

# Also patch the validation and hostname generation files
find /usr/lib/ubiquity -type f -name "*.py" -exec sed -i \
    -e "s/-Ubuntu-/-NekoDev-/g" \
    -e "s/_Ubuntu_/_NekoDev_/g" \
    {} \; 2>/dev/null || true

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
ID_LIKE=debian
PRETTY_NAME="NekoDevOS 1.0"
VERSION_ID="1.0"
HOME_URL="https://github.com/hinatanguyen/NekoDevOS"
SUPPORT_URL="https://github.com/hinatanguyen/NekoDevOS/issues"
BUG_REPORT_URL="https://github.com/hinatanguyen/NekoDevOS/issues"
PRIVACY_POLICY_URL="https://github.com/hinatanguyen/NekoDevOS"
VERSION_CODENAME=neko
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
groupadd -f autologin || true
groupadd -f nopasswdlogin || true

# Create user with all necessary groups for autologin
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,video,audio,users,autologin,nopasswdlogin -c "Neko User" neko || true

# Add user to additional groups if they exist
usermod -a -G plugdev neko 2>/dev/null || true
usermod -a -G lpadmin neko 2>/dev/null || true

# Set password (empty for autologin)
passwd -d neko 2>/dev/null || echo "neko:neko" | chpasswd

# Add sudo permissions
echo "neko ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Ensure home directory permissions
chown -R neko:neko /home/neko
chmod 755 /home/neko

# Configure XFCE default applications
echo -e "${CYAN}[NEKO]${NC} Configuring default applications..."
mkdir -p /home/neko/.config/xfce4
cat > /home/neko/.config/xfce4/helpers.rc << 'EOF'
WebBrowser=firefox
FileManager=Thunar
TerminalEmulator=xfce4-terminal
EOF

# Configure XFCE panel - macOS style (top panel only, small and clean)
echo -e "${CYAN}[NEKO]${NC} Configuring macOS-style panel..."
mkdir -p /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="size" type="uint" value="28"/>
      <property name="length" type="uint" value="100"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
      </property>
      <property name="background-style" type="uint" value="0"/>
      <property name="background-alpha" type="uint" value="80"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu">
      <property name="button-icon" type="string" value="xfce4-panel-menu"/>
      <property name="show-button-title" type="bool" value="false"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-4" type="string" value="clock">
      <property name="digital-format" type="string" value="%a %b %d  %H:%M"/>
      <property name="mode" type="uint" value="2"/>
    </property>
    <property name="plugin-5" type="string" value="actions">
      <property name="appearance" type="uint" value="0"/>
      <property name="items" type="array">
        <value type="string" value="+logout-dialog"/>
        <value type="string" value="-switch-user"/>
        <value type="string" value="-separator"/>
        <value type="string" value="-lock-screen"/>
      </property>
    </property>
  </property>
</channel>
EOF

# Set Firefox as default browser system-wide
update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/firefox 2>/dev/null || true

# Configure XFCE icon theme and appearance
mkdir -p /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita"/>
    <property name="IconThemeName" type="string" value="Papirus"/>
    <property name="DoubleClickTime" type="int" value="400"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
    <property name="DndDragThreshold" type="int" value="8"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="SoundThemeName" type="string" value="default"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CanChangeAccels" type="bool" value="false"/>
    <property name="ColorPalette" type="string" value="black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:goldenrod4:dodger blue:pink:light green:gray10:gray30:gray75:gray90"/>
    <property name="FontName" type="string" value="Sans 10"/>
    <property name="MonospaceFontName" type="string" value="Monospace 10"/>
    <property name="IconSizes" type="string" value=""/>
    <property name="KeyThemeName" type="string" value=""/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="int" value="3"/>
    <property name="IMPreeditStyle" type="string" value=""/>
    <property name="IMStatusStyle" type="string" value=""/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuBarAccel" type="string" value="F10"/>
    <property name="CursorThemeName" type="string" value=""/>
    <property name="CursorThemeSize" type="int" value="0"/>
    <property name="IMModule" type="string" value=""/>
  </property>
</channel>
EOF
chown neko:neko /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

# Create mimeapps.list for default applications
mkdir -p /home/neko/.config
cat > /home/neko/.config/mimeapps.list << 'EOF'
[Default Applications]
text/html=firefox.desktop
text/xml=firefox.desktop
application/xhtml+xml=firefox.desktop
application/xml=firefox.desktop
application/rss+xml=firefox.desktop
application/rdf+xml=firefox.desktop
image/gif=firefox.desktop
image/jpeg=firefox.desktop
image/png=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
x-scheme-handler/ftp=firefox.desktop
x-scheme-handler/chrome=firefox.desktop
video/webm=firefox.desktop
application/x-xpinstall=firefox.desktop
inode/directory=thunar.desktop
EOF

# Enable auto-login for live session
echo -e "${CYAN}[NEKO]${NC} Configuring LightDM autologin..."

# Configure main LightDM config with live session support
cat > /etc/lightdm/lightdm.conf << 'EOF'
[LightDM]
run-directory=/run/lightdm

[Seat:*]
autologin-guest=false
autologin-user=neko
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
greeter-hide-users=false
greeter-show-manual-login=false
allow-guest=false
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
EOF

# Also add to conf.d for redundancy and override
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'EOF'
[Seat:*]
autologin-user=neko
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
autologin-guest=false
greeter-hide-users=false
greeter-show-manual-login=false
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
EOF

# Ensure the lightdm-autologin PAM service exists
cat > /etc/pam.d/lightdm-autologin << 'EOF'
#%PAM-1.0
auth     requisite pam_nologin.so
auth     required  pam_succeed_if.so user != root quiet_success
auth     sufficient pam_succeed_if.so user ingroup nopasswdlogin
auth     required  pam_permit.so
@include common-account
session  required  pam_limits.so
@include common-session
@include common-password
EOF

# Change login screen branding from Ubuntu to Debian/NekoDevOS
cat > /etc/issue << EOF
NekoDevOS \\n \\l
Debian-based Developer Edition

EOF

cat > /etc/issue.net << EOF
NekoDevOS - Debian-based Developer Edition
EOF

# Configure casper for live session autologin
echo -e "${CYAN}[NEKO]${NC} Configuring Casper for live session..."
cat > /etc/casper.conf << EOF
export USERNAME="neko"
export USERFULLNAME="Neko User"
export HOST="nekodeos"
export BUILD_SYSTEM="NekoDevOS"
export FLAVOUR="Ubuntu"
EOF

# Create hook to copy casper.conf to initramfs
cat > /etc/initramfs-tools/hooks/casper-config << 'EOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0 ;;
esac

# Ensure casper.conf is in initramfs
mkdir -p "${DESTDIR}/etc"
if [ -f /etc/casper.conf ]; then
    cp /etc/casper.conf "${DESTDIR}/etc/casper.conf"
fi

exit 0
EOF
chmod +x /etc/initramfs-tools/hooks/casper-config

# Create casper-bottom script to force autologin after user creation
mkdir -p /etc/initramfs-tools/scripts/casper-bottom
cat > /etc/initramfs-tools/scripts/casper-bottom/99autologin << 'EOF'
#!/bin/sh

PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /scripts/casper-functions

# Get the live username
USERNAME="$(cat /etc/casper.conf | grep USERNAME | cut -d= -f2 | tr -d '"')"
[ -z "$USERNAME" ] && USERNAME="neko"

log_begin_msg "Configuring autologin for $USERNAME"

# Ensure the user is in autologin and nopasswdlogin groups in the live system
chroot /root usermod -a -G autologin,nopasswdlogin $USERNAME 2>/dev/null || true

# Write autologin config to the live system - OVERWRITE EVERYTHING
mkdir -p /root/etc/lightdm/lightdm.conf.d

# Main config
cat > /root/etc/lightdm/lightdm.conf << LIGHTDM_MAIN_EOF
[LightDM]
run-directory=/run/lightdm

[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
autologin-guest=false
allow-guest=false
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
greeter-show-manual-login=false
greeter-hide-users=false
LIGHTDM_MAIN_EOF

# Override config
cat > /root/etc/lightdm/lightdm.conf.d/99-autologin.conf << LIGHTDM_EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
greeter-show-manual-login=false
greeter-hide-users=false
autologin-guest=false
allow-guest=false
LIGHTDM_EOF

# AccountsService config
mkdir -p /root/var/lib/AccountsService/users
cat > /root/var/lib/AccountsService/users/$USERNAME << ACCOUNTS_EOF
[User]
SystemAccount=false
AutomaticLogin=true
ACCOUNTS_EOF

# Ensure PAM autologin service exists
cat > /root/etc/pam.d/lightdm-autologin << PAM_EOF
#%PAM-1.0
auth     requisite pam_nologin.so
auth     required  pam_succeed_if.so user != root quiet_success
@include common-auth
auth     optional  pam_group.so
auth     required  pam_permit.so
@include common-account
session  required  pam_limits.so
@include common-session
@include common-password
PAM_EOF

log_end_msg

exit 0
EOF
chmod +x /etc/initramfs-tools/scripts/casper-bottom/99autologin

# Create systemd override for LightDM to wait for user and force autologin
mkdir -p /etc/systemd/system/lightdm.service.d
cat > /etc/systemd/system/lightdm.service.d/autologin.conf << 'EOF'
[Unit]
After=setup-autologin.service
Requires=setup-autologin.service

[Service]
# Wait for casper to create the live user
ExecStartPre=/bin/sh -c 'timeout 30 sh -c "until id neko 2>/dev/null; do sleep 0.5; done" || true'
# Force autologin configuration right before starting
ExecStartPre=/usr/local/bin/setup-autologin.sh
EOF

# Configure getty autologin as fallback
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin neko --noclear %I $TERM
Type=idle
EOF

# Create AccountsService configuration for autologin
mkdir -p /var/lib/AccountsService/users
cat > /var/lib/AccountsService/users/neko << 'EOF'
[User]
SystemAccount=false
AutomaticLogin=true
EOF

# Create a systemd service to enforce autologin at boot
cat > /etc/systemd/system/setup-autologin.service << 'EOF'
[Unit]
Description=Setup Autologin for Live Session
Before=lightdm.service display-manager.service
After=casper.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-autologin.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create the script that the service runs
cat > /usr/local/bin/setup-autologin.sh << 'EOF'
#!/bin/bash
# Enforce autologin configuration for live session

# Wait for user to exist
for i in {1..30}; do
    if id neko >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Ensure autologin configuration exists
mkdir -p /etc/lightdm/lightdm.conf.d

# Remove any conflicting configs
rm -f /etc/lightdm/lightdm.conf.d/*greeter*.conf

# Write the most aggressive autologin config
cat > /etc/lightdm/lightdm.conf.d/99-force-autologin.conf << 'LIGHTDM_EOF'
[Seat:*]
autologin-user=neko
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
autologin-guest=false
greeter-hide-users=false
greeter-show-manual-login=false
allow-guest=false
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
LIGHTDM_EOF

# Overwrite main config too
cat > /etc/lightdm/lightdm.conf << 'LIGHTDM_MAIN_EOF'
[LightDM]
run-directory=/run/lightdm

[Seat:*]
autologin-user=neko
autologin-user-timeout=0
autologin-session=xfce
user-session=xfce
greeter-session=lightdm-gtk-greeter
autologin-guest=false
allow-guest=false
pam-service=lightdm-autologin
pam-autologin-service=lightdm-autologin
LIGHTDM_MAIN_EOF

# Ensure the user is in the autologin group
if id neko >/dev/null 2>&1; then
    usermod -a -G autologin,nopasswdlogin neko 2>/dev/null || true
    
    # Create AccountsService config
    mkdir -p /var/lib/AccountsService/users
    cat > /var/lib/AccountsService/users/neko << 'ACCOUNTS_EOF'
[User]
SystemAccount=false
AutomaticLogin=true
ACCOUNTS_EOF
fi

exit 0
EOF

chmod +x /usr/local/bin/setup-autologin.sh

# Enable the autologin setup service
systemctl enable setup-autologin.service || true

# Enable LightDM display manager service
echo -e "${CYAN}[NEKO]${NC} Enabling LightDM display manager..."
systemctl enable lightdm.service || true
systemctl set-default graphical.target || true

# Ensure X.Org server is installed
apt-get install -y xserver-xorg xinit --no-install-recommends || true

# Install Plymouth for splash screen
echo -e "${CYAN}[NEKO]${NC} Installing Plymouth for splash screen..."
apt-get install -y plymouth plymouth-themes --no-install-recommends

# Create custom minimal Plymouth theme - black screen with logo
echo -e "${CYAN}[NEKO]${NC} Creating minimal NekoDevOS splash theme..."
mkdir -p /usr/share/plymouth/themes/nekodeos-minimal

# Create the Plymouth theme script (minimal - just logo on black)
cat > /usr/share/plymouth/themes/nekodeos-minimal/nekodeos-minimal.script << 'EOF'
# Simple black background with centered logo

# Set background to black
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

# Load and display logo in center
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth() / 2 - logo.image.GetWidth() / 2, 
                        Window.GetHeight() / 2 - logo.image.GetHeight() / 2, 
                        10000);

# Simple refresh function
fun refresh_callback() {}
Plymouth.SetRefreshFunction(refresh_callback);
EOF

# Create Plymouth theme configuration
cat > /usr/share/plymouth/themes/nekodeos-minimal/nekodeos-minimal.plymouth << 'EOF'
[Plymouth Theme]
Name=NekoDevOS Minimal
Description=Simple black screen with NekoDevOS logo
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/nekodeos-minimal
ScriptFile=/usr/share/plymouth/themes/nekodeos-minimal/nekodeos-minimal.script
EOF

# Create a simple logo (using ASCII art converted to text-based approach)
# We'll use the bgrt theme as base which is minimal
cp /usr/share/plymouth/themes/bgrt/bgrt.plymouth /usr/share/plymouth/themes/nekodeos-minimal/ 2>/dev/null || true

# Set as default theme
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/nekodeos-minimal/nekodeos-minimal.plymouth 100
update-alternatives --set default.plymouth /usr/share/plymouth/themes/nekodeos-minimal/nekodeos-minimal.plymouth

# Configure Plymouth daemon
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf << 'EOF'
[Daemon]
Theme=nekodeos-minimal
ShowDelay=0
DeviceTimeout=5
EOF

# Configure initramfs for casper live boot
echo -e "${CYAN}[NEKO]${NC} Configuring initramfs for live boot..."

# Ensure casper is configured properly in initramfs
mkdir -p /etc/initramfs-tools/conf.d
cat > /etc/initramfs-tools/conf.d/casper << 'EOF'
# Casper configuration for live boot
BOOT=casper
MODULES=most
COMPRESS=gzip
EOF

# Check if overlay is built-in or as module
echo -e "${CYAN}[NEKO]${NC} Checking overlay filesystem support..."
echo -e "${CYAN}[NEKO]${NC} Kernel configuration check:"
if grep -q "CONFIG_OVERLAY_FS=y" /boot/config-* 2>/dev/null; then
    echo -e "${GREEN}[NEKO]${NC} ✓ Overlay filesystem is built into kernel (CONFIG_OVERLAY_FS=y)"
    grep "CONFIG_OVERLAY_FS" /boot/config-* 2>/dev/null || true
elif grep -q "CONFIG_OVERLAY_FS=m" /boot/config-* 2>/dev/null; then
    echo -e "${GREEN}[NEKO]${NC} ✓ Overlay filesystem available as module (CONFIG_OVERLAY_FS=m)"
    grep "CONFIG_OVERLAY_FS" /boot/config-* 2>/dev/null || true
else
    echo -e "${CYAN}[NEKO]${NC} ⚠ Overlay not found in kernel config"
fi

echo -e "${CYAN}[NEKO]${NC} Module check:"
if [ -f /lib/modules/*/kernel/fs/overlayfs/overlay.ko* ] || [ -f /lib/modules/*/kernel/fs/overlay/overlay.ko* ]; then
    echo -e "${GREEN}[NEKO]${NC} ✓ Overlay module found:"
    find /lib/modules -name "overlay.ko*" 2>/dev/null | head -3
elif [ -f /lib/modules/*/kernel/fs/overlayfs.ko* ]; then
    echo -e "${GREEN}[NEKO]${NC} ✓ Overlayfs module found:"
    find /lib/modules -name "overlayfs.ko*" 2>/dev/null | head -3
else
    echo -e "${CYAN}[NEKO]${NC} ⚠ No overlay module file found (may be built-in)"
fi

# Configure modprobe to ensure overlay loads
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/overlay.conf << 'EOF'
# Ensure overlay filesystem is available
options overlay index=off
EOF

# Add required modules to initramfs (overwrite to avoid duplicates)
cat > /etc/initramfs-tools/modules << 'EOF'
# NekoDevOS required modules for live boot
# overlay is usually built-in, but we list it anyway
overlay
squashfs
loop
EOF

# Create a custom initramfs hook to ensure overlay is loaded
mkdir -p /etc/initramfs-tools/hooks
cat > /etc/initramfs-tools/hooks/overlay-modules << 'EOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0 ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Copy overlay module if it exists (it might be built-in)
manual_add_modules overlay || true
manual_add_modules overlayfs || true
manual_add_modules squashfs
manual_add_modules loop

# Ensure overlay filesystem support is in initramfs
# Copy modprobe configuration
mkdir -p "${DESTDIR}/etc/modprobe.d"
cp -p /etc/modprobe.d/overlay.conf "${DESTDIR}/etc/modprobe.d/" 2>/dev/null || true

exit 0
EOF
chmod +x /etc/initramfs-tools/hooks/overlay-modules

# Create initramfs script to ensure overlay is available EARLY
mkdir -p /etc/initramfs-tools/scripts/init-premount
cat > /etc/initramfs-tools/scripts/init-premount/00-overlay << 'EOF'
#!/bin/sh
# Load overlay module before anything else (00 prefix ensures it runs first)
PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

# Force load overlay and required modules
/sbin/modprobe -q overlay 2>/dev/null || /sbin/modprobe -q overlayfs 2>/dev/null || true
/sbin/modprobe -q squashfs 2>/dev/null || true
/sbin/modprobe -q loop 2>/dev/null || true

# Verify overlay is loaded
if [ -d /sys/module/overlay ]; then
    echo "Overlay module loaded successfully" >&2
elif grep -q overlay /proc/filesystems 2>/dev/null; then
    echo "Overlay filesystem available (built-in)" >&2
else
    # Last resort - try insmod with full path
    /sbin/insmod /usr/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko 2>/dev/null || true
fi
EOF
chmod +x /etc/initramfs-tools/scripts/init-premount/00-overlay

# Create a casper-premount script to load overlay before casper runs
mkdir -p /etc/initramfs-tools/scripts/casper-premount
cat > /etc/initramfs-tools/scripts/casper-premount/00-load-overlay << 'EOF'
#!/bin/sh

PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

# Ensure overlay module is loaded before casper runs
if [ ! -d /sys/module/overlay ] && ! grep -q overlay /proc/filesystems 2>/dev/null; then
    echo "Loading overlay module for casper..." >&2
    modprobe overlay 2>/dev/null || modprobe overlayfs 2>/dev/null || insmod /usr/lib/modules/*/kernel/fs/overlayfs/overlay.ko 2>/dev/null || true
fi

# Final check
if [ -d /sys/module/overlay ] || grep -q overlay /proc/filesystems 2>/dev/null; then
    echo "Overlay filesystem ready" >&2
else
    echo "WARNING: Overlay filesystem not available" >&2
fi
EOF
chmod +x /etc/initramfs-tools/scripts/casper-premount/00-load-overlay

# Create a hook to patch casper script to completely bypass overlay modprobe check
mkdir -p /etc/initramfs-tools/hooks
cat > /etc/initramfs-tools/hooks/patch-casper << 'EOF'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs) prereqs; exit 0 ;;
esac

# Aggressively patch casper to not panic on overlay modprobe failure
CASPER_SCRIPT="${DESTDIR}/scripts/casper"
if [ -f "$CASPER_SCRIPT" ]; then
    # Replace the entire modprobe overlay line that causes panic
    # Match any line with modprobe and overlay and panic, replace with non-failing version
    sed -i 's/^[[:space:]]*modprobe[[:space:]].*overlay.*||[[:space:]]*panic.*/        modprobe -b overlay 2>\/dev\/null || true  # Patched by NekoDevOS/' "$CASPER_SCRIPT" 2>/dev/null || true
fi

exit 0
EOF
chmod +x /etc/initramfs-tools/hooks/patch-casper

# Update initramfs with all modules
echo -e "${CYAN}[NEKO]${NC} Updating initramfs with overlay support..."
update-initramfs -u -k all

echo -e "${GREEN}[NEKO]${NC} Minimal splash screen configured!"

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

# Custom neofetch ASCII art and config
mkdir -p /home/neko/.config/neofetch
cat > /home/neko/.config/neofetch/config.conf << 'EOF'
# NekoDevOS Custom Config
print_info() {
    prin "$(color 6)╔═══════════════════════════════════╗"
    prin "$(color 6)║       NekoDevOS - Dev Edition     ║"
    prin "$(color 6)╚═══════════════════════════════════╝"
    info "$(color 6)OS" distro
    info "$(color 6)Kernel" kernel
    info "$(color 6)Uptime" uptime
    info "$(color 6)Packages" packages
    info "$(color 6)Shell" shell
    info "$(color 6)Resolution" resolution
    info "$(color 6)DE" de
    info "$(color 6)WM" wm
    info "$(color 6)Terminal" term
    info "$(color 6)CPU" cpu
    info "$(color 6)GPU" gpu
    info "$(color 6)Memory" memory
    prin "$(color 6)Package Manager" "apt"
    echo
    prin "$(color 6)     Made with ♥ by hinatanguyen     "
}

# Custom ASCII art - cute cat
ascii_distro="custom"
ascii_colors=(6 6 7 1)
colors=(6 6 7 1 8 6)

ascii_bold="on"

# Cute neko ASCII
read -rd '' ascii_data <<'ASCII'
${c1}      /\_/\  
${c1}     ( o.o ) 
${c1}      > ^ <
${c1}     /|   |\
${c1}    (_|   |_)
${c2}   NekoDevOS
ASCII

# Performance settings
image_backend="ascii"
image_source="auto"
EOF

# Add neofetch and auto-startx to .bash_profile (runs once at login)
cat > /home/neko/.bash_profile << 'EOF'
# Auto-start X session on tty1 if not already running
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi

# Run neofetch only on first login
if [ -z "$NEOFETCH_RAN" ]; then
    export NEOFETCH_RAN=1
    neofetch
fi

# Source bashrc if it exists
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
EOF

# Create minimal bashrc without neofetch
cat > /home/neko/.bashrc << 'EOF'
# NekoDevOS bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Check window size after each command
shopt -s checkwinsize

# Colored prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# Some useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

chown -R neko:neko /home/neko

# Create .xinitrc for startx with Plank dock and wallpaper
cat > /home/neko/.xinitrc << 'EOF'
#!/bin/sh
# Set wallpaper if custom wallpaper exists
if [ -f /usr/share/backgrounds/nekodeos/wallpaper.jpg ]; then
    (sleep 5 && xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -s /usr/share/backgrounds/nekodeos/wallpaper.jpg 2>/dev/null || true) &
    (sleep 5 && xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -s /usr/share/backgrounds/nekodeos/wallpaper.jpg 2>/dev/null || true) &
    (sleep 5 && xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s /usr/share/backgrounds/nekodeos/wallpaper.jpg 2>/dev/null || true) &
fi

# Start Plank dock in background with delay
(sleep 3 && plank) &

# Start XFCE session
exec startxfce4
EOF
chmod +x /home/neko/.xinitrc
chown neko:neko /home/neko/.xinitrc

# Configure Plank dock (macOS-like, always visible at bottom)
mkdir -p /home/neko/.config/plank/dock1
cat > /home/neko/.config/plank/dock1/settings << 'EOF'
[PlankDockPreferences]
Alignment=center
HideMode=none
IconSize=48
Position=bottom
Theme=Gtk+
ZoomEnabled=true
ZoomPercent=150
ShowDockItem=false
LockItems=false
EOF

# Create launchers directory for Plank
mkdir -p /home/neko/.config/plank/dock1/launchers

# Add Firefox to Plank
cat > /home/neko/.config/plank/dock1/launchers/firefox.dockitem << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/firefox.desktop
EOF

# Add Terminal to Plank
cat > /home/neko/.config/plank/dock1/launchers/xfce4-terminal.dockitem << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/xfce4-terminal.desktop
EOF

# Add File Manager to Plank
cat > /home/neko/.config/plank/dock1/launchers/thunar.dockitem << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/thunar.desktop
EOF

# Add Application Finder to Plank
cat > /home/neko/.config/plank/dock1/launchers/xfce4-appfinder.dockitem << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/xfce4-appfinder.desktop
EOF

chown -R neko:neko /home/neko/.config/plank

# Create desktop shortcuts by copying system desktop files
mkdir -p /home/neko/Desktop

# Copy Calamares installer desktop file (most important for live session!)
cp /usr/share/applications/calamares.desktop /home/neko/Desktop/
chmod +x /home/neko/Desktop/calamares.desktop

# Copy Firefox desktop file
cp /usr/share/applications/firefox.desktop /home/neko/Desktop/
chmod +x /home/neko/Desktop/firefox.desktop

# Copy Terminal desktop file
cp /usr/share/applications/xfce4-terminal.desktop /home/neko/Desktop/
chmod +x /home/neko/Desktop/xfce4-terminal.desktop

# Copy File Manager desktop file
cp /usr/share/applications/thunar.desktop /home/neko/Desktop/
chmod +x /home/neko/Desktop/thunar.desktop

# Copy Application Finder desktop file  
cp /usr/share/applications/xfce4-appfinder.desktop /home/neko/Desktop/
chmod +x /home/neko/Desktop/xfce4-appfinder.desktop

# Create a script to conditionally show installer only in install mode
mkdir -p /home/neko/.local/bin
cat > /home/neko/.local/bin/setup-installer-icon.sh << 'INSTALLER_SCRIPT'
#!/bin/bash
# Only show installer in install-only mode (when only-ubiquity boot parameter is present)
if grep -q "only-ubiquity" /proc/cmdline 2>/dev/null; then
    # We're in install-only mode, show the installer
    if [ -f /usr/share/applications/ubiquity.desktop ]; then
        # Make installer visible in application menu
        sudo sed -i '/^NoDisplay=/d' /usr/share/applications/ubiquity.desktop 2>/dev/null || true
        
        # Copy to desktop
        cp /usr/share/applications/ubiquity.desktop /home/neko/Desktop/
        chmod +x /home/neko/Desktop/ubiquity.desktop
        # Modify the desktop file to have custom name and icon
        sed -i 's/^Name=.*/Name=Install NekoDevOS/' /home/neko/Desktop/ubiquity.desktop
        sed -i 's/^Comment=.*/Comment=Install NekoDevOS to your computer/' /home/neko/Desktop/ubiquity.desktop
        sed -i 's/^Icon=.*/Icon=system-software-install/' /home/neko/Desktop/ubiquity.desktop
    fi
else
    # We're in try mode, hide installer from menu and remove desktop icon
    if [ -f /usr/share/applications/ubiquity.desktop ]; then
        # Hide from application menu
        sudo sed -i '/^NoDisplay=/d' /usr/share/applications/ubiquity.desktop 2>/dev/null || true
        echo "NoDisplay=true" | sudo tee -a /usr/share/applications/ubiquity.desktop >/dev/null 2>&1 || true
    fi
    rm -f /home/neko/Desktop/ubiquity.desktop
fi
INSTALLER_SCRIPT
chmod +x /home/neko/.local/bin/setup-installer-icon.sh
chown neko:neko /home/neko/.local/bin/setup-installer-icon.sh

# Create autostart entry to run the installer setup script with higher priority
mkdir -p /home/neko/.config/autostart
cat > /home/neko/.config/autostart/setup-installer.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Setup Installer Icon
Exec=/home/neko/.local/bin/setup-installer-icon.sh
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=0
Hidden=false
EOF
chmod +x /home/neko/.config/autostart/setup-installer.desktop
chown neko:neko /home/neko/.config/autostart/setup-installer.desktop

# Ensure ubiquity.desktop is NOT on desktop by default (only added at boot if in install mode)
rm -f /home/neko/Desktop/ubiquity.desktop

# Mark all desktop files as trusted
chown -R neko:neko /home/neko/Desktop
chmod -R u+x /home/neko/Desktop/*.desktop

# Trust desktop files for the user
mkdir -p /home/neko/.local/share
cat > /home/neko/.local/share/trusted-launchers << 'EOF'
/home/neko/Desktop/calamares.desktop
/home/neko/Desktop/firefox.desktop
/home/neko/Desktop/xfce4-terminal.desktop
/home/neko/Desktop/thunar.desktop
/home/neko/Desktop/xfce4-appfinder.desktop
EOF
chown -R neko:neko /home/neko/.local

# Configure Plank to autostart with XFCE
mkdir -p /home/neko/.config/autostart
cat > /home/neko/.config/autostart/plank.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Comment=Stupidly simple
Exec=plank
Icon=plank
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
chown -R neko:neko /home/neko/.config/autostart

# Create script to trust desktop files on first boot
cat > /home/neko/.local/bin/trust-desktop-files.sh << 'TRUSTSCRIPT'
#!/bin/bash
# Mark all desktop files on Desktop as trusted
sleep 2  # Wait for desktop to fully initialize
for f in /home/neko/Desktop/*.desktop; do
    if [ -f "$f" ]; then
        gio set "$f" metadata::trusted true 2>/dev/null || true
        chmod +x "$f" 2>/dev/null || true
    fi
done
TRUSTSCRIPT
chmod +x /home/neko/.local/bin/trust-desktop-files.sh
chown neko:neko /home/neko/.local/bin/trust-desktop-files.sh

# Autostart the trust script
cat > /home/neko/.config/autostart/trust-desktop.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Trust Desktop Files
Exec=/home/neko/.local/bin/trust-desktop-files.sh
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chown neko:neko /home/neko/.config/autostart/trust-desktop.desktop

# Create autostart script to set wallpaper (runs after XFCE starts)
cat > /home/neko/.config/autostart/set-wallpaper.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Exec=/home/neko/.local/bin/set-wallpaper.sh
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chown neko:neko /home/neko/.config/autostart/set-wallpaper.desktop

# Create wallpaper setting script
mkdir -p /home/neko/.local/bin
cat > /home/neko/.local/bin/set-wallpaper.sh << 'WALLPAPER_SCRIPT'
#!/bin/bash
sleep 3
WALLPAPER="/usr/share/backgrounds/nekodeos/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    # Set for all possible monitor configurations
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor1/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
    # Generic fallback for any monitor
    for prop in $(xfconf-query -c xfce4-desktop -l | grep last-image); do
        xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" 2>/dev/null || true
    done
fi
WALLPAPER_SCRIPT
chmod +x /home/neko/.local/bin/set-wallpaper.sh
chown neko:neko /home/neko/.local/bin/set-wallpaper.sh

# Set up custom wallpaper if provided
mkdir -p /usr/share/backgrounds/nekodeos
WALLPAPER_SET=false
if [ -f /tmp/wallpaper.jpg ] || [ -f /tmp/wallpaper.png ]; then
    WALLPAPER_FILE=$(ls /tmp/wallpaper.* 2>/dev/null | head -1)
    if [ -n "$WALLPAPER_FILE" ]; then
        cp "$WALLPAPER_FILE" /usr/share/backgrounds/nekodeos/wallpaper.jpg
        chmod 644 /usr/share/backgrounds/nekodeos/wallpaper.jpg
        WALLPAPER_SET=true
        echo -e "${GREEN}[NEKO]${NC} Custom wallpaper installed!"
    fi
fi

# Configure XFCE desktop to show icons properly with custom wallpaper
mkdir -p /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml

if [ "$WALLPAPER_SET" = true ]; then
    # Create backdrop configuration with custom wallpaper for all monitors/workspaces
    cat > /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-home" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
      <property name="show-removable" type="bool" value="false"/>
    </property>
    <property name="icon-size" type="uint" value="48"/>
  </property>
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVirtual1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nekodeos/wallpaper.jpg"/>
        </property>
        <property name="workspace1" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nekodeos/wallpaper.jpg"/>
        </property>
      </property>
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nekodeos/wallpaper.jpg"/>
        </property>
        <property name="workspace1" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/nekodeos/wallpaper.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
else
    # Default configuration without custom wallpaper
    cat > /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-home" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
      <property name="show-removable" type="bool" value="false"/>
    </property>
    <property name="icon-size" type="uint" value="48"/>
  </property>
</channel>
EOF
fi

chown neko:neko /home/neko/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

# Performance optimizations
echo -e "${CYAN}[NEKO]${NC} Applying performance optimizations..."

# Disable unnecessary services
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true
systemctl disable cups-browsed.service 2>/dev/null || true
systemctl disable ModemManager.service 2>/dev/null || true
systemctl disable packagekit.service 2>/dev/null || true
systemctl disable snapd.service 2>/dev/null || true
systemctl disable snapd.socket 2>/dev/null || true
systemctl mask snapd.service 2>/dev/null || true

# Disable apport (error reporting) to save memory
systemctl disable apport.service 2>/dev/null || true

# Remove snap completely
apt-get purge -y snapd 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd 2>/dev/null || true

# Configure swappiness for better performance
echo "vm.swappiness=10" >> /etc/sysctl.conf

# Reduce journal size
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/00-journal-size.conf << 'EOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=50M
EOF

# Clean up
echo -e "${CYAN}[NEKO]${NC} Cleaning up..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /var/cache/apt/archives/*.deb

# Update initramfs
echo -e "${CYAN}[NEKO]${NC} Updating initramfs..."
update-initramfs -u -k all || true

echo -e "${GREEN}[NEKO]${NC} Chroot configuration complete! ฅ^•ﻌ•^ฅ"
