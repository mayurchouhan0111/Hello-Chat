import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\youtube_room_player.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''            // 🔊 Volume Control Button (Top Right, Owner only)
            if (_isOwner)
              Positioned(
                top: 12,
                right: 12,
                child: Row('''

replacement = '''            // 🔊 Volume Control Button (Center Right, Owner only)
            if (_isOwner)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row('''

target2 = '''                      ),
                    ),
                  ],
                ),
              ),

            // 🛑 Elegant Close Button'''

replacement2 = '''                      ),
                    ),
                  ],
                ),
                ),
              ),

            // 🛑 Elegant Close Button'''

if target in content and target2 in content:
    content = content.replace(target, replacement)
    content = content.replace(target2, replacement2)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done")
else:
    print("Target not found")
