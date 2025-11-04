# NekoDevOS Build Complete! 🎉

## Your ISO File

**Location:** `/home/hinatanguyen/NekoDevOS/output/nekodeos-minimal-amd64.iso`
**Size:** 799 MB
**Type:** Minimal bootable Ubuntu-based live system

## What's Inside

✅ Ubuntu 22.04 (Jammy) base system
✅ Linux kernel 5.15
✅ Network Manager (WiFi/Ethernet support)
✅ Casper (Live session support)
✅ SystemD init system
✅ User account: `neko` / password: `live`
✅ Sudo access enabled

## Next Steps

### 1. Test the ISO in a Virtual Machine

```bash
# Install QEMU if you haven't
sudo apt install qemu-system-x86

# Test the ISO
qemu-system-x86_64 -cdrom output/nekodeos-minimal-amd64.iso -m 2048 -enable-kvm
```

### 2. Create a Bootable USB Drive

#### Using Balena Etcher (Recommended - GUI)
1. Download from: https://www.balena.io/etcher/
2. Select the ISO file
3. Select your USB drive
4. Click "Flash!"

#### Using dd (Linux - Terminal)
```bash
# Find your USB device (e.g., /dev/sdb)
lsblk

# Write ISO to USB (REPLACE /dev/sdX with your USB device!)
sudo dd if=output/nekodeos-minimal-amd64.iso of=/dev/sdX bs=4M status=progress && sync
```

**⚠️ WARNING:** Double-check the device name! Using the wrong device will erase that drive!

### 3. Boot from USB

1. Insert the USB drive
2. Restart your computer
3. Enter BIOS/UEFI (usually F2, F12, Del, or Esc during boot)
4. Set USB as first boot device
5. Save and exit
6. You should see the NekoDevOS boot menu!

### 4. Build the Full NekoDevOS (Optional)

Once you've tested the minimal ISO and it works, build the full version with KDE Plasma and all the weeb customizations:

```bash
# Clean up
sudo ./clean.sh

# Build full version (takes 30-60 minutes)
sudo ./build.sh
```

## Troubleshooting

### ISO doesn't boot
- Make sure Secure Boot is disabled in BIOS
- Try using a different USB port
- Re-create the bootable USB

### "No operating system found"
- The ISO might not have been written correctly
- Try using Balena Etcher instead of dd

### Black screen after booting
- This is normal for the minimal build (no desktop environment)
- Press Ctrl+Alt+F2 to get to a terminal
- Login with: `neko` / `live`

## Build Notes

### Why did the original build fail?

The build script had a bug where `mksquashfs` creation was interrupted. We:
1. Fixed the `lupin-casper` package issue (deprecated in Ubuntu 22.04)
2. Manually created the squashfs filesystem
3. Created the ISO using `genisoimage`

### How to avoid this in the future?

The build scripts have been updated. Future builds should complete without issues.

## What's Different: Minimal vs Full Build

| Feature | Minimal Build | Full Build |
|---------|--------------|------------|
| **Size** | ~800 MB | ~4 GB |
| **Build Time** | 10 min | 30-60 min |
| **Desktop** | ❌ None | ✅ KDE Plasma |
| **Dev Tools** | ❌ None | ✅ VSCode, Git, Docker, etc. |
| **Themes** | ❌ None | ✅ Anime themes |
| **Japanese Support** | ❌ Basic | ✅ Full (fonts + input) |
| **Customization** | ❌ None | ✅ Wallpapers, prompts, etc. |
| **Use Case** | Testing only | Daily use |

## Support

If you encounter any issues:
1. Check the build.log file
2. Open an issue on GitHub
3. Include error messages and your system info

---

**Congratulations on building your first NekoDevOS ISO!** 🐱💻✨

Made with ❤️ and 🍜
