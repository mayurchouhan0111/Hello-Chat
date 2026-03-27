import os
import urllib.request

fonts = [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf'
]

base_url = "https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/static/"

for font in fonts:
    url = f"{base_url}{font}"
    out_path = f"assets/fonts/{font}"
    print(f"Downloading {font} from {url}...")
    try:
        urllib.request.urlretrieve(url, out_path)
        print(f"Downloaded {font}")
    except Exception as e:
        print(f"Failed to download {font}: {e}")
