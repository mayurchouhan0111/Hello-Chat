import os
import urllib.request
import zipfile
import io

url = "https://fonts.google.com/download?family=Plus%20Jakarta%20Sans"
print(f"Downloading from {url}...")

req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        with zipfile.ZipFile(io.BytesIO(response.read())) as z:
            static_dir = 'static/'
            for file_info in z.infolist():
                if file_info.filename.startswith(static_dir) and file_info.filename.endswith('.ttf'):
                    # Extract just the filename, not the static/ dir
                    filename = os.path.basename(file_info.filename)
                    if filename:
                        print(f"Extracting {filename}...")
                        content = z.read(file_info.filename)
                        with open(f"assets/fonts/{filename}", 'wb') as f:
                            f.write(content)
                        
    print("Fonts downloaded and extracted successfully.")
except Exception as e:
    print(f"Error: {e}")
