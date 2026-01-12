#!/usr/bin/env python3
"""
Simple script to generate HM app icon
Requires: pip install Pillow
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os

    # Create 1024x1024 image
    size = 1024
    img = Image.new('RGB', (size, size), color='#4CAF50')
    draw = ImageDraw.Draw(img)

    # Try to load a font, fallback to default if not available
    try:
        # Try to use a system font
        font_size = 300
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", font_size)
            except:
                font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    # Draw "HM" text in center
    text = "HM"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    position = ((size - text_width) // 2, (size - text_height) // 2)
    draw.text(position, text, fill='white', font=font)

    # Save the image
    output_path = 'app_icon.png'
    img.save(output_path, 'PNG')
    print(f"✓ Icon generated successfully: {output_path}")
    print(f"  Size: {size}x{size} pixels")
    print("\nNext steps:")
    print("1. If you have a harvesting machine image, you can edit this icon")
    print("2. Run: flutter pub run flutter_launcher_icons")
    print("3. Rebuild your app: flutter clean && flutter run")

except ImportError:
    print("Pillow is not installed. Install it with: pip install Pillow")
    print("\nOr use the HTML tool: Open create_icon.html in your browser")
except Exception as e:
    print(f"Error: {e}")
    print("\nAlternative: Use the HTML tool (create_icon.html) in your browser")

