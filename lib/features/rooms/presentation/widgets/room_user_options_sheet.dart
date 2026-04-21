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
import 'package:hello_chat/core/services/profile_service.dart';
import '../widgets/gift_panel.dart';

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
        
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Main Content Container
            Container(
              padding: const EdgeInsets.only(top: 60),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // 1. Follow Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        currentUid == u.uid 
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: (currentUid == null || _isFollowingLoading) ? null : () async {
                              setState(() => _isFollowingLoading = true);
                              try {
                                await ref.read(profileServiceProvider).toggleFollow(currentUid, u.uid);
                              } finally {
                                if (mounted) setState(() => _isFollowingLoading = false);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isFollowing ? const Color(0xFFF3F4F6) : AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: _isFollowingLoading 
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black26),
                                  ),
                                )
                              : Text(
                                isFollowing ? "Following" : "+ Follow",
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w900, 
                                  color: isFollowing ? Colors.black45 : Colors.white
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(10),

                  // 2. User Info Section
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            u.displayName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                          ),
                          if (u.isBanned) ...[
                            const Gap(6),
                            const Icon(Icons.block_rounded, color: Colors.red, size: 18),
                          ] else if (u.svipLevel != null && u.svipLevel! > 0) ...[
                            const Gap(6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 18),
                          ],
                        ],
                      ),
                      const Gap(4),
                      Text("@${u.username}", style: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.bold)),
                      const Gap(12),
                      // ID & Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatItem(Icons.person_3_rounded, "ID:${u.helloId ?? '...' }"),
                          const Gap(16),
                          _buildStatItem(null, "${u.followerCount} followers"),
                          const Gap(16),
                          _buildStatItem(Icons.location_on_rounded, u.country.isEmpty ? "International" : u.country),
                        ],
                      ),
                    ],
                  ),

                  const Gap(16),

                  // 3. Primary Badges Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildImageBadge("https://i.ibb.co/vzV6Ynx/lvl.png", "Lv.${u.level}"),
                        if (u.vipTier != 'none') ...[
                          const Gap(8),
                          _buildImageBadge("https://i.ibb.co/r7v9tZ0/vip.png", u.vipTier.toUpperCase()),
                        ],
                        if (u.svipLevel != null && u.svipLevel! > 0) ...[
                          const Gap(8),
                          _buildImageBadge("https://i.ibb.co/r7v9tZ0/vip.png", "SVIP ${u.svipLevel}"),
                        ],
                        if (u.combatPoints > 0) ...[
                          const Gap(8),
                          _buildImageBadge("https://i.ibb.co/M9YXV9S/pk.png", "Combat Lvl"),
                        ],
                      ],
                    ),
                  ),

                  const Gap(16),

                  // 4. Achievement Badge Icons
                  if (u.badges.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: u.badges.map((badgeUrl) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[100],
                            backgroundImage: CachedNetworkImageProvider(badgeUrl),
                          ),
                        )).toList(),
                      ),
                    )
                  else
                    const Text("No achievement badges", style: TextStyle(color: Colors.black12, fontSize: 10, fontWeight: FontWeight.bold)),

                  const Gap(24),

                  // 5. Action Bar (Chat & Gifts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.black.withOpacity(0.08)),
                            ),
                            child: ElevatedButton(
                              onPressed: currentUid == null ? null : () {
                                Navigator.pop(context);
                                final cid = currentUid.compareTo(u.uid) < 0 ? '${currentUid}_${u.uid}' : '${u.uid}_$currentUid';
                                context.push(AppRoutes.chatDetail, extra: {'chatId': cid, 'otherUid': u.uid});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                  Gap(6),
                                  Text("Chat", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF8E54E9)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF8E54E9).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => GiftPanel(roomId: widget.roomId),
                                );
                              },
                              icon: const Icon(Icons.card_giftcard_rounded, size: 20, color: Colors.white),
                              label: const Text("Give gifts", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(32),
                  const Divider(height: 1, color: Color(0xFFF3F4F6), thickness: 1),

                  // 6. Admin Control Bar (Only show if target is NOT self)
                  if ((widget.isAdmin || widget.isHost) && u.uid != currentUid)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                  const Gap(10),
                ],
              ),
            ),

            // Top Overlapping Avatar
            Positioned(
              top: -60,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange, Colors.pink]),
                    shape: BoxShape.circle,
                  ),
                  child: AppAvatar(
                    radius: 54,
                    imageUrl: u.profilePhotoUrl,
                    frameUrl: u.profileFrame,
                    vipTier: u.vipTier,
                    showFrame: true,
                    frameMultiplier: 1.5,
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

  Widget _buildStatItem(IconData? icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 14, color: Colors.black26),
        if (icon != null) const Gap(4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black26, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildImageBadge(String url, String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CachedNetworkImage(imageUrl: url, height: 16, width: 16, errorWidget: (_, __, ___) => const Icon(Icons.workspace_premium, size: 14, color: Colors.pink)),
          const Gap(4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.pink)),
        ],
      ),
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
