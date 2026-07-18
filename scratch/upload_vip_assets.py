import time
import hashlib
import requests
import os

def upload_vip_assets():
    print("Starting VIP SVGA assets upload to Cloudinary...")

    api_secret = "eNzBz9AxS9d_VF2ebvSoAth18s0"
    api_key = "256641331991177"
    cloud_name = "dceh4ob2i"
    folder = "vip/VIP 1"

    vip_files = [
        'Badge.svga',
        'Crown 1.svga',
        'Entry.svga',
        'Frame.svga',
        'Sound Waives.svga',
        'Strip.svga',
        'Tag.svga'
    ]

    base_dir = os.path.join("assets", "VIP", "VIP 1")

    for file_name in vip_files:
        file_path = os.path.join(base_dir, file_name)
        if not os.path.exists(file_path):
            print(f"Error: File not found at {file_path}")
            continue

        print(f"Uploading {file_name} ({os.path.getsize(file_path)/(1024*1024):.2f} MB)...")
        
        timestamp = int(time.time())
        params_to_sign = f"folder={folder}&timestamp={timestamp}{api_secret}"
        signature = hashlib.sha1(params_to_sign.encode('utf-8')).hexdigest()

        url = f"https://api.cloudinary.com/v1_1/{cloud_name}/raw/upload"
        
        try:
            with open(file_path, 'rb') as f:
                files = {'file': f}
                data = {
                    'api_key': api_key,
                    'timestamp': timestamp,
                    'signature': signature,
                    'folder': folder
                }
                response = requests.post(url, files=files, data=data)
                result = response.json()
                
                if 'secure_url' in result:
                    print(f"Successfully uploaded {file_name}!")
                    print(f"URL: {result['secure_url']}\n")
                else:
                    print(f"Failed to upload {file_name}: {result}\n")
        except Exception as e:
            print(f"Error uploading {file_name}: {e}\n")

if __name__ == "__main__":
    upload_vip_assets()
