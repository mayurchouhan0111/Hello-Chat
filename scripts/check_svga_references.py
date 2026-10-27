import os
import glob

svga_files = [
    ("cat_gift.svga", "assets/svga/cat_gift.svga"),
    ("SVIP 5 ntry.svga", "assets/SVIP Kit/svip 5/SVIP 5 ntry.svga"),
    ("Crown 1_SVGA_SVGA.svga", "assets/SVIP Kit/svip 5/Crown 1_SVGA_SVGA.svga"),
    ("Crown 1_SVGA.svga", "assets/SVIP Kit/svip 4/Crown 1_SVGA.svga"),
    ("Crown 1.svga (VIP 2)", "assets/VIP/VIP 2/VIP 2/Crown 1.svga"),
    ("SVIP 3 Crown.svga", "assets/SVIP Kit/svip 3/SVIP 3 Crown.svga"),
    ("SVIP 2 Crown.svga", "assets/SVIP Kit/svip 2/SVIP 2 Crown.svga"),
]

dart_files = glob.glob("lib/**/*.dart", recursive=True)

print("=== CHECKING SVGA ASSET REFERENCES IN LIB/ ===")
for label, path_str in svga_files:
    basename = os.path.basename(path_str)
    matches = []
    for df in dart_files:
        content = open(df, encoding="utf-8", errors="ignore").read()
        if basename in content or path_str in content:
            # find line number
            for idx, line in enumerate(content.splitlines()):
                if basename in line or path_str in line:
                    matches.append((df, idx + 1, line.strip()))
    if matches:
        print(f"\n[REFERENCED] {label} ({path_str}):")
        for m in matches:
            print(f"  - {m[0]}:{m[1]} -> {m[2][:90]}")
    else:
        print(f"\n[UNUSED IN CODE] {label} ({path_str}) - NO STATIC REFERENCES IN LIB/")
