import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\room_user_options_sheet.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update padding to 100
content = content.replace('padding: const EdgeInsets.only(top: 24, bottom: 24),', 'padding: const EdgeInsets.only(top: 100, bottom: 24),')

# 2. Remove AppAvatar from Column
avatar_in_col = '''
                  // Avatar
                  AppAvatar(
                    radius: 55,
                    imageUrl: u.profilePhotoUrl,
                    frameUrl: u.profileFrame,
                    vipTier: u.vipTier,
                    userLevel: u.level,
                    showFrame: true,
                    frameMultiplier: 1.6,
                  ),
                  const Gap(16),'''
content = content.replace(avatar_in_col, '')

# 3. Add AppAvatar to Stack
stack_end = '''            // Top Right: Gift Status
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: Colors.purpleAccent, size: 14),
                    Gap(4),
                    Text("0/12", style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold)),
                    Gap(2),
                    Icon(Icons.chevron_right_rounded, color: Colors.purple, size: 14),
                  ],
                ),
              ),
            ),
          ],'''

new_stack_end = '''            // Top Right: Gift Status
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: Colors.purpleAccent, size: 14),
                    Gap(4),
                    Text("0/12", style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold)),
                    Gap(2),
                    Icon(Icons.chevron_right_rounded, color: Colors.purple, size: 14),
                  ],
                ),
              ),
            ),
            
            // Centered Overlapping Avatar (Premium Frame)
            Positioned(
              top: -55,
              child: AppAvatar(
                radius: 55,
                imageUrl: u.profilePhotoUrl,
                frameUrl: u.profileFrame,
                vipTier: u.vipTier,
                userLevel: u.level,
                showFrame: true,
                frameMultiplier: 1.6,
              ),
            ),
          ],'''
content = content.replace(stack_end, new_stack_end)


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
