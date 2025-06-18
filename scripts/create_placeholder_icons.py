#!/usr/bin/env python3
"""
Orchard App Icon Placeholder Generator

This script creates simple placeholder app icons for the Orchard app.
These are basic colored rectangles with the app name that will allow
the app to build successfully while you create proper icons.

Usage:
    python3 scripts/create_placeholder_icons.py

Requirements:
    pip install Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont
import sys

def create_placeholder_icon(size, output_path):
    """Create a simple placeholder icon with the specified size."""

    # Create a new image with a nice blue background
    img = Image.new('RGBA', (size, size), (52, 120, 246, 255))  # Nice blue color
    draw = ImageDraw.Draw(img)

    # Add a subtle border
    border_width = max(1, size // 64)
    draw.rectangle([0, 0, size-1, size-1], outline=(30, 90, 200, 255), width=border_width)

    # Try to load a font, fall back to default if not available
    try:
        # Try to find a nice system font
        if size >= 128:
            font_size = size // 8
        elif size >= 64:
            font_size = size // 6
        else:
            font_size = size // 4

        try:
            # Try to use a nice system font (varies by OS)
            font_paths = [
                '/System/Library/Fonts/Helvetica.ttc',  # macOS
                '/System/Library/Fonts/Arial.ttf',      # Windows
                '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',  # Linux
            ]

            font = None
            for font_path in font_paths:
                if os.path.exists(font_path):
                    font = ImageFont.truetype(font_path, font_size)
                    break

            if font is None:
                font = ImageFont.load_default()

        except (OSError, IOError):
            font = ImageFont.load_default()

    except ImportError:
        font = ImageFont.load_default()

    # Add text based on icon size
    if size >= 64:
        text = "OR"  # Orchard abbreviation
    else:
        text = "O"   # Just the first letter for small sizes

    # Get text bounding box and center it
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size - text_width) // 2
    y = (size - text_height) // 2

    # Draw white text with a subtle shadow
    shadow_offset = max(1, size // 128)
    if shadow_offset > 0:
        draw.text((x + shadow_offset, y + shadow_offset), text, fill=(0, 0, 0, 100), font=font)
    draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)

    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created {size}x{size} icon: {output_path}")

def main():
    """Generate all required app icon sizes."""

    # Check if Pillow is installed
    try:
        import PIL
    except ImportError:
        print("Error: Pillow library is required.")
        print("Install it with: pip install Pillow")
        sys.exit(1)

    # Define the icon sizes needed for macOS apps
    icon_sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_32x32.png"),
        (64, "icon_64x64.png"),
        (128, "icon_128x128.png"),
        (256, "icon_256x256.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_1024x1024.png")
    ]

    # Create the output directory path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_icon_dir = os.path.join(script_dir, "..", "Orchard", "Assets.xcassets", "AppIcon.appiconset")

    # Ensure the directory exists
    os.makedirs(app_icon_dir, exist_ok=True)

    print("Generating placeholder app icons for Orchard...")
    print(f"Output directory: {app_icon_dir}")
    print()

    # Generate each icon size
    for size, filename in icon_sizes:
        output_path = os.path.join(app_icon_dir, filename)
        create_placeholder_icon(size, output_path)

    print()
    print("✅ Placeholder icons generated successfully!")
    print()
    print("Your app should now build without icon errors.")
    print("To create proper app icons, see the ICON_GUIDE.md file.")

if __name__ == "__main__":
    main()
