# App Icon Setup - HM (Harvesting Machine)

## Quick Setup Options:

### Option 1: Use the HTML Generator (Easiest)
1. Open `create_icon.html` in your web browser
2. (Optional) Upload a harvesting machine image
3. Click "Generate Icon"
4. Click "Download Icon" to save `app_icon.png`
5. Make sure the file is saved in this folder as `app_icon.png`

### Option 2: Use Python Script
1. Install Pillow: `pip install Pillow`
2. Run: `python generate_icon.py`
3. This creates a basic icon with "HM" text

### Option 3: Create Your Own
1. Create a 1024x1024 PNG image
2. Include "HM" text and harvesting machine image
3. Save as `app_icon.png` in this folder

## After Creating the Icon:

1. **Generate launcher icons for all platforms:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

2. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter run
   ```

## Icon Requirements:
- Size: 1024x1024 pixels (square)
- Format: PNG
- Background: Transparent or solid color
- Content: "HM" text + Harvesting Machine image

## Notes:
- The icon will be automatically generated for Android, iOS, Web, Windows, and macOS
- For Android, adaptive icons will be created automatically
- The icon will appear after rebuilding the app

