import os
import sys
import firebase_admin
from firebase_admin import credentials, storage, firestore
from PIL import Image
try:
    from rembg import remove
except ImportError:
    print("Error: 'rembg' library not found. Please install it with: pip install rembg pillow firebase-admin")
    sys.exit(1)

# --- CONFIGURATION ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
SERVICE_ACCOUNT_KEY = os.path.join(SCRIPT_DIR, 'service-account-key.json') 
BUCKET_NAME = 'hellochat-e8965.firebasestorage.app'
TARGET_SIZE = (512, 512)  # Same as VIP frames

# Local asset paths
ASSET_DIR = os.path.join(ROOT_DIR, 'assets', 'images', 'super')
TEMP_DIR = os.path.join(SCRIPT_DIR, 'temp_frames')
os.makedirs(TEMP_DIR, exist_ok=True)

FRAMES = {
    'super-admin': 'super-admin.png',
    'admin': 'admin.png',
    'reseller': 'reseller.png'
}

def process_image(input_path, output_path, target_size=TARGET_SIZE, extra_padding=0):
    """Removes background, resizes, and center-crops the image to ensure perfect alignment."""
    print(f"--- Processing: {os.path.basename(input_path)} ---")
    
    # 1. Remove Background
    with open(input_path, 'rb') as i:
        input_data = i.read()
        output_data = remove(input_data)
        
    with open(output_path, 'wb') as o:
        o.write(output_data)
    
    # 2. Resize and Center
    img = Image.open(output_path)
    img = img.convert("RGBA")
    
    # Auto-crop to content (remove extra transparent space)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # Calculate target size with extra padding (for super-admin to make it appear larger)
    if extra_padding > 0:
        padded_size = (target_size[0] - extra_padding, target_size[1] - extra_padding)
    else:
        padded_size = target_size
        
    # Resize while maintaining aspect ratio
    img.thumbnail(padded_size, Image.Resampling.LANCZOS)
    
    # Create new transparent background and center the image
    new_img = Image.new("RGBA", target_size, (0, 0, 0, 0))
    offset = ((target_size[0] - img.size[0]) // 2, (target_size[1] - img.size[1]) // 2)
    new_img.paste(img, offset)
    
    new_img.save(output_path, "PNG")
    print(f"Successfully processed and saved to {output_path}")
    return output_path

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        exit(1)
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred, {'storageBucket': BUCKET_NAME})
    return firestore.client()

def upload_frame(local_path, destination_blob_name):
    print(f"Uploading {local_path} to {destination_blob_name}...")
    bucket = storage.bucket()
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(local_path)
    blob.make_public()
    return blob.public_url

def main():
    db = initialize_firebase()
    print("[OK] Firebase Initialized")

    # 1. Upload Assets
    frame_urls = {}
    for name, filename in FRAMES.items():
        local_path = os.path.join(ASSET_DIR, filename)
        if not os.path.exists(local_path):
            print(f"!! Warning: {local_path} not found. Skipping.")
            continue
        
        # Add padding for super-admin to make frame appear smaller
        extra_padding = 150 if name == 'super-admin' else 0
        
        # Process image before upload to ensure perfect size/alignment
        processed_path = os.path.join(TEMP_DIR, filename)
        process_image(local_path, processed_path, extra_padding=extra_padding)
        
        storage_path = f"official_assets/frames/{filename}"
        url = upload_frame(processed_path, storage_path)
        frame_urls[name] = url
        print(f"[OK] Uploaded {name}: {url}")

    # 2. Register in Firestore (System Config)
    if frame_urls:
        db.collection("system_configs").document("admin_frames").set({
            "frames": frame_urls,
            "updatedAt": firestore.SERVER_TIMESTAMP
        })
        print("[OK] Firestore system_configs/admin_frames updated")
    
    print("\n[OK] All done! Frames uploaded and updated in Firestore.")

if __name__ == "__main__":
    main()
