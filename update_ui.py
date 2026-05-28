import sys
import os

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\room_user_options_sheet.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_str = '        return Stack('
end_str = '      loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),'

start_idx = content.find(start_str)
end_idx = content.find(end_str)

new_stack_code = '''        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Main Bottom Sheet Card
            Container(
              padding: const EdgeInsets.only(top: 70, bottom: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 0, offset: Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Username & Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        u.displayName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                      const Gap(6),
                      // Verified/Teal icon
                      if (u.isVerified) ...[
                        const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 18),
                        const Gap(4),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 10),
                        ),
                        const Gap(4),
                      ],
                      // Gender
                      if (u.gender.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: u.gender.toLowerCase() == 'male' ? Colors.blue : Colors.pinkAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            u.gender.toLowerCase() == 'male' ? Icons.male_rounded : Icons.female_rounded,
                            color: Colors.white, size: 10,
                          ),
                        ),
                    ],
                  ),
                  const Gap(6),
                  
                  // User ID
                  GestureDetector(
                    onTap: () {
                      if (u.helloId != null) {
                        import('package:flutter/services.dart').Clipboard.setData(import('package:flutter/services.dart').ClipboardData(text: u.helloId.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("ID ${u.helloId} copied"), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                    child: Text(
                      "ID:${u.helloId ?? '...'}", 
                      style: const TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.w600)
                    ),
                  ),
                  
                  const Gap(12),
                  
                  // Badges Row
                  if (badges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: badges.take(3).map((badge) {
                          if (badge is UserBadge) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: UserBadge(
                                label: badge.label, type: badge.type, icon: badge.icon, margin: EdgeInsets.zero, customFrameAsset: badge.customFrameAsset,
                              ),
                            );
                          }
                          return badge;
                        }).toList(),
                      ),
                    ),
                  
                  const Gap(24),
                  
                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(_formatNumber(u.followerCount), "Fans"),
                        _buildStatColumn(_formatNumber(u.followingCount), "Following"),
                        _buildStatColumn(_formatNumber(u.beansBalance), "Beans"),
                        _buildStatColumn(_formatNumber(u.diamondBalance), "Diamonds"),
                      ],
                    ),
                  ),
                  
                  const Gap(24),
                  
                  // Two Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.diamond_rounded, color: Colors.grey, size: 16),
                            const Gap(4),
                            Text("Lv. ${u.level}", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFFD54F)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: Colors.black87, size: 16),
                            const Gap(4),
                            const Text("GOLDEN S...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                            const Gap(4),
                            const Icon(Icons.star_rounded, color: Colors.white70, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Gap(32),
                  
                  // Bottom Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Follow Button
                        if (currentUid != u.uid)
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: (currentUid == null || _isFollowingLoading) ? null : () async {
                                setState(() => _isFollowingLoading = true);
                                try {
                                  await ref.read(profileServiceProvider).toggleFollow(currentUid, u.uid);
                                } finally {
                                  if (mounted) setState(() => _isFollowingLoading = false);
                                }
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isFollowing ? Colors.grey.shade300 : const Color(0xFF00E5FF),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: _isFollowingLoading 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      isFollowing ? "Following" : "+ Follow",
                                      style: TextStyle(color: isFollowing ? Colors.black54 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                              ),
                            ),
                          )
                        else
                          const Spacer(flex: 3),
                        
                        const Gap(12),
                        
                        // Gift Button
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => GiftPanel(roomId: widget.roomId),
                            );
                          },
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        
                        const Gap(12),
                        
                        // Chat Button
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: currentUid == null ? null : () {
                                Navigator.pop(context);
                                final cid = currentUid.compareTo(u.uid) < 0 ? '${currentUid}_${u.uid}' : '${u.uid}_${currentUid}';
                                context.push(AppRoutes.chatDetail, extra: {'chatId': cid, 'otherUid': u.uid});
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black12),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, color: Colors.black54, size: 18),
                                  Gap(6),
                                  Text("Chat", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Admin Control Bar (Optional)
                  if ((widget.isAdmin || widget.isHost) && u.uid != currentUid) ...[
                    const Gap(24),
                    const Divider(height: 1, color: Color(0xFFF3F4F6), thickness: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildControlBtn(
                            icon: widget.participant.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            label: "Mute",
                            color: widget.participant.isMuted ? Colors.redAccent : Colors.black54,
                            onTap: () async {
                              await ref.read(roomServiceProvider).muteUser(widget.roomId, u.uid, !widget.participant.isMuted);
                            }
                          ),
                          _buildControlBtn(icon: Icons.headphones_rounded, label: "Listen", onTap: () {}),
                          _buildControlBtn(icon: Icons.lock_open_rounded, label: "Lock", onTap: () {}),
                          _buildControlBtn(
                            icon: Icons.logout_rounded, 
                            label: "Kick Out", 
                            color: Colors.black54,
                            onTap: () async {
                              Navigator.pop(context);
                              await ref.read(roomServiceProvider).kickUser(widget.roomId, u.uid);
                            }
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Corner Actions Icons
            // Top Left: REPORT
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {}, // TODO: Handle report
                child: const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Colors.black54, size: 20),
                    Gap(4),
                    Text("REPORT", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
            
            // Top Right: Gift Status
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
          ],
        );
'''

new_content = content[:start_idx] + new_stack_code + content[end_idx:]

old_stat = '''  Widget _buildSimpleStat(String text) {
    return Text(
      text, 
      style: const TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.bold)
    );
  }'''

new_stat = '''  String _formatNumber(int num) {
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}k';
    }
    return num.toString();
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
        const Gap(4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.bold)),
      ],
    );
  }'''

new_content = new_content.replace(old_stat, new_stat)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
