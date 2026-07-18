import os
import zlib
import io
from PIL import Image

def inspect_svga(file_path):
    print(f"\n==================================================")
    print(f"Inspecting: {file_path}")
    print(f"File Size: {os.path.getsize(file_path) / (1024*1024):.2f} MB")
    
    try:
        with open(file_path, 'rb') as f:
            compressed_data = f.read()
            
        # Decompress
        try:
            decompressed_data = zlib.decompress(compressed_data)
        except Exception as e:
            print(f"❌ Zlib Decompression failed: {e}")
            return
            
        print(f"Decompressed Size: {len(decompressed_data) / (1024*1024):.2f} MB")
        
        # We search for signatures:
        # PNG: \x89PNG\r\n\x1a\n
        # JPEG: \xff\xd8\xff
        # WEBP: RIFF...WEBP
        signatures = [
            ('PNG', b'\x89PNG\r\n\x1a\n'),
            ('JPEG', b'\xff\xd8\xff'),
            ('WEBP', b'RIFF') # WEBP starts with RIFF
        ]
        
        found = 0
        errors = 0
        
        # Scan decompressed bytes
        # Let's iterate through all offsets to find image headers
        for name, sig in signatures:
            idx = 0
            while True:
                idx = decompressed_data.find(sig, idx)
                if idx == -1:
                    break
                
                if name == 'WEBP':
                    # Validate it's WEBP by checking 'WEBP' at offset +8
                    if idx + 12 <= len(decompressed_data) and decompressed_data[idx+8:idx+12] != b'WEBP':
                        idx += 1
                        continue
                
                # We found a potential image start at idx.
                # Let's try to parse it with PIL Image.open
                try:
                    img_data = decompressed_data[idx:]
                    img = Image.open(io.BytesIO(img_data))
                    # Trigger loading of image data to verify it's valid and not truncated/corrupt
                    img.load()
                    
                    # Deduce length
                    img_len = 0
                    if img.format == 'PNG':
                        iend = img_data.find(b'IEND')
                        if iend != -1:
                            img_len = iend + 8
                    elif img.format == 'JPEG':
                        ffd9 = img_data.find(b'\xff\xd9')
                        if ffd9 != -1:
                            img_len = ffd9 + 2
                    elif img.format == 'WEBP':
                        import struct
                        if len(img_data) >= 8:
                            riff_size = struct.unpack('<I', img_data[4:8])[0]
                            img_len = riff_size + 8
                    
                    print(f"  ✅ Image: {img.format} | Size: {img.size} | Est. Bytes: {img_len} ({img_len/1024:.1f} KB)")
                    found += 1
                    if img_len > 0:
                        idx += img_len
                    else:
                        idx += 1
                except Exception as e:
                    # Let's see if this signature was an actual image attempt that failed
                    # If we find the signature but it fails to load, it might be corrupted image bytes.
                    # Print context of the error
                    print(f"  ❌ Failed to parse potential {name} image at offset {idx}: {e}")
                    errors += 1
                    idx += 1
                    
        print(f"Summary: Found {found} valid images, {errors} errors.")
        
    except Exception as e:
        print(f"❌ General Error: {e}")

def main():
    assets_dir = 'assets'
    svga_files = []
    for root, dirs, files in os.walk(assets_dir):
        for file in files:
            if file.lower().endswith('.svga'):
                svga_files.append(os.path.join(root, file))
                
    print(f"Found {len(svga_files)} SVGA files.")
    for svga in svga_files:
        inspect_svga(svga)

if __name__ == "__main__":
    main()
