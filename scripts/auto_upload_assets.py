import os
import uuid
import firebase_admin
from firebase_admin import credentials, storage, firestore
from PIL import Image
from rembg import remove

# --- CONFIGURATION ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_KEY = os.path.join(SCRIPT_DIR, 'service-account-key.json') 
BUCKET_NAME = 'hellochat-e8965.firebasestorage.app'
TARGET_SIZE = (512, 512) 

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        exit(1)
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred, {'storageBucket': BUCKET_NAME})
    return firestore.client()

def punch_center_hole(img, hole_radius_ratio=0.92):
    """Aggressively removes the center while being smart about the frame's edges."""
    from PIL import ImageDraw, ImageFilter
    img = img.convert("RGBA")
    width, height = img.size
    center_x, center_y = width // 2, height // 2
    
    # 1. Create a Very Aggressive Mask
    mask = Image.new("L", (width, height), 255)
    draw = ImageDraw.Draw(mask)
    radius = int(min(width, height) * hole_radius_ratio // 2)
    draw.ellipse((center_x - radius, center_y - radius, center_x + radius, center_y + radius), fill=0)
    
    # Optional: Slightly blur mask to avoid hard edges
    mask = mask.filter(ImageFilter.GaussianBlur(1))
    
    # 2. Get target color for additional color-based removal
    target_color = img.getpixel((center_x, center_y))
    
    new_data = []
    old_data = img.getdata()
    mask_data = mask.getdata()
    
    for i in range(len(old_data)):
        m = mask_data[i]
        pix = old_data[i]
        
        # Calculate color distance to center pixel (only if in the outer hole region)
        color_dist = sum(abs(pix[j] - target_color[j]) for j in range(3)) if len(pix) >= 3 else 255
        
        # If mask says transparent OR it's very close to the center color in the hole zone
        if m < 128 or (m < 200 and color_dist < 60):
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(pix)
            
    img.putdata(new_data)
    return img

def process_image(input_path, output_path, is_frame=False):
    print(f"--- Processing: {os.path.basename(input_path)} {'(Frame)' if is_frame else ''} ---")
    with open(input_path, 'rb') as i:
        input_data = i.read()
        output_data = remove(input_data)
    with open(output_path, 'wb') as o:
        o.write(output_data)
    
    img = Image.open(output_path).convert("RGBA")
    
    if is_frame:
        img = punch_center_hole(img)
    else:
        # Only crop non-frames (like badges)
        bbox = img.getbbox()
        if bbox: img = img.crop(bbox)

    img.thumbnail(TARGET_SIZE, Image.Resampling.LANCZOS)
    new_img = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    offset = ((TARGET_SIZE[0] - img.size[0]) // 2, (TARGET_SIZE[1] - img.size[1]) // 2)
    new_img.paste(img, offset)
    new_img.save(output_path, "PNG")

def upload_to_firebase(local_path, destination_blob_name):
    bucket = storage.bucket()
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(local_path)
    blob.make_public()
    return blob.public_url

def main():
    db = initialize_firebase()
    output_dir = os.path.join(SCRIPT_DIR, 'processed_assets')
    if not os.path.exists(output_dir): os.makedirs(output_dir)

    # Asset Mapping (File name prefix -> Tier ID)
    mapping = {
        'VIP-1': 'vip1',
        'VIP-2': 'vip2',
        'VIP-3': 'vip3',
        'VIP-4': 'vip4',
        'VIP-5': 'vip5',
        'VIP-6': 'vip6',
        'VIP-7': 'vip7',
        'VIP-8': 'vip8', # Just in case
    }

    folders = {
        'new-frames': 'profileFrame',
        'badge_assets': 'badgeIcon'
    }

    for folder, field in folders.items():
        dir_path = os.path.join(SCRIPT_DIR, folder)
        if not os.path.exists(dir_path): continue
        
        print(f"\n--- Processing Folder: {folder} ({field}) ---")
        for filename in os.listdir(dir_path):
            if not filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')): continue
            
            # Find tier
            tier_id = None
            for prefix, tid in mapping.items():
                if filename.startswith(prefix):
                    tier_id = tid
                    break
            
            if not tier_id:
                print(f"No mapping found for {filename}, skipping.")
                continue

            input_path = os.path.join(dir_path, filename)
            processed_filename = f"processed_{field}_{tier_id}_{uuid.uuid4().hex[:6]}.png"
            output_path = os.path.join(output_dir, processed_filename)

            try:
                # For 'new-frames', we still need to crop but skip background removal
                if folder == 'new-frames':
                    print(f"Cropping pre-cleared frame: {filename}")
                    img = Image.open(input_path).convert("RGBA")
                    # Crop to the actual visible content
                    bbox = img.getbbox()
                    if bbox: img = img.crop(bbox)
                    
                    # Standard 512x512 thumbnailing
                    img.thumbnail(TARGET_SIZE, Image.Resampling.LANCZOS)
                    new_img = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
                    offset = ((TARGET_SIZE[0] - img.size[0]) // 2, (TARGET_SIZE[1] - img.size[1]) // 2)
                    new_img.paste(img, offset)
                    new_img.save(output_path, "PNG")
                else:
                    is_frame = (field == 'profileFrame')
                    process_image(input_path, output_path, is_frame=is_frame)
                
                url = upload_to_firebase(output_path, f"vip_assets/processed/{processed_filename}")
                print(f"Uploaded {filename} -> {url}")

                # Update Firestore
                updated = False
                for col in ["vip_tiers", "noble_tiers", "svip_levels"]:
                    doc_ref = db.collection(col).document(tier_id)
                    if doc_ref.get().exists:
                        doc_ref.update({field: url})
                        print(f"Updated {col}/{tier_id} field {field}")
                        updated = True
                        break
                if not updated:
                    print(f"Warning: Could not find document {tier_id} in any collection.")
            except Exception as e:
                print(f"Error with {filename}: {e}")

if __name__ == "__main__":
    main()
