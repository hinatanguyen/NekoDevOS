# NekoDevOS 🐱💻

<div align="center">

![NekoDevOS](https://img.shields.io/badge/Based%20on-Ubuntu-E95420?style=for-the-badge&logo=ubuntu)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow?style=for-the-badge)

**A weeb-themed Linux distribution built on Ubuntu for developers and anime enthusiasts!**

*Neko (猫) = Cat | Dev = Developer | OS = Operating System*

</div>

---

## 🌸 About

NekoDevOS is a custom Ubuntu-based Linux distribution that combines powerful development tools with anime/manga-inspired aesthetics. It's designed for developers who want a functional workspace with a touch of weeb culture!

## ✨ Features

### 🎨 Weeb Aesthetics
- **Custom anime-themed wallpapers** (rotating collection)
- **Kawaii icon themes** with anime-inspired designs
- **Pastel color schemes** inspired by popular anime
- **Custom GRUB bootloader** with anime artwork
- **Anime-themed Plymouth boot splash**
- **Waifu terminal prompts** (oh-my-zsh/bash themes)

### 💻 Developer-Focused
- **Pre-installed development tools**: VSCode, Git, Docker, Node.js, Python, etc.
- **Multiple IDE support**: VSCode, IntelliJ IDEA Community, Vim/Neovim
- **Container support**: Docker and Podman pre-configured
- **Terminal customization**: Zsh with oh-my-zsh, Starship prompt
- **Development fonts**: JetBrains Mono, Fira Code with ligatures

### 🚀 Desktop Environment
- **KDE Plasma** or **XFCE** (lightweight option)
- Customized with anime themes and widgets
- Japanese/English language support
- Custom Conky widgets with anime art

### 📦 Pre-installed Applications
- **Media**: VLC, MPV (anime-friendly video players)
- **Creative**: GIMP, Inkscape, Blender
- **Browsers**: Firefox with anime themes
- **Communication**: Discord, Telegram
- **Utilities**: Timeshift (backups), Bleachbit (cleanup)

## 🛠️ Building NekoDevOS

### Prerequisites
- Ubuntu 22.04 LTS or newer (host system)
- At least 20GB free disk space
- Root/sudo access
- Stable internet connection
- **Time**: Full build takes 30-60 minutes depending on your connection

### Build Instructions

#### Option 1: Minimal Build (Faster - for testing)
```bash
# Clone the repository
git clone https://github.com/hinatanguyen/NekoDevOS.git
cd NekoDevOS

# Build minimal ISO (no desktop, just bootable system)
sudo ./build-minimal.sh

# The ISO will be created in ./output/
```

#### Option 2: Full Build (Complete NekoDevOS with all features)
```bash
# Clone the repository
git clone https://github.com/hinatanguyen/NekoDevOS.git
cd NekoDevOS

# Install build dependencies (the script will do this, but you can pre-install)
sudo apt update
sudo apt install -y debootstrap squashfs-tools xorriso isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools

# Run the full build script
sudo ./build.sh

# The ISO will be created in ./output/
```

#### Cleaning Up
```bash
# If build fails or you want to start fresh
sudo ./clean.sh
```

## 📥 Installation

1. Download the latest ISO from [Releases](https://github.com/hinatanguyen/NekoDevOS/releases)
2. Create a bootable USB using tools like:
   - **Balena Etcher** (recommended)
   - **Rufus** (Windows)
   - `dd` command (Linux)
3. Boot from USB and follow the installation wizard
4. Enjoy your weeb-dev paradise! 🎉

## 🎯 Post-Installation Setup

After installing NekoDevOS, run the customization script:

```bash
./scripts/customize.sh
```

This will:
- Set up anime wallpapers rotation
- Configure terminal themes
- Install additional anime-themed packages
- Set up development environments

## 📁 Project Structure

```
NekoDevOS/
├── build.sh                 # Main build script
├── config/
│   ├── packages.list        # List of packages to install
│   ├── preseed.cfg          # Automated installation config
│   └── isolinux.cfg         # Boot loader configuration
├── customization/
│   ├── themes/              # Anime themes and icon packs
│   ├── wallpapers/          # Wallpaper collection
│   ├── plymouth/            # Boot splash screens
│   └── grub/                # GRUB themes
├── scripts/
│   ├── customize.sh         # Post-install customization
│   ├── chroot-commands.sh   # Commands to run in chroot
│   └── setup-dev-env.sh     # Development environment setup
└── README.md
```

## 🎨 Customization Options

### Changing Themes
```bash
# Switch to different anime theme
./scripts/switch-theme.sh <theme-name>
```

### Adding Your Own Wallpapers
Place wallpapers in `~/.local/share/wallpapers/neko/` and run:
```bash
./scripts/update-wallpapers.sh
```

## 🤝 Contributing

Contributions are welcome! Whether it's:
- Adding new anime themes
- Improving build scripts
- Suggesting new pre-installed packages
- Fixing bugs

Please feel free to submit issues or pull requests!

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- Based on **Ubuntu** by Canonical
- Inspired by various anime/manga series
- Community theme creators and artists
- All package maintainers

## ⚠️ Disclaimer

This is a fan-made project created for fun and learning. All anime artwork and themes used respect their original creators. If you're a copyright holder and have concerns, please contact me.

## 📞 Contact

- GitHub: [@hinatanguyen](https://github.com/hinatanguyen)
- Issues: [GitHub Issues](https://github.com/hinatanguyen/NekoDevOS/issues)

## 🐛 Troubleshooting

### Build Issues

**Problem**: ISO file not created after running `build.sh`
- **Solution**: Check the terminal output for errors. Common issues:
  - Network problems downloading packages
  - Insufficient disk space (need 20GB+)
  - Missing build dependencies
  - Run `sudo ./clean.sh` and try again

**Problem**: "command not found" errors during build
- **Solution**: The build script now installs prerequisites automatically. If you still see errors, ensure you're on Ubuntu 22.04+ and have internet access.

**Problem**: Build takes too long or gets stuck
- **Solution**: 
  - Try the minimal build first: `sudo ./build-minimal.sh`
  - Check your internet connection
  - Some packages are large (1GB+), be patient

**Problem**: Permission denied errors
- **Solution**: Always run build scripts with `sudo`

### ISO Testing

**Test your ISO in a VM before burning to USB:**
```bash
# Using QEMU (install with: sudo apt install qemu-system-x86)
qemu-system-x86_64 -cdrom output/nekodeos-*.iso -m 2048 -enable-kvm
```

### Getting Help

1. Check the [Issues](https://github.com/hinatanguyen/NekoDevOS/issues) page
2. Search for similar problems
3. Open a new issue with:
   - Error messages
   - Build log output
   - Your Ubuntu version
   - Available disk space

---

<div align="center">

**Made with ❤️ and 🍜 by a weeb developer**

*"Code by day, watch anime by night"* ✨

</div>
