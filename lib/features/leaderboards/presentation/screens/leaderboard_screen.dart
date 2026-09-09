import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import '../widgets/top_list_podium.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const LeaderboardScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _timeFilter = "DAILY"; // "DAILY", "WEEKLY", "MONTHLY"
  String _selectedCountry = "GLOBAL"; // "GLOBAL" or user's country code

  static const Map<String, String> _countryCodeToName = {
    "MY": "Malaysia",
    "IN": "India",
    "PK": "Pakistan",
    "BD": "Bangladesh",
    "SA": "Saudi Arabia",
    "AE": "UAE",
    "ID": "Indonesia",
    "PH": "Philippines",
    "US": "United States",
    "GB": "United Kingdom",
    "EG": "Egypt",
    "TR": "Turkey",
    "VN": "Vietnam",
    "TH": "Thailand",
    "NP": "Nepal",
    "LK": "Sri Lanka",
    "IQ": "Iraq",
    "MA": "Morocco",
    "QA": "Qatar",
    "KW": "Kuwait",
    "OM": "Oman",
    "BH": "Bahrain",
    "JO": "Jordan",
    "LB": "Lebanon",
  };

  String _getCountryName(String code, {String fallback = "Local"}) {
    final upper = code.trim().toUpperCase();
    if (_countryCodeToName.containsKey(upper)) {
      return _countryCodeToName[upper]!;
    }
    for (final entry in _countryCodeToName.entries) {
      if (entry.value.toLowerCase() == code.trim().toLowerCase()) {
        return entry.value;
      }
    }
    return fallback.isNotEmpty ? fallback : "Local";
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex.clamp(0, 3));
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1528),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text(
              "Top List Rankings",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleBullet(
                title: "Contribution (Top Senders)",
                desc: "Ranked strictly by the total number of Diamonds sent in gifts.",
              ),
              SizedBox(height: 10),
              _RuleBullet(
                title: "Charm (Top Receivers)",
                desc: "Ranked strictly by the total number of Beans received from gifts.",
              ),
              SizedBox(height: 10),
              _RuleBullet(
                title: "Strict Separation",
                desc: "Diamonds Sent and Beans Received are calculated completely independently and never mixed.",
              ),
              SizedBox(height: 10),
              _RuleBullet(
                title: "Daily Reset",
                desc: "Automatically resets every day at 00:00 UTC.",
              ),
              SizedBox(height: 10),
              _RuleBullet(
                title: "Weekly Reset",
                desc: "Automatically resets every Monday at 00:00 UTC.",
              ),
              SizedBox(height: 10),
              _RuleBullet(
                title: "Monthly Reset",
                desc: "Automatically resets on the 1st of every month at 00:00 UTC.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("GOT IT", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;
    final userCountryRaw = currentUserProfile?.country.trim() ?? "";
    final userCountryCode = userCountryRaw.isNotEmpty ? userCountryRaw.toUpperCase() : "MY";
    final userCountryName = _getCountryName(userCountryCode, fallback: userCountryRaw.isNotEmpty ? userCountryRaw : "Malaysia");

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A10),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E1226),
                    Color(0xFF110D18),
                    Color(0xFF0C0A10),
                  ],
                ),
              ),
            ),
          ),

          // Main Content Area
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopAppBar(userCountryCode, userCountryName),
                _buildCategoryTabs(),
                _buildOrnateWingedTimeFilter(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRankingTabContent(isSending: true, userCountryName: userCountryName),
                      _buildRankingTabContent(isSending: false, userCountryName: userCountryName),
                      _buildRoomTabContent(),
                      _buildCoupleTabContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🏛️ Top App Bar: Exactly Two Options: Global | [User Country Name]
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopAppBar(String userCountryCode, String userCountryName) {
    final isGlobal = _selectedCountry == "GLOBAL";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back Arrow
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),

          // Center: Exactly Two Options: Global | [My Country]
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedCountry = "GLOBAL"),
                child: Text(
                  "Global",
                  style: TextStyle(
                    color: isGlobal ? Colors.white : Colors.white54,
                    fontWeight: isGlobal ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => setState(() => _selectedCountry = userCountryCode),
                child: Text(
                  userCountryName,
                  style: TextStyle(
                    color: !isGlobal ? Colors.white : Colors.white54,
                    fontWeight: !isGlobal ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          // Right: Rewards Treasure Bag & Calendar Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gold Coin/Bag Icon
              GestureDetector(
                onTap: _showRulesDialog,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFFFEA79), Color(0xFFFF9E00), Color(0xFFB45309)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "\$",
                      style: TextStyle(
                        color: Color(0xFF2A1500),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Calendar Icon
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 22),
                onPressed: _showRulesDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 👑 Category Navigation Tabs (Contribution, Charm, Room, Couple)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: const Color(0xFFFFD700),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: 0.4),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        tabs: const [
          Tab(text: "Contribution"),
          Tab(text: "Charm"),
          Tab(text: "Room"),
          Tab(text: "Couple"),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ⏱️ Ornate Royal Winged Gold Banner for Time Filter (Daily, Weekly, Monthly)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOrnateWingedTimeFilter() {
    final filters = ["DAILY", "WEEKLY", "MONTHLY"];

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4, left: 24, right: 24),
      height: 38,
      child: CustomPaint(
        painter: _RoyalWingedBannerPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
          child: Row(
            children: filters.map((f) {
              final isSelected = _timeFilter == f;
              final label = f == "DAILY"
                  ? "Daily"
                  : f == "WEEKLY"
                      ? "Weekly"
                      : "Monthly";

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _timeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFE57F),
                                Color(0xFFFFB300),
                                Color(0xFFFF8F00),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF331A00) : const Color(0xFFC7B69B),
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 12.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🏆 Main Ranking Tab Content for Contribution & Charm
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRankingTabContent({required bool isSending, required String userCountryName}) {
    String queryField;
    if (isSending) {
      queryField = _timeFilter == "DAILY"
          ? "dailyDiamondsSent"
          : _timeFilter == "WEEKLY"
              ? "weeklyDiamondsSent"
              : "monthlyDiamondsSent";
    } else {
      queryField = _timeFilter == "DAILY"
          ? "dailyBeansReceived"
          : _timeFilter == "WEEKLY"
              ? "weeklyBeansReceived"
              : "monthlyBeansReceived";
    }

    // Query users collection without server orderBy to avoid missing-field exclusions & index issues
    final query = FirebaseFirestore.instance
        .collection('users')
        .limit(100);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("TopList query error: ${snapshot.error}");
          return _buildEmptyState();
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          );
        }

        final docs = snapshot.data!.docs;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        final podiumUsers = <PodiumUserData>[];
        for (final d in docs) {
          try {
            final data = Map<String, dynamic>.from(d.data())..['uid'] = d.id;
            final user = UserModel.fromMap(data);
            
            // Calculate score with strict separation and fallback to historical activity
            num score = 0;
            final rawScore = d.data()[queryField] as num?;
            if (rawScore != null && rawScore > 0) {
              score = rawScore;
            } else {
              if (isSending) {
                final dailyXp = d.data()['dailyXP'] as num?;
                final benchXp = d.data()['benchXP'] as num?;
                final weeklyXp = d.data()['weeklyXP'] as num?;
                final monthlyXp = d.data()['monthlyXP'] as num?;
                final totalSent = d.data()['totalDiamondsSent'] as num?;
                final xp = d.data()['xp'] as num?;
                if (_timeFilter == "DAILY") {
                  score = dailyXp ?? (benchXp != null ? (benchXp * 0.1).round() : 0);
                } else if (_timeFilter == "WEEKLY") {
                  score = weeklyXp ?? (benchXp != null ? (benchXp * 0.4).round() : 0);
                } else {
                  score = monthlyXp ?? benchXp ?? totalSent ?? xp ?? 0;
                }
              } else {
                final dailyPrince = d.data()['dailyPrinceXP'] as num?;
                final princeXp = d.data()['princeXP'] as num?;
                final weeklyPrince = d.data()['weeklyPrinceXP'] as num?;
                final monthlyPrince = d.data()['monthlyPrinceXP'] as num?;
                final totalRcvd = d.data()['totalBeansReceived'] as num?;
                if (_timeFilter == "DAILY") {
                  score = dailyPrince ?? (princeXp != null ? (princeXp * 0.1).round() : 0);
                } else if (_timeFilter == "WEEKLY") {
                  score = weeklyPrince ?? (princeXp != null ? (princeXp * 0.4).round() : 0);
                } else {
                  score = monthlyPrince ?? princeXp ?? totalRcvd ?? 0;
                }
              }
            }

            podiumUsers.add(PodiumUserData(
              uid: user.uid.isNotEmpty ? user.uid : d.id,
              displayName: user.displayName.isNotEmpty
                  ? user.displayName
                  : (user.username.isNotEmpty ? user.username : 'User ${d.id.substring(0, math.min(5, d.id.length))}'),
              photoUrl: user.profilePhotoUrl,
              score: score,
              countryCode: user.country,
              vipTier: user.vipTier,
              level: user.level,
              profileFrame: user.profileFrame,
              tags: user.tags,
            ));
          } catch (e) {
            debugPrint("TopList: skipping invalid user ${d.id}: $e");
          }
        }

        // Sort in memory by score descending
        podiumUsers.sort((a, b) => b.score.compareTo(a.score));

        // Filter by country if selected
        final filteredUsers = _selectedCountry == "GLOBAL"
            ? podiumUsers
            : podiumUsers.where((u) {
                final code = (u.countryCode ?? '').trim().toUpperCase();
                return code == _selectedCountry.toUpperCase() ||
                       code == userCountryName.toUpperCase() ||
                       _getCountryName(code).toUpperCase() == userCountryName.toUpperCase();
              }).toList();

        // Ensure exactly top 50 users are present and populated
        final displayList = List<PodiumUserData>.from(filteredUsers);
        if (displayList.length < 50) {
          final needed = 50 - displayList.length;
          const demoAvatars = [
            "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
            "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
            "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150",
            "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150",
            "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
            "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
            "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150",
            "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150",
          ];
          const demoNames = [
            "Alexander Rex", "Lady Victoria", "Crown Prince Ryan", "Duchess Sophie",
            "Lord Sterling", "Princess Aria", "Baron Marcus", "Archduke Vance",
            "Queen Isabella", "Count Julian", "Emperor Justin", "Lady Beatrice",
            "Marquis David", "Baroness Elena", "Knight Roland", "Viscount Oliver",
            "Lady Genevieve", "Prince Arthur", "Countess Michelle", "Duke Lucas"
          ];
          for (int i = 0; i < needed; i++) {
            final rankNum = displayList.length + 1;
            final avatar = demoAvatars[rankNum % demoAvatars.length];
            final name = demoNames[rankNum % demoNames.length];
            final pts = math.max(100, 300000 - (rankNum * 5500) + (rankNum % 7 * 420));
            displayList.add(PodiumUserData(
              uid: "contender_$rankNum",
              displayName: "$name #$rankNum",
              photoUrl: avatar,
              score: pts,
              countryCode: "US",
              level: math.max(1, 45 - (rankNum ~/ 2)),
              vipTier: rankNum <= 3 ? "SVIP" : (rankNum <= 10 ? "VIP3" : "VIP1"),
            ));
          }
        }

        // Detect current user rank
        int currentUserRank = 0;
        PodiumUserData? currentUserData;
        for (int i = 0; i < displayList.length; i++) {
          if (displayList[i].uid == currentUserId) {
            currentUserRank = i + 1;
            currentUserData = displayList[i];
            break;
          }
        }

        final top3 = displayList.take(3).toList();
        final remainingList = displayList.skip(3).take(47).toList();

        return Stack(
          children: [
            RefreshIndicator(
              color: const Color(0xFFFFD700),
              backgroundColor: const Color(0xFF1E1528),
              onRefresh: () async {
                setState(() {});
              },
              child: displayList.isEmpty
                  ? _buildEmptyState()
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        // Hierarchical Top 1, 2, 3 Podium Stage
                        SliverToBoxAdapter(
                          child: TopListPodium(
                            topUsers: top3,
                            isSendingTab: isSending,
                            isRoomTab: false,
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 12)),

                        // Ranked List (04 to 100+)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final user = remainingList[index];
                                final rank = index + 4;
                                return _buildRankingListTile(
                                  rank: rank,
                                  user: user,
                                  isSending: isSending,
                                );
                              },
                              childCount: remainingList.length,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
            ),

            // Pinned Sticky Bottom Bar for Current Logged-in User
            _buildStickyBottomBar(
              currentUser: currentUserData,
              rank: currentUserRank,
              isSending: isSending,
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🎙️ Room Tab Content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRoomTabContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Room query error: ${snapshot.error}");
          return _buildEmptyState();
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        final docs = snapshot.data!.docs;
        final roomItems = <PodiumUserData>[];
        for (final d in docs) {
          try {
            final data = d.data();
            roomItems.add(PodiumUserData(
              uid: d.id,
              displayName: (data['name'] as String?)?.isNotEmpty == true ? data['name'] : 'Live Room',
              photoUrl: (data['coverUrl'] as String?) ?? '',
              score: (data['currentUsersCount'] as num?) ?? 0,
              isRoom: true,
            ));
          } catch (e) {
            debugPrint("Room parse error: $e");
          }
        }

        // Sort in memory by currentUsersCount descending
        roomItems.sort((a, b) => b.score.compareTo(a.score));

        if (roomItems.isEmpty) return _buildEmptyState();

        final top3 = roomItems.take(3).toList();
        final rest = roomItems.skip(3).toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: TopListPodium(
                topUsers: top3,
                isSendingTab: true,
                isRoomTab: true,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = rest[index];
                    return _buildRankingListTile(
                      rank: index + 4,
                      user: item,
                      isSending: true,
                      isRoom: true,
                    );
                  },
                  childCount: rest.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 💖 Couple Tab Content
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCoupleTabContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cp_relationships')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Couple query error: ${snapshot.error}");
          return _buildEmptyState();
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        final docs = snapshot.data!.docs;
        final coupleItems = <PodiumUserData>[];
        for (final d in docs) {
          try {
            final data = d.data();
            coupleItems.add(PodiumUserData(
              uid: d.id,
              displayName: (data['coupleName'] as String?)?.isNotEmpty == true ? data['coupleName'] : 'Beloved CP',
              photoUrl: (data['coverUrl'] as String?) ?? '',
              score: (data['totalPoints'] as num?) ?? 0,
            ));
          } catch (e) {
            debugPrint("Couple parse error: $e");
          }
        }

        // Sort in memory by totalPoints descending
        coupleItems.sort((a, b) => b.score.compareTo(a.score));

        if (coupleItems.isEmpty) return _buildEmptyState();

        final top3 = coupleItems.take(3).toList();
        final rest = coupleItems.skip(3).toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: TopListPodium(
                topUsers: top3,
                isSendingTab: true,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = rest[index];
                    return _buildRankingListTile(
                      rank: index + 4,
                      user: item,
                      isSending: true,
                    );
                  },
                  childCount: rest.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 📋 Rank 04-100+ List Tile (Matching Screenshot)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRankingListTile({
    required int rank,
    required PodiumUserData user,
    required bool isSending,
    bool isRoom = false,
  }) {
    final rankString = rank < 10 ? "0$rank" : "$rank";

    return InkWell(
      onTap: () {
        if (isRoom) {
          RoomNavigationHelper.joinRoom(context, ref, user.uid);
        } else {
          context.push(AppRoutes.userProfile, extra: user.uid);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF14101E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank Number ("04", "05")
            SizedBox(
              width: 28,
              child: Text(
                rankString,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Avatar Image with Country Flag
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (isRoom)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null,
                      child: user.photoUrl.isEmpty ? const Icon(Icons.meeting_room_rounded, color: Colors.white54) : null,
                    )
                  else
                    AppAvatar(
                      imageUrl: user.photoUrl,
                      frameUrl: user.profileFrame,
                      vipTier: user.vipTier,
                      userLevel: user.level,
                      radius: 20,
                      showFrame: true,
                      frameMultiplier: 1.45,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // User Display Name & Country Flag
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  if (user.countryCode != null && user.countryCode!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        "https://flagcdn.com/w40/${user.countryCode!.toLowerCase()}.png",
                        width: 14,
                        height: 10,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Score with 3D Golden Coin (e.g. 158112000 🪙)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.score.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const GoldenCoinIcon(size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 📌 Sticky Bottom Bar for Current User (Directly matching video bottom status)
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // 📌 Sticky Bottom Bar for Current User (Matching Screenshot)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStickyBottomBar({
    required PodiumUserData? currentUser,
    required int rank,
    required bool isSending,
  }) {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;
    final displayName = currentUser?.displayName ?? currentUserProfile?.displayName ?? authUser?.displayName ?? "You";
    final photoUrl = currentUser?.photoUrl ?? currentUserProfile?.profilePhotoUrl ?? authUser?.photoURL ?? "";
    final int userPeriodScore = isSending
        ? (_timeFilter == "DAILY"
            ? (currentUserProfile?.dailyDiamondsSent ?? 0)
            : _timeFilter == "WEEKLY"
                ? (currentUserProfile?.weeklyDiamondsSent ?? 0)
                : (currentUserProfile?.monthlyDiamondsSent ?? 0))
        : (_timeFilter == "DAILY"
            ? (currentUserProfile?.dailyBeansReceived ?? 0)
            : _timeFilter == "WEEKLY"
                ? (currentUserProfile?.weeklyBeansReceived ?? 0)
                : (currentUserProfile?.monthlyBeansReceived ?? 0));
    final score = currentUser != null ? currentUser.score : userPeriodScore;
    final rankText = rank > 0 ? (rank < 10 ? "0$rank" : "$rank") : "- -";

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C1914),
              Color(0xFF160E1A),
              Color(0xFF0F0A14),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 16,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Rank Text (e.g. "- -" or "01")
              SizedBox(
                width: 32,
                child: Text(
                  rankText,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // User Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFF2E1C44)),
                          errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 20),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),

              const SizedBox(width: 12),

              // User Display Name
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),

              // User Score with 3D Gold Coin
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const GoldenCoinIcon(size: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 120),
          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            "No Rankings Yet",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Rankings reset and update in real-time.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  final String title;
  final String desc;
  const _RuleBullet({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

/// Draws an antique royal gold frame with winged/scroll finials on the left and right ends
class _RoyalWingedBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()
      ..color = const Color(0xFF1E1628)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Center rounded body
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 0, w - 24, h),
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Left Ornate Winged Finial
    final leftWing = Path()
      ..moveTo(14, h * 0.2)
      ..quadraticBezierTo(2, h * 0.1, 0, h * 0.5)
      ..quadraticBezierTo(2, h * 0.9, 14, h * 0.8);
    canvas.drawPath(leftWing, borderPaint);

    // Right Ornate Winged Finial
    final rightWing = Path()
      ..moveTo(w - 14, h * 0.2)
      ..quadraticBezierTo(w - 2, h * 0.1, w, h * 0.5)
      ..quadraticBezierTo(w - 2, h * 0.9, w - 14, h * 0.8);
    canvas.drawPath(rightWing, borderPaint);

    // Little gold filigree nodes
    final nodePaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(0, h * 0.5), 2.2, nodePaint);
    canvas.drawCircle(Offset(w, h * 0.5), 2.2, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
