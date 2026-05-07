"""
Generate placeholder images for the Claimit app assets.
Run: python generate_assets.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

def create_image(width, height, bg_color, text, text_color=(255, 255, 255), filename=None):
    img = Image.new('RGBA', (width, height), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Draw text centered
    bbox = draw.textbbox((0, 0), text, font=None)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (width - text_width) // 2
    y = (height - text_height) // 2
    draw.text((x, y), text, fill=text_color)
    
    if filename:
        img.save(filename)
    return img

def create_logo(filename):
    """Create Claimit logo."""
    img = Image.new('RGBA', (200, 200), (26, 60, 110, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw rounded rectangle background
    draw.rounded_rectangle([10, 10, 190, 190], radius=40, fill=(26, 60, 110, 255))
    
    # Draw "C" letter
    draw.text((60, 40), "C", fill=(255, 255, 255))
    
    img.save(filename)
    print(f"Created: {filename}")

def create_onboarding_image(filename, color, icon_text, title):
    """Create onboarding illustration."""
    img = Image.new('RGBA', (400, 300), (245, 247, 250, 255))
    draw = ImageDraw.Draw(img)
    
    # Background circle
    draw.ellipse([100, 30, 300, 230], fill=(*[int(c) for c in color], 30))
    
    # Icon circle
    draw.ellipse([140, 70, 260, 190], fill=(*[int(c) for c in color], 200))
    
    # Text
    draw.text((160, 115), icon_text, fill=(255, 255, 255))
    draw.text((120, 240), title, fill=(26, 26, 46))
    
    img.save(filename)
    print(f"Created: {filename}")

# Ensure directories exist
os.makedirs("claimit/assets/images", exist_ok=True)
os.makedirs("claimit/assets/icons", exist_ok=True)

# Create logo
create_logo("claimit/assets/images/logo.png")

# Create app icon
img = Image.new('RGBA', (1024, 1024), (26, 60, 110, 255))
draw = ImageDraw.Draw(img)
draw.rounded_rectangle([50, 50, 974, 974], radius=200, fill=(26, 60, 110, 255))
draw.text((350, 300), "C", fill=(255, 255, 255))
img.save("claimit/assets/images/app_icon.png")
print("Created: claimit/assets/images/app_icon.png")

# Create onboarding images
colors = [
    ((26, 60, 110), "📋", "File Claims"),
    ((46, 124, 246), "📍", "Track Claims"),
    ((0, 200, 150), "🔒", "Secure"),
]

for i, (color, icon, title) in enumerate(colors, 1):
    create_onboarding_image(
        f"claimit/assets/images/onboarding_{i}.png",
        color, icon, title
    )

# Create claim type icons
claim_types = {
    "health": (16, 185, 129),
    "motor": (59, 130, 246),
    "home": (245, 158, 11),
    "life": (139, 92, 246),
    "travel": (236, 72, 153),
    "property": (107, 114, 128),
}

for name, color in claim_types.items():
    img = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([5, 5, 95, 95], fill=(*color, 255))
    img.save(f"claimit/assets/icons/{name}_insurance.png")
    print(f"Created: claimit/assets/icons/{name}_insurance.png")

# Create empty placeholder for splash
img = Image.new('RGBA', (400, 400), (26, 60, 110, 255))
draw = ImageDraw.Draw(img)
draw.text((150, 160), "CLAIMIT", fill=(255, 255, 255))
img.save("claimit/assets/images/splash.png")
print("Created: claimit/assets/images/splash.png")

print("\n✅ All assets generated successfully!")
