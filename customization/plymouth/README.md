# NekoDevOS Plymouth Theme

This directory contains the custom Plymouth boot splash theme for NekoDevOS.

## Required Images

You need to create/add the following images to the `nekodeos/` directory:

### 1. **logo.png**
- The main logo/character that appears in the center
- Recommended size: 400x400 pixels (or 512x512)
- Should be an anime cat girl character or NekoDevOS logo
- Transparent background (PNG with alpha)

### 2. **spinner.png**
- The spinning loading indicator (e.g., cat paw, gear, or circular spinner)
- Recommended size: 64x64 pixels
- Transparent background
- Should be designed to look good when rotated

### 3. **progress_box.png**
- The background/border for the progress bar
- Recommended size: 400x20 pixels
- Can be a simple rounded rectangle or styled box

### 4. **progress_bar.png**
- The filled part of the progress bar
- Recommended size: 400x20 pixels (will be scaled based on progress)
- Should match the theme colors (pink, purple, or anime-themed)

### 5. **dialog_box.png** (optional, for password prompts)
- Dialog box for password entry during boot
- Recommended size: 500x150 pixels
- Transparent or semi-transparent background

## Quick Start

### Option 1: Simple Placeholder Images
If you want to test the theme first, you can create simple placeholder images:

```bash
cd /home/hinatanguyen/NekoDevOS/customization/plymouth/nekodeos

# Create a simple logo (requires ImageMagick)
convert -size 400x400 xc:transparent \
    -fill "#FF69B4" -draw "circle 200,200 200,100" \
    -gravity center -pointsize 48 -fill white -annotate 0 "NekoDevOS\nNya~" \
    logo.png

# Create a spinner
convert -size 64x64 xc:transparent \
    -fill "#FF69B4" -draw "circle 32,32 32,16" \
    -fill "#DA70D6" -draw "circle 32,32 32,48" \
    spinner.png

# Create progress box
convert -size 400x20 xc:transparent \
    -fill "#333333" -draw "roundrectangle 0,0 400,20 10,10" \
    -strokewidth 2 -stroke "#666666" -draw "roundrectangle 0,0 400,20 10,10" \
    progress_box.png

# Create progress bar
convert -size 400x20 xc:transparent \
    -fill "gradient:#FF69B4-#DA70D6" -draw "roundrectangle 0,0 400,20 10,10" \
    progress_bar.png

# Create dialog box
convert -size 500x150 xc:transparent \
    -fill "#222222DD" -draw "roundrectangle 0,0 500,150 15,15" \
    -strokewidth 2 -stroke "#FF69B4" -draw "roundrectangle 0,0 500,150 15,15" \
    dialog_box.png
```

### Option 2: Custom Anime Art
Replace the images with your own anime cat girl artwork or NekoDevOS branding.

## Theme Colors

The current theme uses:
- Background: Dark blue-purple gradient
- Accent: Pink (#FF69B4) and Purple (#DA70D6)
- Text: White

You can customize colors by editing `nekodeos.script`.

## Testing

After adding images and rebuilding the ISO, you can test Plymouth in QEMU or on real hardware during boot.

## Customization

Edit `nekodeos.script` to:
- Change colors
- Adjust animation speed
- Modify text messages
- Change positioning of elements
