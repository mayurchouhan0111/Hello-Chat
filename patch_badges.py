import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\core\widgets\user_badge.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Height adjustment
target1 = '''    return Container(
      margin: margin ?? const EdgeInsets.only(right: 6),
      height: 38,
      constraints: const BoxConstraints(minWidth: 85),'''

repl1 = '''    return Container(
      margin: margin ?? const EdgeInsets.only(right: 6),
      height: (type == BadgeType.level) ? 22 : 38,
      constraints: const BoxConstraints(minWidth: 85),'''

if target1 in content:
    content = content.replace(target1, repl1)
else:
    print("target1 not found")

# 2. Icon removal for level frame
target2 = '''                  ] else if (icon != null) ...[
                    Icon(
                      icon, 
                      size: 10, 
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 1.5, offset: Offset(0, 0.5))],
                    ),
                    const SizedBox(width: 3),
                  ],'''

repl2 = '''                  ] else if (icon != null && type != BadgeType.level) ...[
                    Icon(
                      icon, 
                      size: 10, 
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 1.5, offset: Offset(0, 0.5))],
                    ),
                    const SizedBox(width: 3),
                  ],'''

if target2 in content:
    content = content.replace(target2, repl2)
else:
    print("target2 not found")

# 3. Unified font (Cinzel for all)
target3 = '''                      style: (type == BadgeType.level) 
                        ? GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
                          )
                        : TextStyle(
                            color: Colors.white,
                            fontSize: baseFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
                          ),'''

repl3 = '''                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
                      ),'''

if target3 in content:
    content = content.replace(target3, repl3)
else:
    print("target3 not found")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("user_badge.dart patched")
