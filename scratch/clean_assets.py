import os
import shutil

def clean_assets():
    base_dir = r'd:\UnHuman\Apps\Hello Chat\hellochat\assets\rocket'
    old_folder = os.path.join(base_dir, 'Rocket set SVGA')
    new_folder = os.path.join(base_dir, 'rocket_set_svga')
    
    if not os.path.exists(old_folder):
        print(f"Error: {old_folder} not found.")
        return

    if not os.path.exists(new_folder):
        os.makedirs(new_folder)
        print(f"Created {new_folder}")

    print("Renaming and moving files...")
    for filename in os.listdir(old_folder):
        if filename.endswith('.svga'):
            # Convert X.Y.svga to rocket_X_Y.svga or just keep X_Y.svga
            new_filename = filename.replace('.', '_', filename.count('.') - 1)
            # Remove any spaces
            new_filename = new_filename.replace(' ', '_').lower()
            
            old_path = os.path.join(old_folder, filename)
            new_path = os.path.join(new_folder, new_filename)
            
            shutil.copy2(old_path, new_path)
            print(f"  {filename} -> {new_filename}")

    print("\nCleanup complete.")
    print(f"New asset path: assets/rocket/rocket_set_svga/")

if __name__ == "__main__":
    clean_assets()
