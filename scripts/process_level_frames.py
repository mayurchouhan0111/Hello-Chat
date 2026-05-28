import os
import re
from PIL import Image, ImageChops

# Define the new 11-group model with associated "Target Hues" for mapping
# Hue values (0-360):
# 0: Red, 30: Orange, 60: Yellow, 120: Green, 180: Cyan, 240: Blue, 300: Magenta
LEVEL_GROUPS = [
    {"index": 0, "range": "1-9", "hue": 210, "sat": 0.1, "name": "Silver"}, # Low sat
    {"index": 1, "range": "10-19", "hue": 140, "sat": 0.5, "name": "Green/Gold"},
    {"index": 2, "range": "20-29", "hue": 45, "sat": 0.8, "name": "Gold/Yellow"},
    {"index": 3, "range": "30-39", "hue": 330, "sat": 0.7, "name": "Pink"},
    {"index": 4, "range": "40-49", "hue": 260, "sat": 0.6, "name": "Dark Blue/Purple"},
    {"index": 5, "range": "50-59", "hue": 120, "sat": 0.8, "name": "Emerald Green"},
    {"index": 6, "range": "60-69", "hue": 200, "sat": 0.8, "name": "Sky Blue"},
    {"index": 7, "range": "70-79", "hue": 280, "sat": 0.8, "name": "Royal Purple"},
    {"index": 8, "range": "80-89", "hue": 30, "sat": 0.9, "name": "Fire Orange"},
    {"index": 9, "range": "90-99", "hue": 0, "sat": 0.9, "name": "Ruby Red"},
    {"index": 10, "range": "100", "hue": 45, "sat": 0.3, "name": "Emperor Black/Gold"}, # Complex
]

from PIL import ImageFilter

def remove_background(img, tolerance=30, target_height=200):
    """Replaces background color with transparency and resizes with smoothing."""
    img = img.convert("RGBA")
    
    # Sample background color from corners
    corners = [img.getpixel((0, 0)), img.getpixel((img.width - 1, 0)), 
               img.getpixel((0, img.height - 1)), img.getpixel((img.width - 1, img.height - 1))]
    bg_r = sum(c[0] for c in corners) // 4
    bg_g = sum(c[1] for c in corners) // 4
    bg_b = sum(c[2] for c in corners) // 4

    # Create a mask for the background
    rgb = img.convert("RGB")
    mask = Image.new("L", img.size, 255)
    
    pixels = rgb.getdata()
    mask_pixels = []
    
    for p in pixels:
        # Distance to sampled background color
        dist = abs(p[0] - bg_r) + abs(p[1] - bg_g) + abs(p[2] - bg_b)
        
        # Also check if it's a neutral grey (common in these backgrounds)
        is_neutral = abs(p[0] - p[1]) < 15 and abs(p[1] - p[2]) < 15 and abs(p[0] - p[2]) < 15
        avg_val = (p[0] + p[1] + p[2]) / 3
        is_light_grey = is_neutral and avg_val > 180 # Background is usually light grey
        
        if dist < tolerance * 3 or is_light_grey:
            # Soft transition
            alpha = 0
            if dist > tolerance:
                alpha = int(min(255, (dist / (tolerance * 3)) * 255))
            
            # If it's very likely background, force transparent
            if is_light_grey or dist < tolerance: alpha = 0
            
            mask_pixels.append(alpha)
        else:
            mask_pixels.append(255)
            
    mask.putdata(mask_pixels)
    
    # Smooth the mask to avoid "patches" and rough edges
    mask = mask.filter(ImageFilter.SMOOTH)
    
    # Apply the mask
    img.putalpha(mask)
    
    # 1. Trim empty borders
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # 2. Resize while keeping aspect ratio
    aspect_ratio = img.width / img.height
    new_width = int(target_height * aspect_ratio)
    img = img.resize((new_width, target_height), Image.Resampling.LANCZOS)
    
    return img

def get_dominant_hue(img):
    """Analyzes the image to find the dominant hue."""
    img_hsv = img.convert("HSV")
    h_sum, s_sum, count = 0, 0, 0
    
    for pixel in img_hsv.getdata():
        h, s, v = pixel
        if s > 30 and v > 50: # Only count colorful and bright pixels
            h_sum += h
            s_sum += s
            count += 1
            
    if count == 0: return 0, 0
    return (h_sum / count) * (360/255), (s_sum / count) / 255

def process_images(input_dir, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    # Correct mapping based on the files provided by the user
    mapping = {
        "1 (2).png": 0,
        "2 (2).png": 1,
        "3 (2).png": 2,
        "4.png": 3,
        "4..png": 4,
        "5.png": 5,
        "7.png": 6,
        "8.png": 7,
        "9.png": 8,
        "10.png": 9,
        "11.png": 10,
    }
    
    processed_count = 0
    print(f"Processing images using manual mapping...")
    
    for filename, index in mapping.items():
        file_path = os.path.join(input_dir, filename)
        if not os.path.exists(file_path):
            print(f"Warning: {filename} not found in {input_dir}")
            continue
            
        try:
            img = Image.open(file_path)
            
            # 1. Remove background
            img_no_bg = remove_background(img)
            
            # 2. Save as WebP
            target_filename = f"level_badge_{index}.webp"
            output_path = os.path.join(output_dir, target_filename)
            
            img_no_bg.save(output_path, "WEBP", quality=95)
            print(f"Processed {filename} -> {target_filename}")
            processed_count += 1
                
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            
    print(f"\nSuccessfully processed {processed_count} frames.")

def update_dart_code():
    """Updates the Dart code to use .webp extensions and new logic."""
    utils_path = os.path.join("lib", "utils", "level_utils.dart")
    if not os.path.exists(utils_path):
        print("Error: level_utils.dart not found.")
        return

    # Call the manage_levels.py logic or integrate it here
    # For now, let's just make sure we update the extension in LevelDetailScreen too
    screens_to_fix = [
        os.path.join("lib", "features", "profile", "presentation", "screens", "level_detail_screen.dart"),
        os.path.join("lib", "features", "profile", "presentation", "screens", "profile_detail_screen.dart"),
    ]
    
    for screen_path in screens_to_fix:
        if os.path.exists(screen_path):
            with open(screen_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            content = content.replace("level_badge_$index.png", "level_badge_$index.webp")
            content = content.replace("level_badge_$index.png", "level_badge_$index.webp") # double check
            
            with open(screen_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated image extensions in {screen_path}")

if __name__ == "__main__":
    raw_dir = os.path.join("assets", "images", "levels_raw")
    target_dir = os.path.join("assets", "images", "levels_new")
    
    if not os.path.exists(raw_dir):
        os.makedirs(raw_dir)
        print(f"Please put your raw level images in: {raw_dir}")
    else:
        process_images(raw_dir, target_dir)
        update_dart_code()
        # Also run the logic update
        import manage_levels
        manage_levels.update_level_utils(os.path.join("lib", "utils", "level_utils.dart"))
