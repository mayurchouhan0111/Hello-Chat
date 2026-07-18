import os
import zlib
import io
import sys
import shutil
from PIL import Image

sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def optimize_svga_file(file_path):
    if not os.path.exists(file_path):
        return None
        
    orig_size = os.path.getsize(file_path)
    if orig_size < 10 * 1024:  # Skip files smaller than 10KB
        print(f"Skipping tiny file: {file_path} ({orig_size / 1024:.2f} KB)")
        return None
        
    try:
        with open(file_path, 'rb') as f:
            data = f.read()
            
        decompressed = zlib.decompress(data)
        movie = svga_pb2.MovieEntity()
        movie.ParseFromString(decompressed)
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        return None
        
    modified_images = {}
    has_changes = False
    
    for key, img_bytes in movie.images.items():
        try:
            img = Image.open(io.BytesIO(img_bytes))
        except Exception:
            # Keep non-image files (audio, etc.) as is
            modified_images[key] = img_bytes
            continue
            
        # Determine scale
        scale = 1.0
        # For large assets, scale down by 50% to save 75% memory on decoding
        if max(img.width, img.height) > 256:
            scale = 0.5
            
        if scale != 1.0:
            new_size = (int(img.width * scale), int(img.height * scale))
            img_resized = img.resize(new_size, Image.Resampling.LANCZOS)
            has_changes = True
        else:
            img_resized = img
            
        # Compress image to WEBP
        out_webp = io.BytesIO()
        img_resized.save(out_webp, format='WEBP', quality=75)
        webp_bytes = out_webp.getvalue()
        
        # Only replace if WebP is smaller than original bytes
        if len(webp_bytes) < len(img_bytes) or scale != 1.0:
            modified_images[key] = webp_bytes
            has_changes = True
        else:
            modified_images[key] = img_bytes
            
    if not has_changes:
        return None
        
    # Serialize and compress
    movie.images.clear()
    for key, val in modified_images.items():
        movie.images[key] = val
        
    serialized = movie.SerializeToString()
    compressed = zlib.compress(serialized)
    
    new_size = len(compressed)
    
    # Only overwrite if it actually saved space
    if new_size < orig_size:
        # Backup original file just in case
        backup_path = file_path + ".bak"
        shutil.copy2(file_path, backup_path)
        
        # Overwrite
        with open(file_path, 'wb') as f:
            f.write(compressed)
            
        return orig_size, new_size
    else:
        return None

def main():
    print("[START] Starting SVGA Asset Optimization...")
    svga_files = []
    
    # Find all svga files
    for root, dirs, files in os.walk("."):
        if "node_modules" in root or ".git" in root or "build" in root or ".dart_tool" in root or "scratch" in root:
            continue
        for file in files:
            if file.endswith(".svga") and not file.endswith(".bak"):
                path = os.path.join(root, file)
                svga_files.append(path)
                
    print(f"Found {len(svga_files)} SVGA files to process.")
    
    optimized_count = 0
    total_saved = 0
    
    for path in svga_files:
        result = optimize_svga_file(path)
        if result:
            orig, opt = result
            saved = orig - opt
            total_saved += saved
            optimized_count += 1
            print(f"[OPTIMIZED] Optimized: {path} | {orig/1024/1024:.2f}MB -> {opt/1024/1024:.2f}MB (saved {saved/1024/1024:.2f}MB, {saved/orig*100:.1f}%)")
            
    print("\n-------------------------------------------")
    print(f"Optimization Completed!")
    print(f"  - Total files optimized: {optimized_count}")
    print(f"  - Total space saved: {total_saved / 1024 / 1024:.2f} MB")
    print("-------------------------------------------")

if __name__ == "__main__":
    main()
