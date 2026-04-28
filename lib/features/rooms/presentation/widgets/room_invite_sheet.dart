import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/room_provider.dart';

class RoomInviteSheet extends ConsumerWidget {
  final String roomId;
  const RoomInviteSheet({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAuthUser = ref.watch(authStateProvider).value;
    if (currentAuthUser == null) return const SizedBox.shrink();

    // Fetch following to invite them
    final followingAsync = ref.watch(followingStreamProvider(currentAuthUser.uid));

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Gap(12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Gap(16),
          const Text("Invite Supporters", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Gap(8),
          const Text("Invite your friends to support you!", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const Gap(16),
          Expanded(
            child: followingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
              data: (uids) {
                if (uids.isEmpty) {
                  return const Center(child: Text("No friends to invite", style: TextStyle(color: Colors.white38)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: uids.length,
                  itemBuilder: (context, index) => _InviteUserTile(uid: uids[index], roomId: roomId),
                );
              },
            ),
          ),
          const Gap(20),
        ],
      ),
    );
  }
}

class _InviteUserTile extends ConsumerStatefulWidget {
  final String uid;
  final String roomId;
  const _InviteUserTile({required this.uid, required this.roomId});

  @override
  ConsumerState<_InviteUserTile> createState() => _InviteUserTileState();
}

class _InviteUserTileState extends ConsumerState<_InviteUserTile> {
  bool _invited = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.uid));

    return profileAsync.when(
      loading: () => const SizedBox(height: 70),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final user = profile as UserModel;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: AppAvatar(imageUrl: user.profilePhotoUrl, radius: 24, showFrame: false),
          title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text("@${user.username}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: ElevatedButton(
            onPressed: _invited ? null : () async {
              setState(() => _invited = true);
              try {
                await ref.read(roomServiceProvider).sendRoomInvitation(
                  roomId: widget.roomId,
                  targetUid: widget.uid,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invitation sent to ${user.displayName}!")));
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _invited = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _invited ? Colors.white10 : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(_invited ? "Sent" : "Invite", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
