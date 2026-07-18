import os
from PIL import Image

def compress_image(filepath, target_size_kb=200):
    try:
        orig_size = os.path.getsize(filepath)
        print(f"Compressing: {filepath} ({orig_size / 1024:.1f} KB)")
        
        with Image.open(filepath) as img:
            # Check format
            fmt = img.format
            width, height = img.size
            print(f"  - Format: {fmt}, Dimensions: {width}x{height}")
            
            # If resolution is extremely large, resize it. Fallback preview images do not need to be huge.
            max_dim = 600
            if width > max_dim or height > max_dim:
                ratio = min(max_dim / width, max_dim / height)
                new_width = int(width * ratio)
                new_height = int(height * ratio)
                img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                print(f"  - Resized to: {new_width}x{new_height}")
            
            # Save back. If it's a PNG, we can save it with optimize=True. Or, since we want to keep transparent backgrounds,
            # we should save it as PNG with high compression (compress_level=9) and palette/quantization if appropriate, or
            # convert to WebP/JPEG if alpha is not needed. But we must keep original extension so the app code doesn't break!
            # So we save it as PNG.
            img.save(filepath, format="PNG", optimize=True, compress_level=9)
            
        new_size = os.path.getsize(filepath)
        print(f"  - Done! New size: {new_size / 1024:.1f} KB (Saved {(orig_size - new_size)/1024:.1f} KB / {(orig_size - new_size)/orig_size*100:.1f}%)")
    except Exception as e:
        print(f"  - Error compressing {filepath}: {e}")

def run_compression():
    target_files = [
        "assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.png",
        "assets/VIP/VIP 7/VIP 7/Entry.png"
    ]
    
    for filepath in target_files:
        if os.path.exists(filepath):
            compress_image(filepath)
        else:
            # Try with backslashes
            alt_path = filepath.replace('/', '\\')
            if os.path.exists(alt_path):
                compress_image(alt_path)
            else:
                print(f"File not found: {filepath}")

    # Also check if there are other PNG/JPG files larger than 1MB in assets
    print("\nScanning for other large PNG/JPG images in assets/...")
    for root, dirs, files in os.walk("assets"):
        for file in files:
            ext = file.lower()
            if ext.endswith(".png") or ext.endswith(".jpg") or ext.endswith(".jpeg"):
                path = os.path.join(root, file)
                # Ignore the targets we already compressed
                if any(x in path.replace('\\', '/') for x in target_files):
                    continue
                try:
                    size = os.path.getsize(path)
                    if size > 500 * 1024: # > 500KB
                        compress_image(path)
                except Exception as e:
                    print(f"Error checking {path}: {e}")

if __name__ == "__main__":
    run_compression()
