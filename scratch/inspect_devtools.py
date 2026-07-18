import json
import os

def inspect():
    path = "assets/dart_devtools_2026-06-17_15_59_45.197.json"
    if not os.path.exists(path):
        print("Devtools file does not exist at:", path)
        return
        
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
            
    perf = data.get("performance", {})
    tb = perf.get("traceBinary", [])
    print("traceBinary length:", len(tb))
    if tb:
        print("First 10 items in list:", tb[:10])
        print("Item types:", set(type(x) for x in tb))
        
        # Convert list of ints to bytes
        try:
            byte_data = bytes(tb)
            print("Converted to bytes successfully. Length:", len(byte_data))
            # Try to decode as string
            try:
                # Let's check if it is JSON or gzip
                if byte_data.startswith(b'\x1f\x8b'):
                    print("Data is gzipped!")
                    import gzip
                    decompressed = gzip.decompress(byte_data)
                    print("Decompressed length:", len(decompressed))
                    # Print decompressed snippet
                    print("Decompressed snippet:", decompressed[:200])
                else:
                    text = byte_data.decode('utf-8', errors='ignore')
                    print("Text snippet:", text[:200])
            except Exception as e:
                print("Failed to inspect bytes:", e)
        except Exception as e:
            print("Failed conversion to bytes:", e)

if __name__ == "__main__":
    inspect()
