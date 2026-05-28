import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\functions\index.js'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add lastLevelUp to the first onUserUpdate
target1 = '''    // 2. ID Level (XP based)
    const oldXP = before.xp || 0;
    const newXP = after.xp || 0;
    if (newXP !== oldXP) {
        const nextLevel = calculateIDLevel(newXP);
        if (nextLevel !== (after.level || 1)) {
            updates.level = nextLevel;
        }
    }'''

repl1 = '''    // 2. ID Level (XP based)
    const oldXP = before.xp || 0;
    const newXP = after.xp || 0;
    if (newXP !== oldXP) {
        const nextLevel = calculateIDLevel(newXP);
        if (nextLevel !== (after.level || 1)) {
            updates.level = nextLevel;
            updates.lastLevelUp = admin.firestore.FieldValue.serverTimestamp();
        }
    }'''

if target1 in content:
    content = content.replace(target1, repl1)
else:
    print("Target 1 (first onUserUpdate) not found.")

# 2. Delete the second onUserUpdate completely
target2 = '''/**
 * 400. Universal Leveling Engine
 * Automatically calculates and updates User Level based on XP gain.
 * Logic: Every 1,000 XP earned = +1 Level.
 */
exports.onUserUpdate = functions.firestore.document("users/{uid}").onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();

    // Only run logic if XP has increased
    if ((after.xp || 0) <= (before.xp || 0)) return null;

    const currentXP = after.xp || 0;
    const currentLevel = after.level || 1;

    // Formula: Level starts at 1, gains +1 for every 1000 XP
    const calculatedLevel = Math.floor(currentXP / 1000) + 1;

    // Trigger update only if a new level is reached
    if (calculatedLevel > currentLevel) {
        console.log(`[LEVEL_UP] User:${context.params.uid} New Level:${calculatedLevel}`);

        return change.after.ref.update({
            level: calculatedLevel,
            lastLevelUp: admin.firestore.FieldValue.serverTimestamp()
        });
    }

    return null;
});'''

# Use regex for robust replacement just in case
import re
# We'll just replace it with empty string
if target2 in content:
    content = content.replace(target2, '')
    print("Target 2 (second onUserUpdate) replaced successfully.")
else:
    print("Target 2 (second onUserUpdate) not found exactly as string. Trying regex...")
    # fallback to regex
    pattern = re.compile(r'/\*\*[\s\*]*400\. Universal Leveling Engine.*?\*/[\s]*exports\.onUserUpdate = functions\.firestore\.document\("users/\{uid\}"\)\.onUpdate\(async \(change, context\) => \{.*?\n\}\);\n', re.DOTALL)
    content, count = pattern.subn('', content)
    if count > 0:
        print("Target 2 (second onUserUpdate) removed via regex.")
    else:
        print("Target 2 (second onUserUpdate) NOT FOUND via regex either!")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
