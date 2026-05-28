import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\room_user_options_sheet.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update container padding bottom
content = content.replace('padding: const EdgeInsets.only(top: 60, bottom: 24),', 'padding: const EdgeInsets.only(top: 60, bottom: 16),')

# 2. Reduce Gap under User ID
# It's currently Gap(12) below the GestureDetector for User ID.
# Let's target the exact string blocks to be safe.
id_gap = '''                    ),
                  ),
                  
                  const Gap(12),
                  
                  // Badges Row'''
new_id_gap = id_gap.replace('Gap(12)', 'Gap(6)')
content = content.replace(id_gap, new_id_gap)

# 3. Reduce Gap under Badges
badges_gap = '''                      ),
                    ),
                  
                  const Gap(24),
                  
                  // Stats Row'''
new_badges_gap = badges_gap.replace('Gap(24)', 'Gap(16)')
content = content.replace(badges_gap, new_badges_gap)

# 4. Reduce Gap under Stats Row
stats_gap = '''                    ),
                  ),
                  
                  const Gap(32),
                  
                  // Bottom Action Bar'''
new_stats_gap = stats_gap.replace('Gap(32)', 'Gap(16)')
content = content.replace(stats_gap, new_stats_gap)

# 5. Reduce Gap under Bottom Action Bar (if admin)
admin_gap = '''                      ],
                    ),
                  ),

                  // Admin Control Bar (Optional)
                  if ((widget.isAdmin || widget.isHost) && u.uid != currentUid) ...[
                    const Gap(24),
                    const Divider(height: 1, color: Color(0xFFF3F4F6), thickness: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),'''
new_admin_gap = admin_gap.replace('Gap(24)', 'Gap(16)').replace('vertical: 20', 'vertical: 12')
content = content.replace(admin_gap, new_admin_gap)


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
