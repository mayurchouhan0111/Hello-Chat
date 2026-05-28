import os
import re

def find_unused_deps():
    pubspec_path = "pubspec.yaml"
    lib_dir = "lib"

    if not os.path.exists(pubspec_path) or not os.path.exists(lib_dir):
        print("Error: pubspec.yaml or lib directory not found.")
        return

    # Parse dependencies from pubspec.yaml
    deps = []
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()
        # Find dependencies section
        dep_section = re.search(r"dependencies:\s*\n(.*?)(?=\ndev_dependencies:|\nflutter:|$)", content, re.DOTALL)
        if dep_section:
            lines = dep_section.group(1).split("\n")
            for line in lines:
                line = line.strip()
                if line and not line.startswith("#") and ":" in line:
                    dep_name = line.split(":")[0].strip()
                    if dep_name not in ["flutter", "sdk"]:
                        deps.append(dep_name)

    print(f"Loaded {len(deps)} dependencies from pubspec.yaml.")

    # Scan lib for imports
    imported_packages = set()
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        for line in f:
                            match = re.match(r"\s*import\s+['\"]package:([^/]+)/", line)
                            if match:
                                imported_packages.add(match.group(1))
                except Exception as e:
                    pass

    print(f"Imported packages in lib/ ({len(imported_packages)})")

    # Find unused deps
    unused = []
    for dep in deps:
        if dep not in imported_packages:
            unused.append(dep)

    print("\n--- Unused dependencies ---")
    for u in sorted(unused):
        print(f"  - {u}")

if __name__ == "__main__":
    find_unused_deps()
