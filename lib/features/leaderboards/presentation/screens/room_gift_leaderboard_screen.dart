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
    // No setState listener here: TabBar and TabBarView already subscribe to the
    // controller, and rebuilding on every animation tick handed each child a
    // brand-new Firestore stream mid-swipe (visible flicker, refetch per frame).
    _tabController = TabController(length: periods.length, vsync: this);
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
              // Equal-width tabs, evenly distributed. `isScrollable: true`
              // left-hugged the three short labels against the back button.
              isScrollable: false,
              tabAlignment: TabAlignment.fill,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              dividerColor: Colors.transparent,
              indicatorColor: const Color(0xFFFFD700),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
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
                  streamFactory: () => _leaderboardStream(p),
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

class _LeaderboardTab extends StatefulWidget {
  final Stream<QuerySnapshot> Function() streamFactory;
  final String roomId;
  final Color accentColor;

  const _LeaderboardTab({
    required this.streamFactory,
    required this.roomId,
    required this.accentColor,
  });

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  late Stream<QuerySnapshot> _stream;
  late Stream<QuerySnapshot> _fallback;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    // Subscribed once per tab (and again only on pull-to-refresh / retry) so a
    // parent rebuild cannot hand us a new stream and blank the screen.
    _stream = widget.streamFactory();
    // Fallback: live participant totals, used only while the period buckets are
    // still empty because the cloud function has not written them yet.
    _fallback = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('participants')
        .where('diamondsSent', isGreaterThan: 0)
        .orderBy('diamondsSent', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> _refresh() async {
    setState(_subscribe);
    // Keep the indicator visible long enough to register on a fast local read.
    await Future.delayed(const Duration(milliseconds: 400));
  }

  List<_LeaderboardEntry> _mapDocs(
    List<QueryDocumentSnapshot> docs,
    String nameKey,
    String photoKey,
    String amountKey,
  ) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final rawName = data[nameKey] as String?;
      return _LeaderboardEntry(
        uid: doc.id,
        name: (rawName != null && rawName.isNotEmpty) ? rawName : 'User',
        photoUrl: (data[photoKey] as String?) ?? '',
        amount: (data[amountKey] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: widget.accentColor,
      backgroundColor: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StatusBody(child: _ErrorState(onRetry: _refresh));
          }
          if (!snapshot.hasData) {
            return const _StatusBody(child: _LoadingState());
          }

          final docs = snapshot.data!.docs;
          if (docs.isNotEmpty) {
            return _buildLeaderboardContent(
              context,
              _mapDocs(docs, 'name', 'photoUrl', 'amount'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _fallback,
            builder: (context, partSnap) {
              if (partSnap.hasError) {
                return _StatusBody(child: _ErrorState(onRetry: _refresh));
              }
              if (!partSnap.hasData) {
                return const _StatusBody(child: _LoadingState());
              }
              final fdocs = partSnap.data!.docs;
              if (fdocs.isNotEmpty) {
                return _buildLeaderboardContent(
                  context,
                  _mapDocs(fdocs, 'name', 'profilePhotoUrl', 'diamondsSent'),
                );
              }
              return const _StatusBody(child: _EmptyState());
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardContent(BuildContext context, List<_LeaderboardEntry> items) {
    final top1 = items.isNotEmpty ? items[0] : null;
    final top2 = items.length > 1 ? items[1] : null;
    final top3 = items.length > 2 ? items[2] : null;
    final rest = items.length > 3 ? items.sublist(3) : <_LeaderboardEntry>[];

    return SingleChildScrollView(
      // AlwaysScrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // 1. Luxury Podium for Top 3
          if (top1 != null)
            _PodiumSection(
              top1: top1,
              top2: top2,
              top3: top3,
              accentColor: widget.accentColor,
            ),

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
                  accentColor: widget.accentColor,
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

/// Centres [child] against the full viewport while staying scrollable, so a
/// `RefreshIndicator` can still be pulled when a tab is showing a status
/// message instead of a list.
class _StatusBody extends StatelessWidget {
  final Widget child;

  const _StatusBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFFFD700)),
          ),
          SizedBox(height: 14),
          Text(
            "Loading ranking…",
            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.black26, size: 56),
          const SizedBox(height: 12),
          const Text(
            "Couldn't load ranking",
            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            "Check your connection and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("RETRY"),
          ),
        ],
      ),
    );
  }
}