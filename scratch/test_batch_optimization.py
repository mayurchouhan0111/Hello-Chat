import os
import zlib
import io
import sys
from PIL import Image

sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def test_optimize(file_path):
    if not os.path.exists(file_path):
        return
        
    with open(file_path, 'rb') as f:
        data = f.read()
        
    decompressed = zlib.decompress(data)
    movie = svga_pb2.MovieEntity()
    movie.ParseFromString(decompressed)
    
    modified_webp = {}
    modified_png = {}
    
    for key, img_bytes in movie.images.items():
        try:
            img = Image.open(io.BytesIO(img_bytes))
        except Exception:
            modified_webp[key] = img_bytes
            modified_png[key] = img_bytes
            continue
            
        # Determine scale
        scale = 1.0
        if max(img.width, img.height) > 256:
            scale = 0.5
            
        if scale != 1.0:
            new_size = (int(img.width * scale), int(img.height * scale))
            img_resized = img.resize(new_size, Image.Resampling.LANCZOS)
        else:
            img_resized = img
            
        # Save to WebP
        out_webp = io.BytesIO()
        img_resized.save(out_webp, format='WEBP', quality=75)
        modified_webp[key] = out_webp.getvalue()
        
        # Save to PNG
        out_png = io.BytesIO()
        img_resized.save(out_png, format='PNG', optimize=True)
        modified_png[key] = out_png.getvalue()
        
    # Serialize WebP
    movie.images.clear()
    for key, val in modified_webp.items():
        movie.images[key] = val
    webp_data = zlib.compress(movie.SerializeToString())
    
    # Serialize PNG
    movie.images.clear()
    for key, val in modified_png.items():
        movie.images[key] = val
    png_data = zlib.compress(movie.SerializeToString())
    
    orig_mb = len(data) / 1024 / 1024
    webp_mb = len(webp_data) / 1024 / 1024
    png_mb = len(png_data) / 1024 / 1024
    
    print(f"{os.path.basename(file_path)}:")
    print(f"  Original: {orig_mb:.2f} MB")
    print(f"  WebP Opt: {webp_mb:.2f} MB (saved {(orig_mb - webp_mb)/orig_mb*100:.1f}%)")
    print(f"  PNG Opt : {png_mb:.2f} MB (saved {(orig_mb - png_mb)/orig_mb*100:.1f}%)")

large_files = [
    r"assets/svga/100.svga",
    r"assets/VIP/VIP 1/Crown 1.svga",
    r"assets/VIP/VIP 1/Entry.svga",
    r"assets/rocket/rocket_set_svga/4_3.svga"
]

for lf in large_files:
    test_optimize(lf)
