import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\functions\index.js'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''function getXPRequiredForNextLevel(currentLevel) {
    if (currentLevel <= 0) return 100;
    if (currentLevel < 50) {
        return currentLevel * 200;
    } else {
        return 10000 + (currentLevel - 50) * 2000;
    }
}'''

replacement = '''function getXPRequiredForNextLevel(currentLevel) {
    if (currentLevel < 10) return 10000;
    if (currentLevel < 20) return 25000;
    if (currentLevel < 30) return 50000;
    if (currentLevel < 40) return 100000;
    if (currentLevel < 50) return 200000;
    if (currentLevel < 60) return 300000;
    if (currentLevel < 70) return 400000;
    if (currentLevel < 80) return 500000;
    if (currentLevel < 90) return 600000;
    if (currentLevel < 100) return 1000000;
    return 1000000;
}'''

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced getXPRequiredForNextLevel successfully.")
else:
    print("Target not found in index.js")
