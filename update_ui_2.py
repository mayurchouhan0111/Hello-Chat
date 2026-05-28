import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\room_user_options_sheet.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update padding
content = content.replace('padding: const EdgeInsets.only(top: 70, bottom: 24),', 'padding: const EdgeInsets.only(top: 24, bottom: 24),')

# 2. Insert AppAvatar into the Column
avatar_code = '''
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
                  const Gap(16),
'''
# Find the start of Column children
col_start = '              child: Column(\n                mainAxisSize: MainAxisSize.min,\n                children: [\n'
content = content.replace(col_start, col_start + avatar_code)

# 3. Remove AppAvatar from Stack
stack_avatar = '''
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
'''
content = content.replace(stack_avatar, '')

# 4. Remove Beans, Diamonds, and Two Buttons Row
stats_row_start = '                  // Stats Row'
stats_row_end = '                  const Gap(32),'
start_idx = content.find(stats_row_start)
end_idx = content.find(stats_row_end)

if start_idx != -1 and end_idx != -1:
    new_stats_row = '''                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(_formatNumber(u.followerCount), "Fans"),
                        _buildStatColumn(_formatNumber(u.followingCount), "Following"),
                      ],
                    ),
                  ),
                  
'''
    content = content[:start_idx] + new_stats_row + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
