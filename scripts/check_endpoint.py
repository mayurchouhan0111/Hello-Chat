import urllib.request
try:
    res = urllib.request.urlopen('http://localhost:5174/agencies')
    print(f"HTTP Status: {res.status}")
except Exception as e:
    print(f"Error: {e}")
