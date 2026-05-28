import time
import hashlib
import requests
import os

def upload_svga_files():
    print("Starting SVGA files upload to Cloudinary...")

    api_secret = "eNzBz9AxS9d_VF2ebvSoAth18s0"
    api_key = "256641331991177"
    cloud_name = "dceh4ob2i"
    folder = "gifts/animations"

    svga_files = [
        {'id': 'mystic_rings', 'file': '164 (1).svga'},
        {'id': 'royal_carriage', 'file': '235.svga'},
        {'id': 'crystal_palace', 'file': '100.svga'}
    ]

    for item in svga_files:
        file_path = os.path.join("assets", "svga", item['file'])
        if not os.path.exists(file_path):
            print(f"Error: File not found at {file_path}")
            continue

        print(f"Uploading {item['file']} ({os.path.getsize(file_path)/(1024*1024):.2f} MB)...")
        
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
                    print(f"Successfully uploaded {item['file']}!")
                    print(f"  ID: {item['id']}")
                    print(f"  URL: {result['secure_url']}\n")
                else:
                    print(f"Failed to upload {item['file']}: {result}\n")
        except Exception as e:
            print(f"Error uploading {item['file']}: {e}\n")

if __name__ == "__main__":
    upload_svga_files()
