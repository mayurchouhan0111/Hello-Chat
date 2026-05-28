import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import 'package:hello_chat/core/services/profile_service.dart';
import 'package:hello_chat/utils/level_utils.dart';
import '../widgets/gift_panel.dart';
import 'mixer_sheet.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

class RoomUserOptionsSheet extends ConsumerStatefulWidget {
  final Participant participant;
  final String roomId;
  final bool isHost;
  final bool isAdmin;

  const RoomUserOptionsSheet({
    super.key,
    required this.participant,
    required this.roomId,
    required this.isHost,
    required this.isAdmin,
  });

  @override
  ConsumerState<RoomUserOptionsSheet> createState() => _RoomUserOptionsSheetState();
}

class _RoomUserOptionsSheetState extends ConsumerState<RoomUserOptionsSheet> {
  bool _isFollowingLoading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(widget.participant.uid));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final followingAsync = ref.watch(followingStreamProvider(currentUid ?? ''));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final u = user as UserModel;
        final isFollowing = followingAsync.value?.contains(u.uid) ?? false;
        final badges = getBadgesForUser(u);
        
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Main Bottom Sheet Card
            Container(
              padding: EdgeInsets.only(top: 60, bottom: 16 + MediaQuery.of(context).padding.bottom),
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
                        Clipboard.setData(ClipboardData(text: u.helloId.toString()));
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
                  
                  const Gap(6),
                  
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
                  
                  const Gap(16),
                  
                  // Stats Row
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
                  
                  if (currentUid != u.uid) ...[
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
                  ],

                  // Singer Controls (Self)
                  if (currentUid == u.uid) ...[
                    const Gap(16),
                    const Divider(height: 1, color: Color(0xFFF3F4F6), thickness: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildControlBtn(
                            icon: Icons.tune_rounded,
                            label: "Mixing",
                            color: const Color(0xFF00E5FF),
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => const MixerSheet(),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Admin Control Bar (Optional)
                  if ((widget.isAdmin || widget.isHost) && u.uid != currentUid) ...[
                    const Gap(16),
                    const Divider(height: 1, color: Color(0xFFF3F4F6), thickness: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                            const Gap(16),
                            _buildControlBtn(
                              icon: widget.participant.isSinger ? Icons.music_note_rounded : Icons.music_off_rounded,
                              label: widget.participant.isSinger ? "Remove Singer" : "Set Singer",
                              color: widget.participant.isSinger ? const Color(0xFF00E5FF) : Colors.black54,
                              onTap: () async {
                                Navigator.pop(context);
                                await ref.read(roomServiceProvider).setSingerRole(widget.roomId, u.uid, !widget.participant.isSinger);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.participant.isSinger ? "Singer role removed." : "Singer role granted.")));
                              }
                            ),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.headphones_rounded, label: "Listen", onTap: () {}),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.lock_open_rounded, label: "Lock", onTap: () {}),
                            const Gap(16),
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
              top: -84,
              child: SizedBox(
                width: 176,
                height: 176,
                child: Center(
                  child: AppAvatar(
                    radius: 44,
                    imageUrl: u.profilePhotoUrl,
                    frameUrl: u.profileFrame,
                    vipTier: u.vipTier,
                    userLevel: u.level,
                    showFrame: true,
                    frameMultiplier: 2.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 400, child: Center(child: Text("Error fetching profile"))),
    );
  }

  String _formatNumber(int num) {
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
  }

  Widget _buildControlBtn({required IconData icon, required String label, Color color = Colors.black54, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const Gap(6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black38)),
        ],
      ),
    );
  }
}
