import zlib
import os

def check_svga(file_path):
    try:
        with open(file_path, 'rb') as f:
            data = f.read()
            print(f"File: {os.path.basename(file_path)}")
            print(f"Size: {len(data)} bytes")
            print(f"Header: {data[:4].hex()}")
            
            try:
                decompressed = zlib.decompress(data)
                print(f"Decompressed size: {len(decompressed)} bytes")
                print(f"Decompressed header: {decompressed[:10]}")
            except Exception as e:
                print(f"Zlib Decompression failed: {e}")
                
    except Exception as e:
        print(f"Error reading file: {e}")

# Check one file
check_svga(r'd:\UnHuman\Apps\Hello Chat\hellochat\assets\rocket\Rocket set SVGA\1.2.svga')
