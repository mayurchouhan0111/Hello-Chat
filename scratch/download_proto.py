import urllib.request
import os

url = "https://raw.githubusercontent.com/svga/SVGA-Format/master/proto/svga.proto"
dest = "scratch/svga.proto"

try:
    print(f"Downloading {url} to {dest}...")
    urllib.request.urlretrieve(url, dest)
    print("Success!")
    with open(dest, "r", encoding="utf-8") as f:
        lines = f.readlines()
        print(f"File has {len(lines)} lines.")
except Exception as e:
    print(f"Error downloading: {e}")
