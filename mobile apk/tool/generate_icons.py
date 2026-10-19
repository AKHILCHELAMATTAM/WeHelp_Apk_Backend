import os
from PIL import Image, ImageDraw

res_dir = r"e:\14-10-2026\mobile apk\android\app\src\main\res"
assets_dir = r"e:\14-10-2026\mobile apk\assets\images"

master_logo = Image.open(os.path.join(assets_dir, "app_logo.png"))
square_logo = Image.open(os.path.join(assets_dir, "app_logo_square.png"))
fg_logo = Image.open(os.path.join(assets_dir, "app_logo_foreground.png"))

densities = {
    "mipmap-mdpi": (48, 108),
    "mipmap-hdpi": (72, 162),
    "mipmap-xhdpi": (96, 216),
    "mipmap-xxhdpi": (144, 324),
    "mipmap-xxxhdpi": (192, 432),
}

for folder, (size, fg_size) in densities.items():
    target_dir = os.path.join(res_dir, folder)
    os.makedirs(target_dir, exist_ok=True)
    
    # 1. Standard ic_launcher.png
    launcher = master_logo.resize((size, size), Image.Resampling.LANCZOS)
    launcher.save(os.path.join(target_dir, "ic_launcher.png"), "PNG")
    
    # 2. Round ic_launcher_round.png
    round_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(round_mask).ellipse([(0, 0), (size, size)], fill=255)
    round_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_resized = square_logo.resize((size, size), Image.Resampling.LANCZOS)
    round_img.paste(sq_resized, (0, 0), round_mask)
    round_img.save(os.path.join(target_dir, "ic_launcher_round.png"), "PNG")
    
    # 3. Adaptive foreground ic_launcher_foreground.png
    fg_resized = fg_logo.resize((fg_size, fg_size), Image.Resampling.LANCZOS)
    fg_resized.save(os.path.join(target_dir, "ic_launcher_foreground.png"), "PNG")
    
    print(f"Generated {folder}: {size}x{size}, fg: {fg_size}x{fg_size}")

# Also create drawable/ic_launcher_background.xml
drawable_dir = os.path.join(res_dir, "drawable")
os.makedirs(drawable_dir, exist_ok=True)
bg_xml = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:type="linear"
        android:angle="135"
        android:startColor="#0F5132"
        android:endColor="#10B981" />
</shape>
"""
with open(os.path.join(drawable_dir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
    f.write(bg_xml)

# Create mipmap-anydpi-v26 XMLs
anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
os.makedirs(anydpi_dir, exist_ok=True)
adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
    f.write(adaptive_xml)
with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
    f.write(adaptive_xml)

print("All adaptive icon XMLs and mipmaps generated successfully!")
