import firebase_admin
from firebase_admin import credentials, storage
import os

def upload_large_svga():
    print("Initializing Firebase Admin SDK...")
    
    cert_path = os.path.join("scripts", "service-account-key.json")
    if not os.path.exists(cert_path):
        print(f"Error: Firebase service account key not found at {cert_path}")
        return

    bucket_name = "hellochat-e8965.firebasestorage.app"
    svga_path = os.path.join("assets", "svga", "100_optimized.svga")
    
    if not os.path.exists(svga_path):
        print(f"Error: SVGA file not found at {svga_path}")
        return

    print(f"Uploading {svga_path} ({os.path.getsize(svga_path)/(1024*1024):.2f} MB) to Firebase Storage bucket '{bucket_name}'...")

    try:
        cred = credentials.Certificate(cert_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': bucket_name
        })

        bucket = storage.bucket()
        blob = bucket.blob("gifts/animations/crystal_palace.svga")
        
        # Upload file
        blob.upload_from_filename(svga_path, content_type="application/octet-stream")
        
        # Make it public so anyone can download it
        blob.make_public()
        
        print("\nSuccessfully uploaded large SVGA file to Firebase Storage!")
        print(f"  ID: crystal_palace")
        print(f"  URL: {blob.public_url}\n")
        
    except Exception as e:
        print(f"Error uploading to Firebase Storage: {e}")

if __name__ == "__main__":
    upload_large_svga()
