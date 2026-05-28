import sys
import re

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\core\widgets\app_avatar.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Modify AppAvatar to have a frame offset and better default multiplier
target1 = '''  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.frameUrl,
    this.badgeUrl,
    this.tags,
    this.vipTier,
    this.userLevel,
    this.radius = 20.0,
    this.showFrame = true,
    this.frameMultiplier = 1.75,
  });'''

repl1 = '''  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.frameUrl,
    this.badgeUrl,
    this.tags,
    this.vipTier,
    this.userLevel,
    this.radius = 20.0,
    this.showFrame = true,
    this.frameMultiplier = 1.35, // Reduced for better fit
  });'''

if target1 in content:
    content = content.replace(target1, repl1)
else:
    print("target1 not found")

target2 = '''        // 2. The VIP Frame Layer (Foreground Layer - Overlay)
        if (showFrame && finalFrameUrl.isNotEmpty)
          IgnorePointer(
            child: SizedBox(
              width: frameSize,
              height: frameSize,'''

repl2 = '''        // 2. The VIP Frame Layer (Foreground Layer - Overlay)
        if (showFrame && finalFrameUrl.isNotEmpty)
          IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, -radius * 0.15), // Shift frame up to center the hole
              child: SizedBox(
                width: frameSize,
                height: frameSize,'''

target3 = '''              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 2.seconds),
            ),'''
            
repl3 = '''              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 2.seconds),
              ),
            ),'''

if target2 in content and target3 in content:
    content = content.replace(target2, repl2).replace(target3, repl3)
else:
    print("target2 or target3 not found")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
    
print("AppAvatar patched.")
