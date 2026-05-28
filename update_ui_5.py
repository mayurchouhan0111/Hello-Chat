import sys

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\rooms\presentation\widgets\room_user_options_sheet.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                  const Gap(16),
                  
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
                              builder: (context) => GiftPanel(roomId: widget.roomId, targetUid: u.uid),
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
                  ),'''

replacement = '''                  if (currentUid != u.uid) ...[
                    const Gap(16),
                    
                    // Bottom Action Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Follow Button
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
                          ),
                          
                          const Gap(12),
                          
                          // Gift Button
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => GiftPanel(roomId: widget.roomId, targetUid: u.uid),
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
                  ],'''

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Done')
else:
    print('Target not found')
