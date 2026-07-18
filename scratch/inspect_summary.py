import os
import zlib
import sys

sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def inspect_summary(file_path):
    if not os.path.exists(file_path):
        return
        
    with open(file_path, 'rb') as f:
        data = f.read()
        
    decompressed = zlib.decompress(data)
    movie = svga_pb2.MovieEntity()
    movie.ParseFromString(decompressed)
    
    unique_sizes = set()
    for sprite in movie.sprites:
        for frame in sprite.frames:
            layout = frame.layout
            if layout is not None and (layout.width > 0 or layout.height > 0):
                # Round to 1 decimal place to group cleanly
                w = round(layout.width, 1)
                h = round(layout.height, 1)
                unique_sizes.add((w, h))
                
    print(f"File: {os.path.basename(file_path)}")
    print(f"  - ViewBox: {movie.params.viewBoxWidth}x{movie.params.viewBoxHeight}")
    print(f"  - Total Sprites: {len(movie.sprites)}")
    print(f"  - Unique Sprite Sizes: {sorted(list(unique_sizes))}")
    print("-" * 60)

if __name__ == "__main__":
    for level in range(1, 6):
        for form in range(1, 5):
            path = f"assets/rocket/Rocket set SVGA/{level}.{form}.svga"
            inspect_summary(path)
