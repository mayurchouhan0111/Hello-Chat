import os
import zlib
from PIL import Image
import io

def extract_svga_images():
    svga_path = os.path.join("assets", "svga", "100.svga")
    if not os.path.exists(svga_path):
        print(f"Error: SVGA file not found at {svga_path}")
        return

    print(f"Reading SVGA: {svga_path}")
    try:
        with open(svga_path, 'rb') as f:
            compressed_data = f.read()
            
        print(f"Compressed size: {len(compressed_data)/(1024*1024):.2f} MB")
        
        # Decompress using zlib
        decompressed_data = zlib.decompress(compressed_data)
        print(f"Decompressed size: {len(decompressed_data)/(1024*1024):.2f} MB")
        
        # Let's search for image headers in the decompressed data
        # PNG header: \x89PNG\r\n\x1a\n
        # JPEG header: \xff\xd8\xff
        # WEBP/RIFF header: RIFF....WEBP (starts with RIFF, then 4 bytes of size, then WEBP)
        
        signatures = [
            ('PNG', b'\x89PNG\r\n\x1a\n'),
            ('JPEG', b'\xff\xd8\xff'),
            ('WEBP', b'RIFF') # WEBP starts with RIFF, then WEBP at offset 8
        ]
        
        found_images = []
        
        # We can find all occurrences of signatures
        # Since images in the protobuf are stored as bytes fields, their content starts with the header
        # and runs to the end of the byte sequence or can be read by PIL if we try to decode it.
        # Let's scan the file and try to extract images by feeding slices to PIL.Image.open!
        
        print("\nScanning decompressed bytes for image headers...")
        for name, sig in signatures:
            idx = 0
            while True:
                idx = decompressed_data.find(sig, idx)
                if idx == -1:
                    break
                
                # Check for WEBP signature validation (must have WEBP at offset +8)
                if name == 'WEBP':
                    if decompressed_data[idx+8:idx+12] != b'WEBP':
                        idx += 1
                        continue
                
                # Try to decode the image from this offset
                # Since we don't know the exact length, PIL might read until the end of the file or the image's internal length marker.
                # Many image formats (like PNG, JPEG, WEBP) have internal length markers, so PIL.Image.open can successfully parse it!
                try:
                    img_data = decompressed_data[idx:]
                    img = Image.open(io.BytesIO(img_data))
                    
                    # We can find the size of the image in bytes by saving it or checking if PIL knows it.
                    # Alternatively, for PNG, we can find the IEND chunk: b'IEND\xaeB`\x82'
                    img_bytes_len = 0
                    if img.format == 'PNG':
                        iend_idx = img_data.find(b'IEND')
                        if iend_idx != -1:
                            img_bytes_len = iend_idx + 8
                    elif img.format == 'JPEG':
                        # JPEG ends with \xff\xd9
                        ffd9_idx = img_data.find(b'\xff\xd9')
                        if ffd9_idx != -1:
                            img_bytes_len = ffd9_idx + 2
                    elif img.format == 'WEBP':
                        # WEBP size is stored at offset 4 (4 bytes integer) + 8 bytes
                        import struct
                        riff_size = struct.unpack('<I', img_data[4:8])[0]
                        img_bytes_len = riff_size + 8
                    
                    if img_bytes_len > 0:
                        actual_bytes = img_data[:img_bytes_len]
                        found_images.append({
                            'offset': idx,
                            'format': img.format,
                            'size': img.size,
                            'bytes_len': img_bytes_len,
                            'data': actual_bytes
                        })
                        print(f"  Found {img.format} | Offset: {idx} | Size: {img.size} | Bytes: {img_bytes_len/1024:.1f} KB")
                        idx += img_bytes_len
                    else:
                        idx += 1
                except Exception as e:
                    idx += 1
                    
        print(f"\nTotal unique images successfully identified: {len(found_images)}")
        
    except Exception as e:
        print(f"Error extracting images: {e}")

if __name__ == "__main__":
    extract_svga_images()
