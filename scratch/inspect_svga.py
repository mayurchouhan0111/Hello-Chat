import os
import zlib
import sys

sys.path.append(os.path.abspath("scratch"))
import svga_pb2

def inspect_svga(file_path):
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found.")
        return
        
    with open(file_path, 'rb') as f:
        data = f.read()
        
    decompressed = zlib.decompress(data)
    movie = svga_pb2.MovieEntity()
    movie.ParseFromString(decompressed)
    
    print(f"=== Inspecting {os.path.basename(file_path)} ===")
    print(f"ViewBox: {movie.params.viewBoxWidth}x{movie.params.viewBoxHeight}")
    print(f"FPS: {movie.params.fps}, Frames: {movie.params.frames}")
    
    print("\nImages in Entity (Image Keys):")
    for key in sorted(movie.images.keys()):
        img_bytes = movie.images[key]
        print(f"  - Key: '{key}', Bytes: {len(img_bytes)}")
        
    print("\nSprites in Entity:")
    for i, sprite in enumerate(movie.sprites):
        image_key = getattr(sprite, 'imageKey', 'unknown')
        num_frames = len(sprite.frames)
        print(f"  [{i}] Sprite: Image Key: '{image_key}', Frames: {num_frames}")
        
        # Check first frame with valid layout/transform
        for f_idx, frame in enumerate(sprite.frames):
            layout = frame.layout
            if layout is not None and (layout.width > 0 or layout.height > 0):
                print(f"      - First active frame [{f_idx}]: layout = {layout.x}, {layout.y}, {layout.width}x{layout.height}")
                print(f"        transform = a={frame.transform.a}, b={frame.transform.b}, c={frame.transform.c}, d={frame.transform.d}, tx={frame.transform.tx}, ty={frame.transform.ty}")
                break

if __name__ == "__main__":
    for i in range(1, 6):
        path = f"assets/rocket/Rocket set SVGA/{i}.4.svga"
        if os.path.exists(path):
            inspect_svga(path)
            print("-" * 50)
