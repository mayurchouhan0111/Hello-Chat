import os
import shutil
from PIL import Image

source_logo = os.path.abspath(r"d:\UnHuman\Apps\Hello Chat\hellochat\hellochat_admin\src\assets\logo.webp")
target_logo = os.path.abspath(r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\logo.webp")

print(f"Copying {source_logo} to {target_logo}...")
shutil.copyfile(source_logo, target_logo)

# Load logo using PIL
img = Image.open(source_logo)

# Mipmap dimensions for Android launcher icons
mipmap_sizes = {
    r"d:\UnHuman\Apps\Hello Chat\hellochat\android\app\src\main\res\mipmap-mdpi": (48, 48),
    r"d:\UnHuman\Apps\Hello Chat\hellochat\android\app\src\main\res\mipmap-hdpi": (72, 72),
    r"d:\UnHuman\Apps\Hello Chat\hellochat\android\app\src\main\res\mipmap-xhdpi": (96, 96),
    r"d:\UnHuman\Apps\Hello Chat\hellochat\android\app\src\main\res\mipmap-xxhdpi": (144, 144),
    r"d:\UnHuman\Apps\Hello Chat\hellochat\android\app\src\main\res\mipmap-xxxhdpi": (192, 192),
}

for folder, size in mipmap_sizes.items():
    os.makedirs(folder, exist_ok=True)
    out_path = os.path.join(folder, "ic_launcher.png")
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(out_path, format="PNG")
    print(f"Generated {out_path} ({size[0]}x{size[1]})")

print("Launcher icons successfully updated!")
