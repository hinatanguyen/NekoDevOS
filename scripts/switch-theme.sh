#!/bin/bash
#
# Switch Theme Script for NekoDevOS
# Quickly switch between different anime-themed color schemes
#

set -e

THEMES=("sakura-pink" "neko-purple" "ocean-blue" "matcha-green" "sunset-orange")

echo "🎨 NekoDevOS Theme Switcher"
echo ""
echo "Available themes:"
echo "  1) sakura-pink   - Cherry blossom pink"
echo "  2) neko-purple   - Cute cat purple"
echo "  3) ocean-blue    - Anime ocean blue"
echo "  4) matcha-green  - Japanese tea green"
echo "  5) sunset-orange - Anime sunset orange"
echo ""
echo -n "Select theme (1-5): "
read -r choice

case $choice in
    1) THEME="sakura-pink" ;;
    2) THEME="neko-purple" ;;
    3) THEME="ocean-blue" ;;
    4) THEME="matcha-green" ;;
    5) THEME="sunset-orange" ;;
    *) echo "Invalid choice!"; exit 1 ;;
esac

echo "Applying theme: $THEME..."

# Apply to KDE Plasma (if available)
if command -v kwriteconfig5 &> /dev/null; then
    case $THEME in
        "sakura-pink")
            kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme "Sakura Pink"
            ;;
        "neko-purple")
            kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme "Neko Purple"
            ;;
        "ocean-blue")
            kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme "Ocean Blue"
            ;;
        "matcha-green")
            kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme "Matcha Green"
            ;;
        "sunset-orange")
            kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme "Sunset Orange"
            ;;
    esac
    
    # Restart plasmashell to apply changes
    killall plasmashell 2>/dev/null || true
    kstart5 plasmashell &>/dev/null &
    
    echo "✨ Theme applied successfully!"
else
    echo "⚠️  KDE Plasma not detected. Theme files are available but need to be applied manually."
fi
