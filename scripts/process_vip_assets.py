import os
import sys
import json
import uuid
import firebase_admin
from firebase_admin import credentials, storage, firestore
from PIL import Image, ImageOps
try:
    from rembg import remove
except ImportError:
    print("Error: 'rembg' library not found. Please install it with: pip install rembg pillow firebase-admin")
    sys.exit(1)

# --- CONFIGURATION ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_KEY = os.path.join(SCRIPT_DIR, 'service-account-key.json') 
BUCKET_NAME = 'hellochat-e8965.firebasestorage.app'
TARGET_SIZE = (512, 512) 

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        print(f"Please place your Firebase service account JSON key in the 'scripts' folder and name it 'service-account-key.json'.")
        sys.exit(1)
        
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred, {
        'storageBucket': BUCKET_NAME
    })
    return firestore.client()

def process_image(input_path, output_path):
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
        
    # Resize while maintaining aspect ratio
    img.thumbnail(TARGET_SIZE, Image.Resampling.LANCZOS)
    
    # Create new transparent background and center the image
    new_img = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    offset = ((TARGET_SIZE[0] - img.size[0]) // 2, (TARGET_SIZE[1] - img.size[1]) // 2)
    new_img.paste(img, offset)
    
    new_img.save(output_path, "PNG")
    print(f"Successfully processed and saved to {output_path}")

def upload_to_firebase(local_path, destination_blob_name):
    bucket = storage.bucket()
    blob = bucket.blob(destination_blob_name)
    
    # Upload file
    blob.upload_from_filename(local_path)
    
    # Make it public or get signed URL
    blob.make_public()
    return blob.public_url

def main():
    db = initialize_firebase()
    
    output_dir = os.path.join(SCRIPT_DIR, 'processed_assets')
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Folders to check
    source_folders = ['input_assets', 'badge_assets']
    
    for folder_name in source_folders:
        current_input_dir = os.path.join(SCRIPT_DIR, folder_name)
        if not os.path.exists(current_input_dir):
            os.makedirs(current_input_dir)
            continue
            
        print(f"\n>>> Checking Folder: {folder_name} <<<")
        
        for filename in os.listdir(current_input_dir):
            if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                print(f"\n--- [Folder: {folder_name}] File: {filename} ---")
                tier_id = input(f"Enter Tier ID for {filename} (e.g., vip1, vip2) [Blank to skip]: ").strip()
                if not tier_id:
                    print("Skipping database update for this file.")
                    target_field = None
                else:
                    field_type = input("Type? (1) Frame, (2) Badge, (3) BG: ").strip()
                    field_map = {"1": "profileFrame", "2": "badgeIcon", "3": "backgroundImage"}
                    target_field = field_map.get(field_type)

                input_path = os.path.join(current_input_dir, filename)
                processed_filename = f"processed_{uuid.uuid4().hex[:8]}.png"
                output_path = os.path.join(output_dir, processed_filename)
                
                try:
                    # Process
                    process_image(input_path, output_path)
                    
                    # Upload
                    print("Uploading to Firebase...")
                    remote_path = f"vip_assets/processed/{processed_filename}"
                    public_url = upload_to_firebase(output_path, remote_path)
                    print(f"Uploaded! URL: {public_url}")
                    
                    # Update Firestore
                    if tier_id and target_field:
                        print(f"Updating Firestore doc '{tier_id}'...")
                        # Check both possible collections
                        for col in ["vip_tiers", "noble_tiers", "svip_levels"]:
                            doc_ref = db.collection(col).document(tier_id)
                            if doc_ref.get().exists:
                                doc_ref.update({target_field: public_url})
                                print(f"Updated {target_field} in {col}/{tier_id}")
                                break
                    
                    print(f"Done with {filename}!\n")
                
                except Exception as e:
                    print(f"Error processing {filename}: {str(e)}")

if __name__ == "__main__":
    main()
