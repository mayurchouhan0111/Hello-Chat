import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hello_chat/core/providers/pk_mode_provider.dart';

class PKMatchingBottomSheet extends ConsumerStatefulWidget {
  final String roomId;
  final bool isEmbedded;

  const PKMatchingBottomSheet({
    super.key,
    required this.roomId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<PKMatchingBottomSheet> createState() => _PKMatchingBottomSheetState();
}

class _PKMatchingBottomSheetState extends ConsumerState<PKMatchingBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // 📡 Test connection and compare Project IDs on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomServiceProvider).testConnection();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUid = authState.value?.uid;

    if (currentUid == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    final room = ref.watch(currentRoomStreamProvider(widget.roomId)).value;
    final isHost = room != null && (room.ownerUid == currentUid || (room.admins.contains(currentUid)));

    return Material(
      color: Colors.transparent,
      child: Container(
        height: widget.isEmbedded ? null : MediaQuery.of(context).size.height * 0.75,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.isEmbedded ? Colors.transparent : const Color(0xFF0F111E),
          borderRadius: widget.isEmbedded ? null : const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            if (!widget.isEmbedded) ...[
              _buildDragHandle(),
              _buildHeader(),
            ],
            
            // Host vs Viewer Role Indicator Banner
            if (!isHost)
              _buildViewerRestrictedBanner()
            else
              _buildHostActiveBanner(),

            _buildPKModeSelector(isHost),
            _buildModeOptions(isHost),
            _buildTabs(),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildInRoomList(isHost),
                  _buildFollowingList(currentUid, isHost),
                  _buildFriendsList(currentUid, isHost),
                  _buildFamilyRoomsList(isHost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "MATCHING",
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const Text(
              "Multi-Live PK",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _buildViewerRestrictedBanner() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 18),
            Gap(10),
            Expanded(
              child: Text(
                "Host Controls Active: Only the Room Host can initiate and configure PK battles.",
                style: TextStyle(color: Color(0xFFFCD34D), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Widget _buildHostActiveBanner() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 18),
            Gap(10),
            Expanded(
              child: Text(
                "Host Permissions Verified: Select an opponent below to start a PK match.",
                style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

  Widget _buildPKModeSelector(bool isHost) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _modeButton("ROOM PK", isFirst: true, isHost: isHost),
            const Gap(10),
            _modeButton("Guest Arena", isComingSoon: true, isHost: isHost),
            const Gap(10),
            _modeButton("Team PK", isComingSoon: true, isHost: isHost),
          ],
        ),
      );

  Widget _modeButton(String label, {bool isFirst = false, bool isComingSoon = false, required bool isHost}) {
    final selectedMode = ref.watch(pkModeProvider);
    final isSelected = selectedMode == label && !isComingSoon;

    return Expanded(
      child: GestureDetector(
        onTap: (isComingSoon || !isHost)
            ? null
            : () => ref.read(pkModeProvider.notifier).state = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                : const Color(0xFF161928),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                isFirst
                    ? Icons.emoji_people_rounded
                    : (isComingSoon ? Icons.lock_outline_rounded : Icons.groups_rounded),
                color: isSelected ? const Color(0xFF818CF8) : Colors.white54,
                size: 24,
              ),
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOptions(bool isHost) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _optionChip("Shared Screen", true),
            const Gap(10),
            _optionChip("Split Screen", false),
          ],
        ),
      );

  Widget _optionChip(String label, bool isSelected) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF24283D) : const Color(0xFF161928),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

  Widget _buildTabs() => TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF6366F1),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        dividerColor: Colors.white10,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: "In Room"),
          Tab(text: "Following"),
          Tab(text: "Friends"),
          Tab(text: "Family"),
        ],
      );

  Widget _buildInRoomList(bool isHost) {
    final participantsAsync = ref.watch(roomParticipantsProvider(widget.roomId));
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return participantsAsync.when(
      data: (pts) {
        final otherParticipants = pts.where((p) => p.uid != currentUid).toList();
        if (otherParticipants.isEmpty) {
          return _buildEmptyState("You are the only one in the room.");
        }
        return _buildUserList(otherParticipants.map((p) => p.uid).toList(), widget.roomId, isHost);
      },
      loading: () => _buildLoadingState(),
      error: (e, __) => _buildErrorState("Error: $e"),
    );
  }

  Widget _buildFollowingList(String currentUid, bool isHost) {
    final followingAsync = ref.watch(followingStreamProvider(currentUid));
    return followingAsync.when(
      data: (uids) => uids.isEmpty
          ? _buildEmptyState("No following users currently online.")
          : _buildUserList(uids.where((id) => id.isNotEmpty).toList(), widget.roomId, isHost),
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error loading following"),
    );
  }

  Widget _buildFriendsList(String currentUid, bool isHost) {
    final friendsAsync = ref.watch(friendsStreamProvider(currentUid));
    return friendsAsync.when(
      data: (uids) => uids.isEmpty
          ? _buildEmptyState("No mutual friends available.")
          : _buildUserList(uids, widget.roomId, isHost),
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error loading friends"),
    );
  }

  Widget _buildFamilyRoomsList(bool isHost) {
    final userAsync = ref.watch(currentUserProfileProvider);
    return userAsync.when(
      data: (user) {
        if (user?.familyId?.isEmpty ?? true) {
          return _buildEmptyState("Join a family to challenge other family rooms.");
        }
        final roomsAsync = ref.watch(familyRoomsProvider(user!.familyId!));
        return roomsAsync.when(
          data: (rooms) {
            final otherRooms = rooms.where((r) => r['roomId'] != widget.roomId).toList();
            return otherRooms.isEmpty
                ? _buildEmptyState("No active family rooms found.")
                : _buildRoomList(otherRooms, isHost);
          },
          loading: () => _buildLoadingState(),
          error: (_, __) => _buildErrorState("Error loading family rooms"),
        );
      },
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error fetching profile"),
    );
  }

  Widget _buildUserList(List<String> uids, String roomId, bool isHost) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: uids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _OpponentTile(uid: uids[index], roomId: roomId, isHost: isHost),
    );
  }

  Widget _buildRoomList(List<Map<String, dynamic>> rooms, bool isHost) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _RoomTile(roomData: rooms[index], currentRoomId: widget.roomId, isHost: isHost),
    );
  }

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));

  Widget _buildErrorState(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.white70)));

  Widget _buildEmptyState(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 44, color: Colors.white.withValues(alpha: 0.15)),
            const Gap(10),
            Text(message, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
}

// ====================== TILES ======================

class _OpponentTile extends ConsumerWidget {
  final String uid;
  final String roomId;
  final bool isHost;

  const _OpponentTile({
    required this.uid,
    required this.roomId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final u = user as UserModel;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141726),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: u.profilePhotoUrl.isNotEmpty ? CachedNetworkImageProvider(u.profilePhotoUrl) : null,
                child: u.profilePhotoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "@${u.username}",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isHost)
                ElevatedButton(
                  onPressed: () => _handleStartPK(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                  ),
                  child: const Text("PK", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white38),
                      Gap(4),
                      Text("Host Only", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _handleStartPK(BuildContext context, WidgetRef ref) async {
    final currentUid = ref.read(authStateProvider).value?.uid;
    if (currentUid == null) return;
    try {
      await ref.read(roomServiceProvider).invitePKChallenge(
        roomId: roomId,
        targetUid: uid,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Text("PK Challenge sent!"),
            backgroundColor: Color(0xFF6366F1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Error starting PK: $e")),
        );
      }
    }
  }
}

class _RoomTile extends ConsumerWidget {
  final Map<String, dynamic> roomData;
  final String currentRoomId;
  final bool isHost;

  const _RoomTile({
    required this.roomData,
    required this.currentRoomId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerUid = (roomData['ownerUid'] as String?) ?? '';
    final roomName = (roomData['name'] as String?) ?? 'Room';
    final coverUrl = (roomData['coverUrl'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              image: coverUrl.isNotEmpty
                  ? DecorationImage(image: CachedNetworkImageProvider(coverUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: coverUrl.isEmpty
                ? const Icon(Icons.meeting_room_rounded, color: Color(0xFF818CF8), size: 20)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Host: ${ownerUid.isNotEmpty ? ownerUid.substring(0, 8) : 'N/A'}...",
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isHost)
            ElevatedButton(
              onPressed: () => _handleStartPK(context, ref, ownerUid),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
              ),
              child: const Text("PK", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white38),
                  Gap(4),
                  Text("Host Only", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleStartPK(BuildContext context, WidgetRef ref, String targetUid) async {
    if (targetUid.isEmpty) return;
    final currentUid = ref.read(authStateProvider).value?.uid;
    if (currentUid == null) return;

    try {
      await ref.read(roomServiceProvider).invitePKChallenge(
        roomId: currentRoomId,
        targetUid: targetUid,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Text("PK Challenge sent!"),
            backgroundColor: Color(0xFF6366F1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Error starting PK: $e")),
        );
      }
    }
  }
}
