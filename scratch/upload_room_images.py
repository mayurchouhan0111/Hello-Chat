import os
import sys
import time
import hashlib

# Ensure requirements are installed
try:
    from PIL import Image
except ImportError:
    import subprocess
    print("Pillow not found, installing pillow...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image

try:
    import requests
except ImportError:
    import subprocess
    print("requests not found, installing requests...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests


def remove_black_background(input_path, output_path, threshold=25):
    print(f"Removing black background from: {input_path}")
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()
    
    new_data = []
    for item in datas:
        r, g, b, a = item
        # If R, G, B are all below the threshold (very dark/black), make them transparent
        if r < threshold and g < threshold and b < threshold:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Saved transparent image to: {output_path}")


def upload_to_cloudinary(file_path, folder="room"):
    print(f"Uploading {os.path.basename(file_path)} to Cloudinary...")
    api_secret = "eNzBz9AxS9d_VF2ebvSoAth18s0"
    api_key = "256641331991177"
    cloud_name = "dceh4ob2i"
    
    timestamp = int(time.time())
    params_to_sign = f"folder={folder}&timestamp={timestamp}{api_secret}"
    signature = hashlib.sha1(params_to_sign.encode('utf-8')).hexdigest()
    
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
    
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
            url = result['secure_url']
            print(f"Successfully uploaded! URL: {url}")
            return url
        else:
            raise Exception(f"Failed to upload: {result}")


def main():
    room_dir = r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\room"
    
    chatgpt_img = os.path.join(room_dir, "ChatGPT Image Jul 15, 2026, 12_28_43 PM.png")
    gemini_img = os.path.join(room_dir, "Gemini_Generated_Image_d6go48d6go48d6go.png")
    
    transparent_chatgpt_img = os.path.join(room_dir, "ChatGPT_Image_Jul_15_2026_12_28_43_PM_transparent.png")
    
    # Remove black background from the ChatGPT image
    if os.path.exists(chatgpt_img):
        remove_black_background(chatgpt_img, transparent_chatgpt_img)
    else:
        print(f"Error: ChatGPT image not found at {chatgpt_img}")
        return
        
    print("-" * 50)
    
    urls = {}
    
    # Upload transparent ChatGPT image
    try:
        urls['ChatGPT Image (Transparent)'] = upload_to_cloudinary(transparent_chatgpt_img)
    except Exception as e:
        print(f"Error uploading transparent ChatGPT image: {e}")
        
    # Upload Gemini image
    if os.path.exists(gemini_img):
        try:
            urls['Gemini Image'] = upload_to_cloudinary(gemini_img)
        except Exception as e:
            print(f"Error uploading Gemini image: {e}")
    else:
        print(f"Warning: Gemini image not found at {gemini_img}")
        
    print("=" * 50)
    print("UPLOAD COMPLETED! Here are your links for the admin panel:")
    for name, url in urls.items():
        print(f"{name}: {url}")
    print("=" * 50)


if __name__ == "__main__":
    main()
