import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/utils/number_formatter.dart';

/// Per-room gift (diamond) leaderboard.
/// Reads from `rooms/{roomId}/gift_leaderboard/{period}/{bucket}/{uid}`
/// where bucket is the active UTC date-bucket written by the cloud function.
class RoomGiftLeaderboardScreen extends StatefulWidget {
  final String roomId;
  final String? roomName;

  const RoomGiftLeaderboardScreen({super.key, required this.roomId, this.roomName});

  @override
  State<RoomGiftLeaderboardScreen> createState() => _RoomGiftLeaderboardScreenState();
}

class _RoomGiftLeaderboardScreenState extends State<RoomGiftLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const periods = ['daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: periods.length, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _currentBucket(String period) {
    final now = DateTime.now().toUtc();
    switch (period) {
      case 'daily':
        return '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
      case 'weekly':
        return _isoWeekKey(now);
      case 'monthly':
        return '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}';
      default:
        return '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
    }
  }

  /// ISO week key (e.g. "2026-W35") computed in UTC to match the backend.
  String _isoWeekKey(DateTime date) {
    final dayNum = date.weekday;
    final thursday = date.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  int _ordinalDate(DateTime date) {
    final startOfYear = DateTime.utc(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  Stream<QuerySnapshot> _leaderboardStream(String period) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('gift_leaderboard')
        .doc(period)
        .collection(_currentBucket(period))
        .orderBy('amount', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.roomName ?? 'Room Gifts',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 17),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorColor: const Color(0xFFFFD700),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: "DAILY"),
                Tab(text: "WEEKLY"),
                Tab(text: "MONTHLY"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: periods
            .map((p) => _LeaderboardTab(
                  stream: _leaderboardStream(p),
                  roomId: widget.roomId,
                  accentColor: p == 'daily'
                      ? const Color(0xFFFF6A88)
                      : p == 'weekly'
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFF8E54E9),
                ))
            .toList(),
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String roomId;
  final Color accentColor;

  const _LeaderboardTab({
    required this.stream,
    required this.roomId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;
          final items = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _LeaderboardEntry(
              uid: doc.id,
              name: (data['name'] as String?)?.isNotEmpty == true ? data['name'] as String : 'User',
              photoUrl: (data['photoUrl'] as String?) ?? '',
              amount: (data['amount'] as num?)?.toInt() ?? 0,
            );
          }).toList();

          return _buildLeaderboardContent(context, items);
        }

        // Fallback: Read real-time room participants ordered by diamondsSent
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .collection('participants')
              .where('diamondsSent', isGreaterThan: 0)
              .orderBy('diamondsSent', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, partSnap) {
            if (partSnap.hasData && partSnap.data!.docs.isNotEmpty) {
              final items = partSnap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _LeaderboardEntry(
                  uid: doc.id,
                  name: (data['name'] as String?)?.isNotEmpty == true ? data['name'] as String : 'User',
                  photoUrl: (data['profilePhotoUrl'] as String?) ?? '',
                  amount: (data['diamondsSent'] as num?)?.toInt() ?? 0,
                );
              }).toList();
              return _buildLeaderboardContent(context, items);
            }

            return const _EmptyState();
          },
        );
      },
    );
  }

  Widget _buildLeaderboardContent(BuildContext context, List<_LeaderboardEntry> items) {
    final top1 = items.isNotEmpty ? items[0] : null;
    final top2 = items.length > 1 ? items[1] : null;
    final top3 = items.length > 2 ? items[2] : null;
    final rest = items.length > 3 ? items.sublist(3) : <_LeaderboardEntry>[];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. Luxury Podium for Top 3
          if (top1 != null)
            _PodiumSection(top1: top1, top2: top2, top3: top3, accentColor: accentColor),

          // 2. Ranked List for #4+
          if (rest.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = rest[index];
                return _RankCard(
                  rank: index + 4,
                  entry: item,
                  accentColor: accentColor,
                ).animate().fadeIn(delay: Duration(milliseconds: (index * 30).clamp(0, 500)));
              },
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _LeaderboardEntry {
  final String uid;
  final String name;
  final String photoUrl;
  final int amount;

  const _LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.amount,
  });
}

class _PodiumSection extends StatelessWidget {
  final _LeaderboardEntry top1;
  final _LeaderboardEntry? top2;
  final _LeaderboardEntry? top3;
  final Color accentColor;

  const _PodiumSection({
    required this.top1,
    this.top2,
    this.top3,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withOpacity(0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 Silver (Left)
          if (top2 != null)
            Expanded(child: _PodiumColumn(rank: 2, entry: top2!, isCenter: false, accentColor: accentColor))
          else
            const Expanded(child: SizedBox()),

          // #1 Gold (Center, Elevated)
          Expanded(child: _PodiumColumn(rank: 1, entry: top1, isCenter: true, accentColor: accentColor)),

          // #3 Bronze (Right)
          if (top3 != null)
            Expanded(child: _PodiumColumn(rank: 3, entry: top3!, isCenter: false, accentColor: accentColor))
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final int rank;
  final _LeaderboardEntry entry;
  final bool isCenter;
  final Color accentColor;

  const _PodiumColumn({
    required this.rank,
    required this.entry,
    required this.isCenter,
    required this.accentColor,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFB800);
    if (rank == 2) return const Color(0xFF94A3B8);
    return const Color(0xFFD97706);
  }

  String get _crownAsset {
    if (rank == 1) return "assets/images/levels/level_badge_5.png";
    if (rank == 2) return "assets/images/levels/level_badge_4.png";
    return "assets/images/levels/level_badge_3.png";
  }

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isCenter ? 36.0 : 28.0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfile, extra: entry.uid),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Medal Icon
          Image.asset(
            _crownAsset,
            width: isCenter ? 36 : 28,
            height: isCenter ? 36 : 28,
            errorBuilder: (_, __, ___) => Icon(
              Icons.emoji_events_rounded,
              color: _rankColor,
              size: isCenter ? 32 : 24,
            ),
          ),
          const SizedBox(height: 4),

          // Avatar with Rank Border
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_rankColor, _rankColor.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: _rankColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: AppAvatar(
                  imageUrl: entry.photoUrl,
                  radius: avatarRadius,
                  showFrame: false,
                  staticFrame: true,
                ),
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rankColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    'No.$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // User Name
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: isCenter ? 14 : 12,
            ),
          ),

          const SizedBox(height: 4),

          // Diamond Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, color: Color(0xFFFFB800), size: 12),
                const SizedBox(width: 4),
                Text(
                  formatCount(entry.amount),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: isCenter ? 12 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final _LeaderboardEntry entry;
  final Color accentColor;

  const _RankCard({
    required this.rank,
    required this.entry,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfile, extra: entry.uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Avatar
            AppAvatar(
              imageUrl: entry.photoUrl,
              radius: 22,
              showFrame: false,
              staticFrame: true,
            ),

            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),

            // Diamonds
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFFFFB800), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(entry.amount),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackLeaderboardList extends StatelessWidget {
  final List<MapEntry<String, dynamic>> entries;
  final Color accentColor;

  const _FallbackLeaderboardList({
    required this.entries,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final uid = entry.key;
        final amount = (entry.value as num).toInt();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final name = (userData['displayName'] as String?) ?? 'User';
            final photoUrl = (userData['profilePhotoUrl'] as String?) ?? '';

            final item = _LeaderboardEntry(
              uid: uid,
              name: name,
              photoUrl: photoUrl,
              amount: amount,
            );

            if (index == 0) {
              return _PodiumSection(top1: item, accentColor: accentColor);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RankCard(rank: index + 1, entry: item, accentColor: accentColor),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, color: Colors.black26, size: 64),
          SizedBox(height: 12),
          Text(
            "No gifts sent yet",
            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            "Gift diamonds in this room to climb the ranking.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}