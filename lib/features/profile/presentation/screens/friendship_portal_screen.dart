import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/relationship_model.dart';
import '../../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/relationship_service.dart';

class FriendshipPortalScreen extends ConsumerStatefulWidget {
  const FriendshipPortalScreen({super.key});

  @override
  ConsumerState<FriendshipPortalScreen> createState() => _FriendshipPortalScreenState();
}

class _FriendshipPortalScreenState extends ConsumerState<FriendshipPortalScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: profileAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          
            final friendshipsAsync = ref.watch(userFriendshipsProvider(user.uid));
            return friendshipsAsync.when(
              data: (friendships) {
                final activeFriendships = friendships
                    .where((f) => f.isActive && f.isFriendship)
                    .toList();
                
                if (activeFriendships.isEmpty) {
                  return _buildNoFriendsState(user);
                }
                
                // For now, show the first/best friendship (highest intimacy)
                final bestFriendship = activeFriendships.reduce(
                  (a, b) => a.intimacy > b.intimacy ? a : b,
                );
                
                return _buildPortalContent(user, activeFriendships);
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
              error: (e, __) => _buildErrorState(e.toString()),
            );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
        error: (e, __) => _buildErrorState(e.toString()),
      ),
    );
  }

    Widget _buildPortalContent(UserModel user, List<RelationshipModel> friendships) {
    // Background and particle effects stay the same
    return Stack(
      children: [
        _buildBackground(),
        ..._buildFloatingParticles(),
        _buildGradientOverlay(),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: friendships.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) {
                    final friendship = friendships[index];
                    return _buildFriendCard(user, friendship);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(UserModel user, RelationshipModel friendship) {
    final otherUid = friendship.participants.firstWhere((id) => id != user.uid);
    final otherUserAsync = ref.watch(userProfileProvider(otherUid));

    return otherUserAsync.when(
      data: (friend) {
        if (friend == null) return const SizedBox();
        final isBestFriend = friendship.level >= 4;
        return Card(
          color: Colors.white.withOpacity(0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(friend.profilePhotoUrl),
            ),
            title: Text(friend.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Level ${friendship.level} • ${friendship.intimacy} XP', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              onPressed: () => _showRemoveFriendDialog(friend, friendship),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=1000&q=80",
        fit: BoxFit.cover,
        errorWidget: (c, e, s) => Container(color: const Color(0xFF1A1A2E)),
      ),
    );
  }

  List<Widget> _buildFloatingParticles() {
    return List.generate(6, (i) => Positioned(
      left: (i * 60).toDouble() + 10,
      bottom: -40,
      child: Icon(
        i % 3 == 0 ? Icons.stars_rounded : (i % 3 == 1 ? Icons.emoji_events_rounded : Icons.favorite_border_rounded),
        color: Colors.white.withOpacity(0.3),
        size: (10 + i % 5).toDouble(),
      ).animate(onPlay: (c) => c.repeat())
        .moveY(begin: 0, end: -700, duration: (5 + i).seconds)
        .fadeOut(delay: (2 + i).seconds),
    ));
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              const Color(0xFF1A1A2E).withOpacity(0.3),
              Colors.black.withOpacity(0.95),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
          const Column(
            children: [
              Text(
                "FRIENDSHIP HALL",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 4),
              ),
              Text(
                "BOND WITH YOUR BESTIES",
                style: TextStyle(color: Colors.blueAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 20),
        ],
      ),
    );
  }

  Widget _buildSacredRing(UserModel user, UserModel friend, bool isBestFriend) {
    return Container(
      height: 160,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central connection icon
          Icon(
            isBestFriend ? Icons.favorite_rounded : Icons.people_alt_rounded,
            color: isBestFriend ? Colors.blueAccent : Colors.cyanAccent,
            size: 100,
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds)
            .fadeOut(duration: 2.seconds),
          
          // User avatars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSacredAvatar(user.profilePhotoUrl, "YOU"),
              const Gap(80),
              _buildSacredAvatar(friend.profilePhotoUrl, friend.displayName.toUpperCase(), isEmpty: false),
            ],
          ),
          
          // Connection icon
          Icon(
            isBestFriend ? Icons.favorite_rounded : Icons.handshake_rounded,
            color: Colors.white,
            size: 36,
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
        ],
      ),
    );
  }

  Widget _buildSacredAvatar(String url, String label, {bool isEmpty = false}) {
    return Column(
      children: [
        Container(
          width: 84, height: 84,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 25)],
          ),
          child: Container(
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: isEmpty || url.isEmpty
              ? Icon(isEmpty ? Icons.person_add_rounded : Icons.person, color: Colors.white12, size: 28)
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (c, e, s) => const Icon(Icons.person, color: Colors.white12)),
          ),
        ),
        const Gap(12),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildLevelProgress(RelationshipModel friendship, int level, Map<String, dynamic> levelData, int nextLevelIntimacy, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.05), blurRadius: 30)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniProfileCircle(friendship.participants.first),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.handshake_rounded, color: Colors.blueAccent, size: 24),
              ),
              _miniProfileCircle(friendship.participants.last),
            ],
          ),
          const Gap(24),
          Text(levelData['name'], style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Gap(4),
          Text("LV.$level", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
          const Gap(16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
            ),
          ),
          const Gap(12),
          Text("${friendship.intimacy}/$nextLevelIntimacy FRIENDSHIP XP", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _miniProfileCircle(String uid) {
    return FutureBuilder(
      future: ref.read(userProfileProvider(uid).future),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final url = user?.profilePhotoUrl ?? '';
        return Container(
          width: 54, height: 54,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          child: Container(
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: url.isEmpty
              ? const Icon(Icons.person, color: Colors.white12)
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (c, e, s) => const Icon(Icons.person, color: Colors.white12)),
          ),
        );
      },
    );
  }

  Widget _buildGlassStats(UserModel user, UserModel friend, RelationshipModel friendship, int friendCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat("FRIENDS", friendCount.toString()),
          _miniStat("BOND XP", friendship.intimacy.toString()),
          _miniStat("LEVEL", friendship.level.toString()),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildMiniMissionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("FRIENDSHIP MISSIONS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2.5)),
        const Gap(16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.5,
          children: [
            _tinyMission(Icons.mic, "Voice Chat", "+10"),
            _tinyMission(Icons.card_giftcard, "Send Gift", "+100"),
            _tinyMission(Icons.camera_alt, "Share Moment", "+25"),
            _tinyMission(Icons.videogame_asset, "Play Together", "+15"),
          ],
        ),
      ],
    );
  }

  Widget _tinyMission(IconData icon, String title, String xp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 12),
          const Gap(10),
          Expanded(child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 9))),
          Text(xp, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildPerkRow(bool isBestFriend) {
    return Row(
      children: [
        _miniPerk(Icons.shield_rounded, "FRIEND SHIELD", isBestFriend),
        const Gap(10),
        _miniPerk(Icons.auto_awesome_rounded, "BESTIE ENTRY", isBestFriend),
      ],
    );
  }

  Widget _miniPerk(IconData icon, String label, bool unlocked) {
    return Expanded(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFF1A1A2E) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unlocked ? Colors.blueAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: unlocked ? Colors.blueAccent : Colors.white12, size: 14),
            const Gap(10),
            Text(
              label,
              style: TextStyle(
                color: unlocked ? Colors.white54 : Colors.white12,
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
      ),
    );
  }

  void _showRemoveFriendDialog(UserModel friend, RelationshipModel friendship) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Friend?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          "This will end your friendship with ${friend.displayName}. All shared progress and bonuses will be lost. This action cannot be undone.",
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(relationshipServiceProvider).removeFriend(friendship.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Friend removed."), backgroundColor: Colors.orange),
                  );
                  Navigator.pop(context); // Go back to previous screen
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("REMOVE"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFriendsState(UserModel user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(Icons.people_outline, color: Colors.white24, size: 56),
            ),
            const Gap(16),
            const Text("No Friends Yet", style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
            const Gap(8),
            const Text("Add friends to unlock the Friendship Hall\nand build bonds together.", style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
            const Gap(24),
            ElevatedButton(
              onPressed: () => context.push(AppRoutes.friendList),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text("FIND FRIENDS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text("Error: $error", style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
    );
  }

  // Level data helpers
  Map<String, dynamic> _getLevelData(int level) {
    const levelNames = {
      1: 'Acquaintance',
      2: 'Friend',
      3: 'Close Friend',
      4: 'Best Friend',
      5: 'Soulmate',
    };
    return {'name': levelNames[level] ?? 'Level $level'};
  }

  int _getCurrentLevelIntimacy(int level) {
    const thresholds = {1: 0, 2: 1000, 3: 5000, 4: 20000, 5: 50000};
    return thresholds[level] ?? 0;
  }

  int _getNextLevelIntimacy(int level) {
    const thresholds = {1: 1000, 2: 5000, 3: 20000, 4: 50000, 5: 50000};
    return thresholds[level] ?? 50000;
  }
}