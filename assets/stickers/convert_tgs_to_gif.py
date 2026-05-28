import os
import glob
import sys

def install_and_import(package):
    import importlib
    try:
        importlib.import_module(package)
    except ImportError:
        import subprocess
        print(f"Installing {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
    finally:
        globals()[package] = importlib.import_module(package)

try:
    from rlottie_python import LottieAnimation
except ImportError:
    print("Installing rlottie-python...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "rlottie-python"])
    from rlottie_python import LottieAnimation

def convert_all():
    # Find all .tgs files in the current directory and subdirectories
    tgs_files = glob.glob("**/*.tgs", recursive=True)
    
    if not tgs_files:
        print("No .tgs files found in the current directory.")
        return

    print(f"Found {len(tgs_files)} .tgs files. Starting conversion...")
    
    for tgs_file in tgs_files:
        gif_file = tgs_file.replace(".tgs", ".gif")
        if os.path.exists(gif_file):
            print(f"Skipping {tgs_file}, {gif_file} already exists.")
            continue
            
        print(f"Converting {tgs_file} to {gif_file}...")
        try:
            anim = LottieAnimation.from_tgs(tgs_file)
            anim.save_animation(gif_file)
            print(f"Successfully converted {tgs_file}")
        except Exception as e:
            print(f"Error converting {tgs_file}: {e}")
            
    print("Conversion process finished!")

if __name__ == "__main__":
    convert_all()
