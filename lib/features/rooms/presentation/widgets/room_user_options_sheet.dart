import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/features/profile/presentation/screens/user_contribution_ranking_screen.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/services/report_service.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/user_profile_card.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import '../widgets/gift_panel.dart';
import 'mixer_sheet.dart';

class RoomUserOptionsSheet extends ConsumerStatefulWidget {
  final Participant participant;
  final String roomId;
  final bool isHost;
  final bool isAdmin;
  final bool isModerator;

  const RoomUserOptionsSheet({
    super.key,
    required this.participant,
    required this.roomId,
    required this.isHost,
    required this.isAdmin,
    this.isModerator = false,
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

    final fetchedUser = userAsync.valueOrNull;
    final u = fetchedUser ?? UserModel(
      uid: widget.participant.uid,
      createdAt: widget.participant.joinedAt,
      phoneNumber: null,
      username: widget.participant.displayName.isNotEmpty ? widget.participant.displayName : 'User',
      displayName: widget.participant.displayName.isNotEmpty ? widget.participant.displayName : 'User',
      profilePhotoUrl: widget.participant.profilePhotoUrl,
      profileFrame: widget.participant.profileFrame,
      vipTier: widget.participant.vipTier,
      level: widget.participant.level,
      tags: widget.participant.tags,
      badges: widget.participant.tags,
      helloId: widget.participant.helloId,
      lastActive: widget.participant.lastActive,
      role: widget.participant.role,
    );

    final isFollowing = followingAsync.value?.contains(u.uid) ?? false;
    final badges = getBadgesForUser(u);
    
    final svipLevel = _getSvipLevel(u);
    final vipLevel = _getVipLevel(u);
    final hasVipBg = svipLevel > 0 || vipLevel > 0;
    final textColor = hasVipBg ? Colors.white : Colors.black87;
    final subTextColor = hasVipBg ? Colors.white70 : Colors.black38;
    final iconColor = hasVipBg ? Colors.white70 : Colors.black54;
    
    return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Main Bottom Sheet Card (With transparent backdrop so SVGA wings spread behind avatar & actions)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: UserProfileCard(
                user: u,
                fit: BoxFit.fitWidth,
                crownTop: -48,
                crownBottom: 0,
                crownLeft: 0,
                crownRight: 0,
                showCrown: true,
                showStrip: false,
                backgroundColor: hasVipBg ? Colors.transparent : Colors.white,
                padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.of(context).padding.bottom),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: hasVipBg ? const [] : const [
                  BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 0, offset: Offset(0, -5)),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Gap(50), // Clearance inside card below top edge for floating avatar

                    // Username & Badges Row
                  Builder(
                    builder: (context) {
                      final roomData = ref.watch(currentRoomStreamProvider(widget.roomId)).value;
                      final isRoomOwner = roomData?.ownerUid == u.uid;
                      final isRoomAdmin = (roomData?.admins.contains(u.uid) ?? false) || widget.isAdmin;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              u.displayName,
                              style: TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.w900, 
                                color: textColor,
                                shadows: hasVipBg ? const [
                                  Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                                ] : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(6),
                          if (isRoomOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text(
                                "Owner",
                                style: TextStyle(color: Colors.black87, fontSize: 10.5, fontWeight: FontWeight.w900),
                              ),
                            )
                          else if (isRoomAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Color(0x6600E5FF), blurRadius: 6)],
                              ),
                              child: const Text(
                                "Admin",
                                style: TextStyle(color: Colors.black87, fontSize: 10.5, fontWeight: FontWeight.w900),
                              ),
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
                      );
                    },
                  ),
                  const Gap(4),
                  
                  // User ID (Tap opens profile page, long press copies ID)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.userProfile, extra: u.uid);
                    },
                    onLongPress: () {
                      if (u.helloId != null) {
                        Clipboard.setData(ClipboardData(text: u.helloId.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("ID ${u.helloId} copied"), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "ID:${u.helloId ?? '...'}", 
                          style: TextStyle(
                            color: subTextColor, 
                            fontSize: 12, 
                            fontWeight: FontWeight.w700,
                            shadows: hasVipBg ? const [
                              Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                            ] : null,
                          ),
                        ),
                        const Gap(2),
                        Icon(Icons.chevron_right_rounded, size: 14, color: subTextColor),
                      ],
                    ),
                  ),
                  
                  const Gap(4),
                  
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
                  
                  const Gap(10),
                  
                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(_formatNumber(u.followerCount), "Fans", textColor, subTextColor),
                        _buildStatColumn(_formatNumber(u.followingCount), "Following", textColor, subTextColor),
                      ],
                    ),
                  ),
                  
                  if (currentUid != u.uid) ...[
                    const Gap(10),
                    
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
                                  final cid = currentUid.compareTo(u.uid) < 0 ? '${currentUid}_${u.uid}' : '${u.uid}_$currentUid';
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
                            labelColor: subTextColor,
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
                  if ((widget.isAdmin || widget.isHost || widget.isModerator) && u.uid != currentUid) ...[
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
                              color: widget.participant.isMuted ? Colors.redAccent : iconColor,
                              labelColor: subTextColor,
                              onTap: () async {
                                final svipLevel = u.svipLevel ?? 0;
                                if (svipLevel >= 4 || u.isSvipProtected == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed."),
                                      backgroundColor: Colors.amber,
                                    ),
                                  );
                                  return;
                                }
                                await ref.read(roomServiceProvider).muteUser(widget.roomId, u.uid, !widget.participant.isMuted);
                              }
                            ),
                            const Gap(16),
                            _buildControlBtn(
                              icon: widget.participant.isSinger ? Icons.music_note_rounded : Icons.music_off_rounded,
                              label: widget.participant.isSinger ? "Remove Singer" : "Set Singer",
                              color: widget.participant.isSinger ? const Color(0xFF00E5FF) : iconColor,
                              labelColor: subTextColor,
                              onTap: () async {
                                Navigator.pop(context);
                                await ref.read(roomServiceProvider).setSingerRole(widget.roomId, u.uid, !widget.participant.isSinger);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.participant.isSinger ? "Singer role removed." : "Singer role granted.")));
                              }
                            ),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.headset_mic_rounded, label: "Invite to Call", color: iconColor, labelColor: subTextColor, onTap: () async {
                              Navigator.pop(context);
                              await ref.read(roomServiceProvider).inviteToAudioCall(widget.roomId, widget.participant.uid, type: 'invite');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Audio call invitation sent!"), behavior: SnackBarBehavior.floating),
                                );
                              }
                            }),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.call_made_rounded, label: "Bring to Call", color: iconColor, labelColor: subTextColor, onTap: () async {
                              Navigator.pop(context);
                              await ref.read(roomServiceProvider).inviteToAudioCall(widget.roomId, widget.participant.uid, type: 'bring');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Bring to call invitation sent!"), behavior: SnackBarBehavior.floating),
                                );
                              }
                            }),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.headphones_rounded, label: "Listen", color: iconColor, labelColor: subTextColor, onTap: () {}),
                            const Gap(16),
                            _buildControlBtn(icon: Icons.lock_open_rounded, label: "Lock", color: iconColor, labelColor: subTextColor, onTap: () {}),
                            const Gap(16),
                            _buildControlBtn(
                              icon: Icons.logout_rounded, 
                              label: "Kick Out", 
                              color: iconColor,
                              labelColor: subTextColor,
                              onTap: () async {
                                final svipLevel = u.svipLevel ?? 0;
                                final meDoc = await ref.read(currentUserProfileProvider.future);
                                final mySvipLevel = meDoc?.svipLevel ?? 0;

                                if (mySvipLevel == 6) {
                                  if (svipLevel == 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("SVIP 6 users cannot Kick Out another SVIP 6 user."),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                } else if (svipLevel >= 4 || u.isSvipProtected == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed."),
                                      backgroundColor: Colors.amber,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(context);
                                _showKickDialog(context, u.uid);
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
            ),

            // Floating Centered Avatar (floats halfway over the sheet top edge, matching reference images 2, 4, 7)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 104,
                height: 104,
                child: Center(
                  child: AppAvatar(
                    radius: 36,
                    imageUrl: u.profilePhotoUrl,
                    frameUrl: u.profileFrame,
                    vipTier: u.vipTier,
                    svipLevel: u.svipLevel,
                    userLevel: u.level,
                    showFrame: true,
                    frameMultiplier: 1.8,
                  ),
                ),
              ),
            ),

            // Corner Actions Icons
            // Top Left: REPORT
            Positioned(
              top: 54,
              left: 16,
              child: GestureDetector(
                onTap: () => _showReportDialog(context, u),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Colors.white70, size: 16),
                      Gap(4),
                      Text("REPORT", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
            
            // Top Right: Gift Status (Top Senders List)
            Positioned(
              top: 54,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserContributionRankingScreen(
                        targetUid: u.uid,
                        targetUserName: u.displayName,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasVipBg ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hasVipBg ? Colors.amber.withOpacity(0.5) : Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: hasVipBg ? Colors.amber : Colors.purpleAccent, size: 14),
                      const Gap(4),
                      Text("Top List", style: TextStyle(color: hasVipBg ? Colors.amber : Colors.purple, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Gap(2),
                      Icon(Icons.chevron_right_rounded, color: hasVipBg ? Colors.amber : Colors.purple, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
  }

  void _showKickDialog(BuildContext context, String targetUid) {
    int selectedDuration = 0;
    final reasonController = TextEditingController();
    final durations = [
      (0, 'Permanent'),
      (5, '5 min'),
      (15, '15 min'),
      (30, '30 min'),
      (60, '1 hour'),
      (360, '6 hours'),
      (1440, '24 hours'),
      (10080, '7 days'),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kick User', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ban Duration:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: durations.map((d) {
                    final (mins, label) = d;
                    final isSelected = selectedDuration == mins;
                    return ChoiceChip(
                      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: Colors.red,
                      onSelected: (val) => setDialogState(() => selectedDuration = mins),
                    );
                  }).toList(),
                ),
                const Gap(16),
                const Text('Reason (optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Gap(8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Spam, Harassment...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref.read(roomServiceProvider).kickUser(
                    widget.roomId, targetUid,
                    durationMinutes: selectedDuration > 0 ? selectedDuration : null,
                    reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception:', '').replaceAll('FirebaseFunctionsException:', '').trim()),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kick', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(2)}k';
    }
    return num.toString();
  }

  Widget _buildStatColumn(String value, String label, Color textColor, Color subTextColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
        const Gap(4),
        Text(label, style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    Color color = Colors.black54,
    Color labelColor = Colors.black38,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const Gap(6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: labelColor)),
        ],
      ),
    );
  }

  int _getSvipLevel(UserModel user) {
    if (user.svipLevel != null && user.svipLevel! > 0) return user.svipLevel!;
    for (final tag in user.tags) {
      final clean = tag.toLowerCase().replaceAll(' ', '');
      if (clean.startsWith('svip')) {
        final val = int.tryParse(clean.substring(4));
        if (val != null && val > 0) return val;
      }
    }
    for (final badge in user.badges) {
      final clean = badge.toLowerCase().replaceAll(' ', '');
      if (clean.startsWith('svip')) {
        final val = int.tryParse(clean.substring(4));
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  int _getVipLevel(UserModel user) {
    final clean = user.vipTier.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final val = int.tryParse(clean.substring(3));
      if (val != null && val > 0) return val;
    }
    for (final tag in user.tags) {
      final cleanTag = tag.toLowerCase().replaceAll(' ', '');
      if (cleanTag.startsWith('vip') && !cleanTag.startsWith('svip')) {
        final val = int.tryParse(cleanTag.substring(3));
        if (val != null && val > 0) return val;
      }
    }
    for (final badge in user.badges) {
      final cleanBadge = badge.toLowerCase().replaceAll(' ', '');
      if (cleanBadge.startsWith('vip') && !cleanBadge.startsWith('svip')) {
        final val = int.tryParse(cleanBadge.substring(3));
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  void _showReportDialog(BuildContext context, UserModel targetUser) {
    final reasons = ["Harassment", "Spam", "Nudity / Inappropriate", "Hate Speech", "Fake Account"];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Report ${targetUser.displayName}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              "Select a reason for reporting this user",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: reasons.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(
                  title: Text(
                    reasons[i],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(reportServiceProvider).submitReport(
                        targetUid: targetUser.uid,
                        reason: reasons[i],
                      );
                      if (context.mounted) {
                        AppToast.showSuccess(context, "Thanks for reporting! Our team will review this user.");
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.showError(context, "Report failed: $e");
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
