import os
import re

# Define the new 11-group model
LEVEL_GROUPS = [
    {"range": (1, 9), "color": "0xFFB0BEC5", "xp": 10000, "name": "Silver"},
    {"range": (10, 19), "color": "0xFF4DB6AC", "xp": 25000, "name": "Teal/Green"},
    {"range": (20, 29), "color": "0xFFFFD700", "xp": 50000, "name": "Gold"},
    {"range": (30, 39), "color": "0xFFFF4081", "xp": 100000, "name": "Pink"},
    {"range": (40, 49), "color": "0xFF00E5FF", "xp": 200000, "name": "Cyan"},
    {"range": (50, 59), "color": "0xFF4CAF50", "xp": 300000, "name": "Green"},
    {"range": (60, 69), "color": "0xFF2196F3", "xp": 400000, "name": "Blue"},
    {"range": (70, 79), "color": "0xFF9C27B0", "xp": 500000, "name": "Purple"},
    {"range": (80, 89), "color": "0xFFFF9800", "xp": 600000, "name": "Orange"},
    {"range": (90, 99), "color": "0xFFF44336", "xp": 700000, "name": "Red"},
    {"range": (100, 100), "color": "0xFF212121", "xp": 1000000, "name": "Obsidian/Gold"},
]

def generate_dart_code():
    color_logic = []
    xp_logic = []
    badge_logic = []

    for i, group in enumerate(LEVEL_GROUPS):
        start, end = group['range']
        color = group['color']
        xp = group['xp']
        name = group['name']

        if start == end:
            color_logic.append(f"    if (level == {start}) return const Color({color}); // {name}")
            badge_logic.append(f"    if (level == {start}) return {i};")
        else:
            color_logic.append(f"    if (level <= {end}) return const Color({color}); // {name}")
            badge_logic.append(f"    if (level <= {end}) return {i};")
            
        if start < 100:
            xp_logic.append(f"    if (currentLevel < {end + 1}) return {xp};")

    return {
        "color": "\n".join(color_logic),
        "xp": "\n".join(xp_logic),
        "badge": "\n".join(badge_logic)
    }

def update_level_utils(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    codes = generate_dart_code()

    # Update getLevelColor
    color_pattern = r"static Color getLevelColor\(int level\) \{(.*?)\n  \}"
    new_color_body = "\n" + codes['color'] + "\n    return const Color(0xFFF58A4C);"
    content = re.sub(color_pattern, f"static Color getLevelColor(int level) {{{new_color_body}\n  }}", content, flags=re.DOTALL)

    # Update getXPRequiredForNextLevel
    xp_pattern = r"static int getXPRequiredForNextLevel\(int currentLevel\) \{(.*?)\n  \}"
    new_xp_body = "\n" + codes['xp'] + "\n    return 1000000;"
    content = re.sub(xp_pattern, f"static int getXPRequiredForNextLevel(int currentLevel) {{{new_xp_body}\n  }}", content, flags=re.DOTALL)

    # Update getLevelBadgeIndex
    badge_pattern = r"static int getLevelBadgeIndex\(int level\) \{(.*?)\n  \}"
    new_badge_body = "\n" + codes['badge'] + "\n    return 10;"
    content = re.sub(badge_pattern, f"static int getLevelBadgeIndex(int level) {{{new_badge_body}\n  }}", content, flags=re.DOTALL)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Successfully updated {file_path}")

if __name__ == "__main__":
    utils_path = os.path.join("lib", "utils", "level_utils.dart")
    if os.path.exists(utils_path):
        update_level_utils(utils_path)
    else:
        print(f"Error: {utils_path} not found.")
