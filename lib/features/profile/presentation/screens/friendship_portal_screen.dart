import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Ultra-Luxury Room Support Palette
  static const Color darkBg = Color(0xFF070604);
  static const Color cardBg = Color(0xFF13100B);
  static const Color borderGold = Color(0xFF4A3A16);
  static const Color borderGoldLight = Color(0xFF7E6327);
  static const Color textGoldHeader = Color(0xFFF7E7B4);
  static const Color textGoldSub = Color(0xFFD8B65C);
  static const Color textGoldBright = Color(0xFFFFE58F);

  static const LinearGradient goldHeaderGradient = LinearGradient(
    colors: [
      Color(0xFFE5C058),
      Color(0xFFB38728),
      Color(0xFFFBF5B7),
      Color(0xFFDAA520),
      Color(0xFFA67C1E),
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient metallicBadgeGradient = LinearGradient(
    colors: [
      Color(0xFFFFF1B8),
      Color(0xFFD4AF37),
      Color(0xFFAA7C11),
      Color(0xFFF3E5AB),
      Color(0xFF8A6D1C),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  ConsumerState<FriendshipPortalScreen> createState() => _FriendshipPortalScreenState();
}

class _FriendshipPortalScreenState extends ConsumerState<FriendshipPortalScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: FriendshipPortalScreen.darkBg,
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
              
              return _buildPortalContent(user, activeFriendships);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: FriendshipPortalScreen.textGoldBright)),
            error: (e, __) => _buildErrorState(e.toString()),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: FriendshipPortalScreen.textGoldBright)),
        error: (e, __) => _buildErrorState(e.toString()),
      ),
    );
  }

  Widget _buildPortalContent(UserModel user, List<RelationshipModel> friendships) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  // Ultra-Premium Hero Banner with Top-to-Bottom Opacity Fade & Outside Floating Title Badge
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _buildHeroBanner(),
                      ),
                      Positioned(
                        bottom: -18,
                        child: _buildTitleBadge(),
                      ),
                    ],
                  ),

                  const Gap(32),

                  // Friends List Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
          ),
        ],
      ),
    );
  }

  // ─── HERO BANNER ─────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FriendshipPortalScreen.darkBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(16),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black,
              Colors.black87,
              Colors.black38,
              Colors.transparent,
            ],
            stops: [0.0, 0.35, 0.65, 0.88, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'assets/images/friendship_mall_hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 0.95,
                  colors: [
                    Color(0xFF4A3710),
                    Color(0xFF1F1608),
                    FriendshipPortalScreen.darkBg,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.favorite_rounded, color: FriendshipPortalScreen.textGoldBright, size: 80),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 3D METALLIC TITLE BADGE ──────────────────────────────────────────────
  Widget _buildTitleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        gradient: FriendshipPortalScreen.metallicBadgeGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFF9E6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 6)),
          BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Friendship Hall",
            style: GoogleFonts.cinzel(
              color: const Color(0xFF2A1D04),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              shadows: [
                const Shadow(color: Colors.white70, blurRadius: 1, offset: Offset(0, 1)),
              ],
            ),
          ),
          const Gap(8),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFF00E5FF), blurRadius: 8, spreadRadius: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(UserModel user, RelationshipModel friendship) {
    final otherUid = friendship.participants.firstWhere((id) => id != user.uid);
    final otherUserAsync = ref.watch(userProfileProvider(otherUid));

    return otherUserAsync.when(
      data: (friend) {
        if (friend == null) return const SizedBox();
        final isBestFriend = friendship.level >= 4;
        return Container(
          decoration: BoxDecoration(
            color: FriendshipPortalScreen.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isBestFriend ? FriendshipPortalScreen.textGoldBright : FriendshipPortalScreen.borderGold, width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FriendshipPortalScreen.borderGoldLight, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: friend.profilePhotoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white38),
                ),
              ),
            ),
            title: Text(
              friend.displayName,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: FriendshipPortalScreen.goldHeaderGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "LV.${friendship.level}",
                    style: GoogleFonts.cinzel(color: const Color(0xFF241804), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const Gap(8),
                Text(
                  "${friendship.intimacy} XP",
                  style: GoogleFonts.plusJakartaSans(color: FriendshipPortalScreen.textGoldSub, fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _showRemoveFriendDialog(friend, friendship),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: FriendshipPortalScreen.textGoldBright)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: FriendshipPortalScreen.darkBg,
        border: Border(bottom: BorderSide(color: Color(0xFF221B0E), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          ),
          Expanded(
            child: Center(
              child: Text(
                "FRIENDSHIP HALL",
                style: GoogleFonts.cinzel(
                  color: FriendshipPortalScreen.textGoldBright,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
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