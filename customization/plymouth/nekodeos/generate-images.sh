#!/bin/bash
# Script to generate Plymouth theme images
# Run this after installing ImageMagick: sudo apt install imagemagick-6.q16

cd "$(dirname "$0")"

# Create logo
convert -size 400x400 xc:transparent \
    -fill "#FF69B4" -draw "circle 200,200 200,100" \
    -gravity center -pointsize 48 -fill white -font "DejaVu-Sans-Bold" \
    -annotate 0 "NekoDevOS\n    Nya~\n  ฅ^•ﻌ•^ฅ" \
    logo.png

# Create spinner (cat paw style)
convert -size 64x64 xc:transparent \
    -fill "#FF69B4" -draw "circle 32,32 32,16" \
    -fill "#DA70D6" -draw "circle 20,20 20,10" \
    -fill "#DA70D6" -draw "circle 44,20 44,10" \
    -fill "#DA70D6" -draw "circle 20,44 20,10" \
    -fill "#DA70D6" -draw "circle 44,44 44,10" \
    spinner.png

# Create progress box
convert -size 400x20 xc:transparent \
    -fill "#1a1a2e" -draw "roundrectangle 0,0 399,19 10,10" \
    -strokewidth 2 -stroke "#FF69B4" -draw "roundrectangle 1,1 398,18 9,9" \
    progress_box.png

# Create progress bar
convert -size 400x20 xc:transparent \
    -fill "gradient:#FF69B4-#DA70D6" -draw "roundrectangle 0,0 399,19 10,10" \
    progress_bar.png

# Create dialog box
convert -size 500x150 xc:transparent \
    -fill "#1a1a2eDD" -draw "roundrectangle 0,0 499,149 15,15" \
    -strokewidth 3 -stroke "#FF69B4" -draw "roundrectangle 2,2 497,147 14,14" \
    dialog_box.png

echo "Plymouth images created successfully!"
