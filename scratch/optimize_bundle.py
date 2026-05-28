import os
import shutil
import re
from PIL import Image, ImageSequence

def run_optimization():
    print("Starting Automated Asset Optimization and Cleanup...")

    # Define paths
    base_dir = "."
    assets_dir = os.path.join(base_dir, "assets")
    
    # 1. Delete Duplicate Rocket SVGA Folder
    duplicate_svga_dir = os.path.join(assets_dir, "rocket", "Rocket set SVGA")
    if os.path.exists(duplicate_svga_dir):
        print(f"Deleting duplicate SVGA folder: {duplicate_svga_dir}")
        try:
            shutil.rmtree(duplicate_svga_dir)
            print("Successfully deleted duplicate SVGA folder.")
        except Exception as e:
            print(f"Failed to delete duplicate SVGA folder: {e}")
    else:
        print("Duplicate SVGA folder 'Rocket set SVGA' not found or already deleted.")

    # 2. Delete Unused SVGA Variations
    svga_dir = os.path.join(assets_dir, "rocket", "rocket_set_svga")
    if os.path.exists(svga_dir):
        print(f"\nScanning for unused SVGA variations in: {svga_dir}")
        for filename in os.listdir(svga_dir):
            if filename.endswith(".svga"):
                # Keep only variations ending in _3.svga
                if not filename.endswith("_3.svga"):
                    file_path = os.path.join(svga_dir, filename)
                    try:
                        os.remove(file_path)
                        print(f"  Deleted unused SVGA variation: {filename}")
                    except Exception as e:
                        print(f"  Failed to delete {filename}: {e}")
        print("Cleaned up unused SVGA variations (kept only *_3.svga files).")
    else:
        print(f"SVGA folder not found at {svga_dir}")

    # 3. Delete Unused levels_raw Folder
    levels_raw_dir = os.path.join(assets_dir, "images", "levels_raw")
    if os.path.exists(levels_raw_dir):
        print(f"\nDeleting unused levels_raw folder: {levels_raw_dir}")
        try:
            shutil.rmtree(levels_raw_dir)
            print("Successfully deleted levels_raw folder.")
        except Exception as e:
            print(f"Failed to delete levels_raw folder: {e}")
    else:
        print("levels_raw folder not found or already deleted.")

    # 4. Delete Unused UI PNG Images
    unused_images = [
        "Gemini_Generated_Image_fll0offll0offll0.png",
        "LEVEL.png",
        "image.png",
        "resize.png"
    ]
    images_dir = os.path.join(assets_dir, "images")
    print(f"\nScanning for unused UI images in: {images_dir}")
    for img_name in unused_images:
        img_path = os.path.join(images_dir, img_name)
        if os.path.exists(img_path):
            try:
                os.remove(img_path)
                print(f"  Deleted unused image: {img_name}")
            except Exception as e:
                print(f"  Failed to delete {img_name}: {e}")
        else:
            print(f"  {img_name} not found or already deleted.")

    # 5. Delete Empty Rive Folder
    rive_dir = os.path.join(assets_dir, "animations", "rive")
    if os.path.exists(rive_dir):
        print(f"\nDeleting empty Rive folder: {rive_dir}")
        try:
            shutil.rmtree(rive_dir)
            print("Successfully deleted Rive folder.")
        except Exception as e:
            pass

    # 6. Compress Sticker GIFs
    stickers_dir = os.path.join(assets_dir, "stickers")
    if os.path.exists(stickers_dir):
        print(f"\nStarting compression of sticker GIFs in: {stickers_dir}")
        total_original_size = 0
        total_new_size = 0
        compressed_count = 0

        # Walk through sticker directories
        for root, dirs, files in os.walk(stickers_dir):
            for file in files:
                if file.lower().endswith(".gif"):
                    file_path = os.path.join(root, file)
                    original_size = os.path.getsize(file_path)
                    total_original_size += original_size

                    # Compress in-place
                    try:
                        im = Image.open(file_path)
                        is_animated = getattr(im, "is_animated", False)
                        
                        max_size = (128, 128)
                        
                        if not is_animated:
                            # Static GIF
                            frame = im.convert('RGBA')
                            resized = frame.resize(max_size, Image.Resampling.LANCZOS)
                            # Convert back to palette/adaptive to save space
                            resized.convert('P', palette=Image.Palette.ADAPTIVE).save(file_path, 'GIF', optimize=True)
                        else:
                            # Animated GIF
                            frames = []
                            durations = []
                            # Get duration
                            dur = im.info.get('duration', 40)
                            if not dur or dur < 10:
                                dur = 40 # Fallback
                            
                            for i, frame in enumerate(ImageSequence.Iterator(im)):
                                # Keep every second frame to drop frame count by 50%
                                if i % 2 == 0:
                                    frame_rgba = frame.convert('RGBA')
                                    resized = frame_rgba.resize(max_size, Image.Resampling.LANCZOS)
                                    frames.append(resized)
                                    durations.append(dur * 2)

                            if frames:
                                # Save back
                                frames[0].save(
                                    file_path,
                                    save_all=True,
                                    append_images=frames[1:],
                                    loop=0,
                                    duration=durations,
                                    optimize=True
                                )
                        
                        new_size = os.path.getsize(file_path)
                        total_new_size += new_size
                        compressed_count += 1
                        savings = ((original_size - new_size) / original_size) * 100
                        print(f"  Compressed: {os.path.basename(file_path)} | {original_size/1024:.1f}KB -> {new_size/1024:.1f}KB ({savings:.1f}% saved)")
                    
                    except Exception as e:
                        print(f"  Error compressing {os.path.basename(file_path)}: {e}")
                        total_new_size += original_size # didn't change

        original_mb = total_original_size / (1024 * 1024)
        new_mb = total_new_size / (1024 * 1024)
        saved_mb = original_mb - new_mb
        pct_saved = (saved_mb / original_mb) * 100 if original_mb > 0 else 0
        print(f"\nStickers compression complete!")
        print(f"  - Total Sticker Files Compressed: {compressed_count}")
        print(f"  - Stickers Folder Original Size: {original_mb:.2f} MB")
        print(f"  - Stickers Folder Compressed Size: {new_mb:.2f} MB")
        print(f"  - Total Stickers Space Saved: {saved_mb:.2f} MB ({pct_saved:.1f}% saved)")
    else:
        print(f"Stickers folder not found at {stickers_dir}")

    print("\nAll Asset Optimizations Completed Successfully!")

if __name__ == "__main__":
    run_optimization()
