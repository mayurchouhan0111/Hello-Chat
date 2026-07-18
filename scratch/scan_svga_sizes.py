import os

def scan_svga():
    print("Scanning for SVGA files in workspace...")
    total_size = 0
    svga_files = []
    
    for root, dirs, files in os.walk("."):
        # Skip node_modules, .git, etc.
        if "node_modules" in root or ".git" in root or "build" in root or ".dart_tool" in root:
            continue
        for file in files:
            if file.endswith(".svga"):
                path = os.path.join(root, file)
                size = os.path.getsize(path)
                svga_files.append((path, size))
                total_size += size
                
    # Sort by size descending
    svga_files.sort(key=lambda x: x[1], reverse=True)
    
    print(f"Found {len(svga_files)} SVGA files. Total size: {total_size / 1024 / 1024:.2f} MB")
    for path, size in svga_files:
        print(f"  - {path}: {size / 1024 / 1024:.2f} MB ({size} bytes)")

if __name__ == "__main__":
    scan_svga()
