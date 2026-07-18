import os

def scan_large_files():
    print("Scanning for files larger than 1MB in assets/...")
    large_files = []
    
    for root, dirs, files in os.walk("assets"):
        for file in files:
            path = os.path.join(root, file)
            try:
                size = os.path.getsize(path)
                if size > 1 * 1024 * 1024: # > 1MB
                    large_files.append((path, size))
            except Exception as e:
                print(f"Error checking {path}: {e}")
                
    # Sort by size descending
    large_files.sort(key=lambda x: x[1], reverse=True)
    
    print(f"Found {len(large_files)} files larger than 1MB:")
    for path, size in large_files:
        print(f"  - {path}: {size / 1024 / 1024:.2f} MB ({size} bytes)")

if __name__ == "__main__":
    scan_large_files()
