import os
import zlib
import io
import sys
from PIL import Image

sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def optimize_single_file(file_path, output_path, scale=0.5, format_type='WEBP', quality=75):
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found.")
        return
        
    with open(file_path, 'rb') as f:
        data = f.read()
        
    decompressed = zlib.decompress(data)
    movie = svga_pb2.MovieEntity()
    movie.ParseFromString(decompressed)
    
    modified_images = {}
    total_orig = 0
    total_opt = 0
    
    for key, img_bytes in movie.images.items():
        total_orig += len(img_bytes)
        # Skip if it is not an image (e.g., audio)
        # Audio keys in SVGA are usually prefixed with audio_ or not recognized by PIL
        try:
            img = Image.open(io.BytesIO(img_bytes))
        except Exception:
            # Not an image (probably audio)
            modified_images[key] = img_bytes
            total_opt += len(img_bytes)
            continue
            
        # Resize image
        new_size = (int(img.width * scale), int(img.height * scale))
        # Use high quality resizing
        img_resized = img.resize(new_size, Image.Resampling.LANCZOS)
        
        # Save to bytes
        out_io = io.BytesIO()
        if format_type.upper() == 'WEBP':
            # Convert RGBA/RGB as appropriate. WEBP supports RGBA.
            img_resized.save(out_io, format='WEBP', quality=quality)
        elif format_type.upper() == 'PNG':
            # Save as PNG with optimization
            img_resized.save(out_io, format='PNG', optimize=True)
        else:
            # Keep original format
            img_resized.save(out_io, format=img.format, quality=quality)
            
        opt_bytes = out_io.getvalue()
        modified_images[key] = opt_bytes
        total_opt += len(opt_bytes)
        
    # Clear original images and update
    movie.images.clear()
    for key, val in modified_images.items():
        movie.images[key] = val
        
    # Serialize and compress
    serialized = movie.SerializeToString()
    compressed = zlib.compress(serialized)
    
    # Write output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(compressed)
        
    orig_size = len(data)
    new_size = len(compressed)
    print(f"Optimization results for {os.path.basename(file_path)} ({format_type}):")
    print(f"  - Original File Size: {orig_size / 1024 / 1024:.2f} MB ({orig_size} bytes)")
    print(f"  - Optimized File Size: {new_size / 1024 / 1024:.2f} MB ({new_size} bytes)")
    print(f"  - Saved: {(orig_size - new_size) / orig_size * 100:.1f}% space")
    print(f"  - Raw image bytes in proto: {total_orig / 1024 / 1024:.2f} MB -> {total_opt / 1024 / 1024:.2f} MB")

if __name__ == "__main__":
    # Test on one file
    optimize_single_file(
        r"assets/rocket/rocket_set_svga/1_3.svga",
        r"scratch/1_3_opt_webp.svga",
        scale=0.5,
        format_type='WEBP',
        quality=75
    )
    optimize_single_file(
        r"assets/rocket/rocket_set_svga/1_3.svga",
        r"scratch/1_3_opt_png.svga",
        scale=0.5,
        format_type='PNG'
    )
