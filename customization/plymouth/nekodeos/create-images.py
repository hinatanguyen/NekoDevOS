#!/usr/bin/env python3
"""
Generate simple placeholder images for NekoDevOS Plymouth theme
This script creates basic PNG images using PIL/Pillow
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    print("✓ PIL/Pillow found")
except ImportError:
    print("✗ Please install Pillow: pip3 install Pillow")
    print("  or: sudo apt install python3-pil")
    exit(1)

import os

# Change to script directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Colors
PINK = (255, 105, 180, 255)      # #FF69B4
PURPLE = (218, 112, 214, 255)     # #DA70D6
DARK_BG = (26, 26, 46, 255)      # #1a1a2e
DARK_TRANS = (26, 26, 46, 220)   # #1a1a2eDD
TRANSPARENT = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)

print("Creating Plymouth theme images...")

# 1. Create logo (400x400)
print("  → Creating logo.png...")
logo = Image.new('RGBA', (400, 400), TRANSPARENT)
draw = ImageDraw.Draw(logo)
draw.ellipse([50, 50, 350, 350], fill=PINK)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40)
    font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 32)
except:
    font = ImageFont.load_default()
    font_small = font

draw.text((200, 160), "NekoDevOS", fill=WHITE, font=font, anchor="mm")
draw.text((200, 220), "Nya~", fill=WHITE, font=font_small, anchor="mm")
draw.text((200, 260), "ฅ^•ﻌ•^ฅ", fill=WHITE, font=font_small, anchor="mm")
logo.save('logo.png')

# 2. Create spinner (64x64) - cat paw style
print("  → Creating spinner.png...")
spinner = Image.new('RGBA', (64, 64), TRANSPARENT)
draw = ImageDraw.Draw(spinner)
# Main pad
draw.ellipse([16, 24, 48, 56], fill=PINK)
# Toe beans
draw.ellipse([12, 8, 24, 20], fill=PURPLE)
draw.ellipse([28, 8, 40, 20], fill=PURPLE)
draw.ellipse([40, 8, 52, 20], fill=PURPLE)
draw.ellipse([20, 12, 32, 24], fill=PURPLE)
spinner.save('spinner.png')

# 3. Create progress box (400x20)
print("  → Creating progress_box.png...")
prog_box = Image.new('RGBA', (400, 20), TRANSPARENT)
draw = ImageDraw.Draw(prog_box)
draw.rounded_rectangle([0, 0, 399, 19], radius=10, fill=DARK_BG, outline=PINK, width=2)
prog_box.save('progress_box.png')

# 4. Create progress bar (400x20) - gradient effect
print("  → Creating progress_bar.png...")
prog_bar = Image.new('RGBA', (400, 20), TRANSPARENT)
for x in range(400):
    # Create gradient from pink to purple
    ratio = x / 400
    r = int(PINK[0] * (1 - ratio) + PURPLE[0] * ratio)
    g = int(PINK[1] * (1 - ratio) + PURPLE[1] * ratio)
    b = int(PINK[2] * (1 - ratio) + PURPLE[2] * ratio)
    color = (r, g, b, 255)
    for y in range(20):
        # Rounded corners
        if (x < 10 and y < 10 and (x-10)**2 + (y-10)**2 > 100):
            continue
        if (x < 10 and y > 9 and (x-10)**2 + (y-9)**2 > 100):
            continue
        if (x > 389 and y < 10 and (x-389)**2 + (y-10)**2 > 100):
            continue
        if (x > 389 and y > 9 and (x-389)**2 + (y-9)**2 > 100):
            continue
        prog_bar.putpixel((x, y), color)
prog_bar.save('progress_bar.png')

# 5. Create dialog box (500x150)
print("  → Creating dialog_box.png...")
dialog = Image.new('RGBA', (500, 150), TRANSPARENT)
draw = ImageDraw.Draw(dialog)
draw.rounded_rectangle([0, 0, 499, 149], radius=15, fill=DARK_TRANS, outline=PINK, width=3)
dialog.save('dialog_box.png')

print("✓ All Plymouth images created successfully!")
print("\nYou can now rebuild your ISO to use the custom Plymouth theme.")
print("To customize further, replace these images with your own anime artwork!")
