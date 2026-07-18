import firebase_admin
from firebase_admin import credentials, storage
import os

def upload_large_vip_svgas():
    print("Initializing Firebase Admin SDK for VIP assets upload...")
    
    cert_path = os.path.join("scripts", "service-account-key.json")
    if not os.path.exists(cert_path):
        print(f"Error: Firebase service account key not found at {cert_path}")
        return

    bucket_name = "hellochat-e8965.firebasestorage.app"
    
    files_to_upload = [
        {"name": "Crown 1.svga", "path": os.path.join("assets", "VIP", "VIP 1", "Crown 1.svga"), "dest": "vip/VIP_1/Crown_1.svga"},
        {"name": "Entry.svga", "path": os.path.join("assets", "VIP", "VIP 1", "Entry.svga"), "dest": "vip/VIP_1/Entry.svga"},
    ]

    try:
        cred = credentials.Certificate(cert_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': bucket_name
        })
        bucket = storage.bucket()

        for f in files_to_upload:
            path = f["path"]
            dest = f["dest"]
            name = f["name"]
            
            if not os.path.exists(path):
                print(f"Error: File not found at {path}")
                continue

            size_mb = os.path.getsize(path)/(1024*1024)
            print(f"Uploading {name} ({size_mb:.2f} MB) to Firebase Storage as '{dest}'...")
            
            blob = bucket.blob(dest)
            blob.upload_from_filename(path, content_type="application/octet-stream")
            blob.make_public()
            
            print(f"Successfully uploaded {name}!")
            print(f"URL: {blob.public_url}\n")
            
    except Exception as e:
        print(f"Error uploading to Firebase Storage: {e}")

if __name__ == "__main__":
    upload_large_vip_svgas()
