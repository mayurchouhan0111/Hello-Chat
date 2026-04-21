import os
import re
from PIL import Image

# Configuration
ASSETS_DIR = 'assets'
THRESHOLD_KB = 150  # Only convert images larger than 150KB
QUALITY = 80        # WebP quality (0-100)
ROOT_DIR = os.getcwd()

def optimize_images():
    converted_map = {} # Maps old_path -> new_path

    print(f"🚀 Starting asset optimization (Threshold: {THRESHOLD_KB}KB)...")

    if not os.path.exists(ASSETS_DIR):
        print(f"❌ Error: {ASSETS_DIR} directory not found.")
        return

    for root, dirs, files in os.walk(ASSETS_DIR):
        for file in files:
            if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                file_path = os.path.join(root, file)
                file_size = os.path.getsize(file_path) / 1024

                if file_size > THRESHOLD_KB:
                    print(f"📦 Processing {file} ({file_size:.1f}KB)...")
                    
                    # Create new filename
                    base_name = os.path.splitext(file)[0]
                    new_file = f"{base_name}.webp"
                    new_path = os.path.join(root, new_file)

                    # Convert to WebP
                    try:
                        with Image.open(file_path) as img:
                            # Convert RGBA to RGB if saving as WebP (Pillow handles transparency in WebP well)
                            img.save(new_path, 'WEBP', quality=QUALITY)
                        
                        # Store for reference updating
                        rel_old = os.path.relpath(file_path, ROOT_DIR).replace('\\', '/')
                        rel_new = os.path.relpath(new_path, ROOT_DIR).replace('\\', '/')
                        converted_map[rel_old] = rel_new

                        # Delete original
                        os.remove(file_path)
                        print(f"✅ Converted: {file} -> {new_file} (Reduced to {os.path.getsize(new_path)/1024:.1f}KB)")
                    except Exception as e:
                        print(f"❌ Failed to convert {file}: {e}")

    if converted_map:
        update_references(converted_map)
    else:
        print("🙌 No large images found to optimize.")

def update_references(converted_map):
    print("\n🔗 Updating project references...")
    
    # Files to scan for replacements
    extensions_to_scan = ('.dart', '.yaml', '.json')
    
    for root, dirs, files in os.walk(ROOT_DIR):
        # Skip segments that usually don't contain asset references or are auto-generated
        if any(skip in root for skip in ['build', '.dart_tool', '.git', 'android', 'ios']):
            continue
            
        for file in files:
            if file.endswith(extensions_to_scan):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    new_content = content
                    for old, new in converted_map.items():
                        # Replace full paths
                        if old in new_content:
                            new_content = new_content.replace(old, new)
                        
                        # Replace just the filenames (case where only filename is used in string)
                        old_name = os.path.basename(old)
                        new_name = os.path.basename(new)
                        if old_name in new_content:
                             new_content = new_content.replace(old_name, new_name)

                    if new_content != content:
                        with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                            f.write(new_content)
                        print(f"📝 Updated references in: {os.path.relpath(file_path, ROOT_DIR)}")
                except Exception as e:
                    # Skip files with encoding issues
                    pass

if __name__ == "__main__":
    optimize_images()
    print("\n✨ Optimization complete! Run 'flutter clean' and 'flutter pub get' to refresh assets.")
