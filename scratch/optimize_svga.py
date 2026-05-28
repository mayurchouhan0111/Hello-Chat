import os
import zlib
import blackboxprotobuf
from PIL import Image
import io

def optimize_svga():
    svga_path = os.path.join("assets", "svga", "100.svga")
    output_path = os.path.join("assets", "svga", "100_optimized.svga")
    
    if not os.path.exists(svga_path):
        print(f"Error: SVGA file not found at {svga_path}")
        return

    print(f"Loading {svga_path} for optimization...")
    try:
        with open(svga_path, 'rb') as f:
            compressed_data = f.read()
            
        # Decompress
        decompressed_data = zlib.decompress(compressed_data)
        
        # Decode protobuf using blackboxprotobuf
        print("Decoding protobuf message...")
        message_dict, typedef = blackboxprotobuf.decode_message(decompressed_data)
        
        print("\nProtobuf Structure:")
        print(f"Root fields present: {list(message_dict.keys())}")
        
        # We need to look for any fields that correspond to the images map (tag 3 or matching 3-*)
        image_keys = [k for k in message_dict.keys() if k == '3' or k.startswith('3-')]
        print(f"Found image map fields: {image_keys}")
        
        optimized_count = 0
        total_images_processed = 0
        
        for img_key_field in image_keys:
            images_list = message_dict[img_key_field]
            if not isinstance(images_list, list):
                images_list = [images_list] # wrap in list if it's a single entry
                
            print(f"\nProcessing image field '{img_key_field}' with {len(images_list)} entries...")
            
            for idx, entry in enumerate(images_list):
                if not isinstance(entry, dict):
                    continue
                
                total_images_processed += 1
                
                # Dynamically find the image bytes field and key field
                img_data_field = None
                img_key_name = None
                img_bytes = None
                
                for k, v in entry.items():
                    if isinstance(v, bytes):
                        # Check if it starts with image signature
                        if v.startswith(b'\x89PNG') or v.startswith(b'\xff\xd8\xff') or v.startswith(b'RIFF'):
                            img_data_field = k
                            img_bytes = v
                            break
                
                # If we didn't find by signature, let's find the field with tag '2' (standard value field in map entry)
                if img_bytes is None:
                    if '2' in entry and isinstance(entry['2'], bytes):
                        img_data_field = '2'
                        img_bytes = entry['2']
                
                if img_bytes is None:
                    continue
                
                # Now find the key name for logging
                # Key is typically the other field in entry (tag '1' or similar)
                for k, v in entry.items():
                    if k != img_data_field:
                        img_key_name = str(v)
                        break
                
                if not img_key_name:
                    img_key_name = f"unknown_{total_images_processed}"
                
                # Optimize image
                try:
                    img = Image.open(io.BytesIO(img_bytes))
                    orig_w, orig_h = img.size
                    
                    # Scale down by 50%
                    new_w = int(orig_w * 0.5)
                    new_h = int(orig_h * 0.5)
                    
                    resized_img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
                    
                    # Save back as PNG with high compression/optimization
                    out_io = io.BytesIO()
                    resized_img.save(out_io, format='PNG', optimize=True)
                    new_bytes = out_io.getvalue()
                    
                    # Update entry in place!
                    entry[img_data_field] = new_bytes
                    optimized_count += 1
                    
                    if idx % 10 == 0 or idx == len(images_list) - 1:
                        print(f"  Optimized: {img_key_name} | {orig_w}x{orig_h} ({len(img_bytes)/1024:.1f} KB) -> {new_w}x{new_h} ({len(new_bytes)/1024:.1f} KB)")
                except Exception as e:
                    print(f"  Failed to optimize image {img_key_name}: {e}")
            
        print(f"\nSuccessfully optimized {optimized_count} of {total_images_processed} images.")
        
        # Re-encode back to protobuf
        print("Encoding optimized protobuf message...")
        optimized_decompressed_data = blackboxprotobuf.encode_message(message_dict, typedef)
        
        # Re-compress using zlib
        print("Compressing using zlib...")
        optimized_compressed_data = zlib.compress(optimized_decompressed_data)
        
        # Save
        with open(output_path, 'wb') as f:
            f.write(optimized_compressed_data)
            
        orig_size_mb = len(compressed_data)/(1024*1024)
        new_size_mb = len(optimized_compressed_data)/(1024*1024)
        new_comp_size_mb = len(optimized_compressed_data)
        
        print(f"\nSVGA Optimization Completed!")
        print(f"  - Original Compressed Size: {orig_size_mb:.2f} MB")
        print(f"  - New Optimized Compressed Size: {len(optimized_compressed_data)/(1024*1024):.2f} MB")
        print(f"  - Saved to: {output_path}")
        
    except Exception as e:
        print(f"Error during SVGA optimization: {e}")

if __name__ == "__main__":
    optimize_svga()
