import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hello_chat/services/room_service.dart';
import 'package:hello_chat/core/providers/pk_mode_provider.dart';

class PKMatchingBottomSheet extends ConsumerStatefulWidget {
  final String roomId;
  const PKMatchingBottomSheet({super.key, required this.roomId});

  @override
  ConsumerState<PKMatchingBottomSheet> createState() => _PKMatchingBottomSheetState();
}

class _PKMatchingBottomSheetState extends ConsumerState<PKMatchingBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Removed local mode state; using Riverpod provider instead

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // 📡 Diagnostic: Test connection and compare Project IDs on open
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
      return const Center(child: CircularProgressIndicator(color: Colors.indigo));
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF09090B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            _buildHeader(),
            _buildPKModeSelector(),
            _buildModeOptions(),
            _buildRandomPKRestricted(),
            _buildTabs(),
            
            // === CRITICAL PART: This fixes all layout errors ===
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildInRoomList(),
                    _buildFollowingList(currentUid),
                    _buildFriendsList(currentUid),
                    _buildFamilyRoomsList(),
                  ],
                ),
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
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Match", style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, fontWeight: FontWeight.bold)),
            const Text("Multi-live PK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF71717A), size: 20),
                  constraints: const BoxConstraints(),
                ),
                const Gap(12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF71717A), size: 24),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildPKModeSelector() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _modeButton("ROOM PK", isFirst: true),
            const Gap(12),
            _modeButton("Guest Arena", isComingSoon: true),
            const Gap(12),
            _modeButton("Team PK", isComingSoon: true),
          ],
        ),
      );

  Widget _modeButton(String label, {bool isFirst = false, bool isComingSoon = false}) {
    final selectedMode = ref.watch(pkModeProvider); // Riverpod state
    final isSelected = selectedMode == label && !isComingSoon;
    return Expanded(
      child: GestureDetector(
        onTap: isComingSoon ? null : () => ref.read(pkModeProvider.notifier).state = label,
        child: Opacity(
          opacity: isComingSoon ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo.withOpacity(0.1) : const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.indigo : const Color(0xFF27272A),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isFirst ? Icons.emoji_people_rounded : (isComingSoon ? Icons.lock_outline : Icons.groups_rounded),
                  color: isSelected ? Colors.indigo : const Color(0xFF71717A),
                  size: 28,
                ),
                const Gap(8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOptions() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _optionChip("Shared Screen", true),
            const Gap(12),
            _optionChip("Split Screen", false),
          ],
        ),
      );

  Widget _optionChip(String label, bool isSelected) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27272A) : const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Colors.indigo) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF71717A),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

  Widget _buildRandomPKRestricted() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.radar_rounded, color: Color(0xFF27272A)),
            const Gap(12),
            const Expanded(
              child: Text(
                "Random PK (Restricted)",
                style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Text("Disabled",
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  Widget _buildTabs() => TabBar(
        controller: _tabController,
        indicatorColor: Colors.indigo,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF71717A),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "In Room"),
          Tab(text: "Following"),
          Tab(text: "Friends"),
          Tab(text: "Family Room"),
        ],
      );

  // Tab Contents
  Widget _buildInRoomList() {
    final participantsAsync = ref.watch(roomParticipantsProvider(widget.roomId));
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return participantsAsync.when(
      data: (pts) {
        // Exclude current user and filter for speakers if possible, or just anyone but me
        final otherParticipants = pts.where((p) => p.uid != currentUid).toList();
        
        if (otherParticipants.isEmpty) {
          return _buildEmptyState("You are the only one in the room.");
        }

        return _buildUserList(otherParticipants.map((p) => p.uid).toList(), widget.roomId);
      },
      loading: () => _buildLoadingState(),
      error: (e, __) => _buildErrorState("Error: $e"),
    );
  }

  Widget _buildFollowingList(String currentUid) {
    final followingAsync = ref.watch(followingStreamProvider(currentUid));
    return followingAsync.when(
      data: (uids) => uids.isEmpty
          ? _buildEmptyState("No following found.")
          : _buildUserList(uids.where((id) => id.isNotEmpty).toList(), widget.roomId),
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error loading following"),
    );
  }

  Widget _buildFriendsList(String currentUid) {
    final friendsAsync = ref.watch(friendsStreamProvider(currentUid));
    return friendsAsync.when(
      data: (uids) => uids.isEmpty
          ? _buildEmptyState("No mutual friends available.")
          : _buildUserList(uids, widget.roomId),
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error loading friends"),
    );
  }

  Widget _buildFamilyRoomsList() {
    final userAsync = ref.watch(currentUserProfileProvider);
    return userAsync.when(
      data: (user) {
        if (user?.familyId?.isEmpty ?? true) {
          return _buildEmptyState("Join a family to see family rooms.");
        }
        final roomsAsync = ref.watch(familyRoomsProvider(user!.familyId!));
        return roomsAsync.when(
          data: (rooms) {
            final otherRooms = rooms.where((r) => r['roomId'] != widget.roomId).toList();
            return otherRooms.isEmpty
                ? _buildEmptyState("No active family rooms.")
                : _buildRoomList(otherRooms);
          },
          loading: () => _buildLoadingState(),
          error: (_, __) => _buildErrorState("Error loading family rooms"),
        );
      },
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildErrorState("Error fetching profile"),
    );
  }

  Widget _buildUserList(List<String> uids, String roomId) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: uids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _OpponentTile(uid: uids[index], roomId: roomId),
    );
  }

  Widget _buildRoomList(List<Map<String, dynamic>> rooms) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _RoomTile(roomData: rooms[index], currentRoomId: widget.roomId),
    );
  }

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator(color: Colors.indigo));

  Widget _buildErrorState(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.white)));

  Widget _buildEmptyState(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF18181B)),
            const Gap(12),
            Text(message, style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
          ],
        ),
      );
}

// ====================== TILES ======================

class _OpponentTile extends ConsumerWidget {
  final String uid;
  final String roomId;

  const _OpponentTile({super.key, required this.uid, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final u = user as UserModel;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: u.profilePhotoUrl.isNotEmpty ? CachedNetworkImageProvider(u.profilePhotoUrl) : null,
                child: u.profilePhotoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("@${u.username}", style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _handleStartPK(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(60, 40),
                ),
                child: const Text("PK"),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PK Challenge sent!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

class _RoomTile extends ConsumerWidget {
  final Map<String, dynamic> roomData;
  final String currentRoomId;

  const _RoomTile({super.key, required this.roomData, required this.currentRoomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerUid = (roomData['ownerUid'] as String?) ?? '';
    final roomName = (roomData['name'] as String?) ?? 'Room';
    final coverUrl = (roomData['coverUrl'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.indigo.withOpacity(0.2),
              image: coverUrl.isNotEmpty
                  ? DecorationImage(image: CachedNetworkImageProvider(coverUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: coverUrl.isEmpty
                ? const Icon(Icons.meeting_room_rounded, color: Colors.indigo, size: 20)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Host: ${ownerUid.isNotEmpty ? ownerUid.substring(0, 8) : 'N/A'}...",
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleStartPK(context, ref, ownerUid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(60, 40),
            ),
            child: const Text("PK"),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PK Challenge sent!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}