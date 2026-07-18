import os
import zlib
import io
from PIL import Image

# Add scratch to python path so we can import the generated pb2 module
import sys
sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def list_images(file_path):
    print(f"File: {file_path}")
    with open(file_path, 'rb') as f:
        data = f.read()
    
    decompressed = zlib.decompress(data)
    movie = svga_pb2.MovieEntity()
    movie.ParseFromString(decompressed)
    
    print(f"SVGA version: {movie.version}")
    print(f"Canvas size: {movie.params.viewBoxWidth}x{movie.params.viewBoxHeight}")
    print(f"FPS: {movie.params.fps}, Frames: {movie.params.frames}")
    print(f"Number of images: {len(movie.images)}")
    
    total_size = 0
    for key, img_bytes in movie.images.items():
        try:
            img = Image.open(io.BytesIO(img_bytes))
            print(f"  - Key: {key} | Format: {img.format} | Size: {img.size} | Bytes: {len(img_bytes) / 1024:.2f} KB")
            total_size += len(img_bytes)
        except Exception as e:
            print(f"  - Key: {key} | Failed to open image: {e} | Bytes: {len(img_bytes) / 1024:.2f} KB")
            
    print(f"Total image size in protobuf: {total_size / 1024 / 1024:.2f} MB\n")

# List images for one of the files
list_images(r"assets/rocket/rocket_set_svga/1_3.svga")
