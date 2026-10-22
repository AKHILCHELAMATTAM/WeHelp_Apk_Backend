import os
from PIL import Image, ImageDraw, ImageFilter

src_img_path = r"C:\Users\ASUS\.gemini\antigravity\brain\893174c3-de9a-4cd6-b1d2-982a9aa87ace\.user_uploaded\media_1792667433934_a6a7655e.jpg"
res_dir = r"e:\14-10-2026\mobile apk\android\app\src\main\res"
assets_dir = r"e:\14-10-2026\mobile apk\assets\images"
os.makedirs(assets_dir, exist_ok=True)

print("Opening source image:", src_img_path)
raw_img = Image.open(src_img_path).convert("RGBA")

# 1. Save high-resolution app_logo.png in assets
app_logo_path = os.path.join(assets_dir, "app_logo.png")
raw_img.save(app_logo_path, "PNG")
print(f"Saved master logo: {app_logo_path} (1024x1024)")

# Save square 512x512
sq_512 = raw_img.resize((512, 512), Image.Resampling.LANCZOS)
sq_512.save(os.path.join(assets_dir, "app_logo_square.png"), "PNG")

# 2. Function to generate adaptive foreground (108dp canvas with safe zone)
BG_COLOR = (2, 75, 105, 255)

def make_adaptive_fg(size):
    # Canvas size: size x size
    fg = Image.new("RGBA", (size, size), BG_COLOR)
    # Scale master logo so it occupies ~62% of the canvas (fits safely inside 66.6% circular mask)
    logo_size = int(size * 268 / 432)
    scaled = raw_img.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    # Smooth feather edge mask so transition into background is seamless
    mask = Image.new("L", (logo_size, logo_size), 255)
    d = ImageDraw.Draw(mask)
    border = max(2, int(logo_size * 0.08))
    for i in range(border):
        alpha = int(255 * (i / border))
        d.rectangle([(i, i), (logo_size - 1 - i, logo_size - 1 - i)], outline=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=border // 2))
    
    offset = ((size - logo_size) // 2, (size - logo_size) // 2)
    fg.paste(scaled, offset, mask)
    return fg

# Save master adaptive foreground in assets
fg_master = make_adaptive_fg(432)
fg_master.save(os.path.join(assets_dir, "app_logo_foreground.png"), "PNG")

# 3. Android mipmap densities
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
    
    # 1. Standard ic_launcher.png (Rounded squircle with slight margin)
    # Master resized with slight rounded corners (radius ~ 18%)
    launcher = raw_img.resize((size, size), Image.Resampling.LANCZOS)
    sq_mask = Image.new("L", (size, size), 0)
    corner_r = int(size * 0.18)
    ImageDraw.Draw(sq_mask).rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=corner_r, fill=255)
    launcher_out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    launcher_out.paste(launcher, (0, 0), sq_mask)
    launcher_out.save(os.path.join(target_dir, "ic_launcher.png"), "PNG")
    
    # 2. Round ic_launcher_round.png
    # Scale logo slightly so circle doesn't clip the outer text corners
    round_canvas = Image.new("RGBA", (size, size), BG_COLOR)
    r_logo_size = int(size * 0.82)
    r_scaled = raw_img.resize((r_logo_size, r_logo_size), Image.Resampling.LANCZOS)
    r_offset = ((size - r_logo_size) // 2, (size - r_logo_size) // 2)
    round_canvas.paste(r_scaled, r_offset)
    
    round_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(round_mask).ellipse([(0, 0), (size - 1, size - 1)], fill=255)
    round_out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    round_out.paste(round_canvas, (0, 0), round_mask)
    round_out.save(os.path.join(target_dir, "ic_launcher_round.png"), "PNG")
    
    # 3. Adaptive foreground ic_launcher_foreground.png
    fg = make_adaptive_fg(fg_size)
    fg.save(os.path.join(target_dir, "ic_launcher_foreground.png"), "PNG")
    
    print(f"Generated {folder}: {size}x{size}, round: {size}x{size}, fg: {fg_size}x{fg_size}")

# 4. Create drawable/ic_launcher_background.xml with matching deep teal gradient
drawable_dir = os.path.join(res_dir, "drawable")
os.makedirs(drawable_dir, exist_ok=True)
bg_xml = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:type="linear"
        android:angle="135"
        android:startColor="#013B52"
        android:endColor="#06597A" />
</shape>
"""
with open(os.path.join(drawable_dir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
    f.write(bg_xml)

# 5. Create mipmap-anydpi-v26 XMLs
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

print("All Android launcher icons and XML configs generated successfully!")
