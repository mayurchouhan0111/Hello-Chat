import os
import zipfile
from PIL import Image
import io

def inspect_svga():
    svga_path = os.path.join("assets", "svga", "100.svga")
    if not os.path.exists(svga_path):
        print(f"Error: SVGA file not found at {svga_path}")
        return

    print(f"Inspecting SVGA file: {svga_path} ({os.path.getsize(svga_path)/(1024*1024):.2f} MB)")
    
    try:
        with zipfile.ZipFile(svga_path, 'r') as z:
            file_list = z.namelist()
            print(f"Total files inside SVGA: {len(file_list)}")
            
            images_found = 0
            spec_found = False
            
            for name in file_list:
                if name == "movie.spec":
                    spec_found = True
                    print("  Found movie.spec (protobuf file)")
                    continue
                
                # Check for image files
                ext = os.path.splitext(name)[1].lower()
                if ext in ['.png', '.jpg', '.jpeg', '.webp', '.gif']:
                    images_found += 1
                    try:
                        data = z.read(name)
                        img = Image.open(io.BytesIO(data))
                        print(f"  Image file: {name} | Format: {img.format} | Size: {img.size} | Bytes: {len(data)/1024:.1f} KB")
                    except Exception as e:
                        print(f"  Error reading image {name}: {e}")
                        
            print(f"\nInspection summary:")
            print(f"  - movie.spec found: {spec_found}")
            print(f"  - Total embedded images: {images_found}")
            
    except Exception as e:
        print(f"Error inspecting SVGA: {e}")

if __name__ == "__main__":
    inspect_svga()
