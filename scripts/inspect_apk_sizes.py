import zipfile
import os

apk_path = os.path.join("build", "app", "outputs", "flutter-apk", "app-release.apk")
print(f"Inspecting APK: {apk_path}")
total_size = os.path.getsize(apk_path)
print(f"Total APK Size: {total_size:,} bytes ({total_size / (1024*1024):.2f} MB)")

entries = []
with zipfile.ZipFile(apk_path, 'r') as z:
    for info in z.infolist():
        entries.append((info.filename, info.file_size, info.compress_size))

entries.sort(key=lambda x: x[1], reverse=True)

print("\n--- TOP 10 LARGEST ITEMS IN RELEASE APK (by uncompressed size) ---")
print(f"{'Rank':<5} {'Uncompressed (MB)':<18} {'Compressed (MB)':<16} {'Filename'}")
print("-" * 80)
for idx, (name, size, csize) in enumerate(entries[:10], 1):
    print(f"{idx:<5} {size / (1024*1024):<18.2f} {csize / (1024*1024):<16.2f} {name}")
