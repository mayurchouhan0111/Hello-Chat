import os

def delete_backups():
    print("Scanning for .svga.bak files to delete in assets/...")
    deleted_count = 0
    total_freed = 0
    
    for root, dirs, files in os.walk("assets"):
        for file in files:
            if file.endswith(".svga.bak") or file.endswith(".bak"):
                path = os.path.join(root, file)
                try:
                    size = os.path.getsize(path)
                    os.remove(path)
                    print(f"Deleted backup: {path} ({size / 1024 / 1024:.2f} MB)")
                    deleted_count += 1
                    total_freed += size
                except Exception as e:
                    print(f"Error deleting {path}: {e}")
                    
    print(f"\nCleanup finished! Deleted {deleted_count} backup files, freeing {total_freed / 1024 / 1024:.2f} MB of space.")

if __name__ == "__main__":
    delete_backups()
