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

  /// ISO week key (e.g. "2026-W33") computed in UTC to match the backend.
  String _isoWeekKey(DateTime date) {
    final dayOfYear = _ordinalDate(date);
    final dayOfWeek = date.weekday; // 1=Mon ... 7=Sun (Dart)
    final week = ((dayOfYear - dayOfWeek + 10) / 7).floor();
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _RankRow(
                uid: docs[index].id,
                rank: index + 1,
                name: (data['name'] as String?)?.isNotEmpty == true ? data['name'] as String : 'User',
                photoUrl: (data['photoUrl'] as String?) ?? '',
                amount: (data['amount'] as num?)?.toInt() ?? 0,
                accentColor: accentColor,
              ).animate().fadeIn(delay: Duration(milliseconds: (index * 40).clamp(0, 1000)));
            },
          );
        }

        // Fallback: Read real-time room contributions directly from rooms/{roomId}
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots(),
          builder: (context, roomSnap) {
            if (!roomSnap.hasData || !roomSnap.data!.exists) {
              return const _EmptyState();
            }

            final roomData = roomSnap.data!.data() as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> rawContribs = (roomData['rocketContributions'] as Map<String, dynamic>?) ??
                (roomData['pkContributions'] as Map<String, dynamic>?) ?? {};

            if (rawContribs.isEmpty) {
              return const _EmptyState();
            }

            final sortedEntries = rawContribs.entries.toList()
              ..sort((a, b) => ((b.value as num).toInt()).compareTo((a.value as num).toInt()));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                final uid = entry.key;
                final amount = (entry.value as num).toInt();

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final name = (userData['displayName'] as String?) ?? 'User';
                    final photoUrl = (userData['profilePhotoUrl'] as String?) ?? '';

                    return _RankRow(
                      uid: uid,
                      rank: index + 1,
                      name: name,
                      photoUrl: photoUrl,
                      amount: amount,
                      accentColor: accentColor,
                    );
                  },
                );
              },
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

class _RankRow extends StatelessWidget {
  final String uid;
  final int rank;
  final String name;
  final String photoUrl;
  final int amount;
  final Color accentColor;

  const _RankRow({
    required this.uid,
    required this.rank,
    required this.name,
    required this.photoUrl,
    required this.amount,
    required this.accentColor,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFA0AEC0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.black26;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.userProfile, extra: uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: _rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppAvatar(
              imageUrl: photoUrl,
              radius: 26,
              showFrame: false,
              staticFrame: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCount(amount),
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const Text(
                  "SENT",
                  style: TextStyle(color: Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}