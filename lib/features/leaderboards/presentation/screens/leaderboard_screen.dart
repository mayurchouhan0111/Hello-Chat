import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'contribution_ranking_screen.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const LeaderboardScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          onPressed: () => Navigator.pop(context)
        ),
        title: const Text("RANKINGS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 17)),
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
              indicatorColor: const Color(0xFF8E54E9), // Premium Purple
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: "CONTRIBUTION"),
                Tab(text: "CHARM"),
                Tab(text: "ROOMS"),
                Tab(text: "OVERALL"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ContributionRankingScreen(), // Using the NEW premium screen
          CharmTab(),
          RoomTab(),
          OverallTab(),
        ],
      ),
    );
  }
}

class ContributionTab extends StatelessWidget {
  const ContributionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "CONTRIBUTION",
      field: "benchXP",
      subtitle: "TOP SENDERS",
      accentColor: const Color(0xFFFF6A88),
    );
  }
}

class CharmTab extends StatelessWidget {
  const CharmTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "CHARM",
      field: "princeXP",
      subtitle: "TOP RECEIVERS",
      accentColor: const Color(0xFF8BC6EC),
      showFlag: false,
    );
  }
}

class RoomTab extends StatelessWidget {
  const RoomTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "LIVE ROOMS",
      field: "currentUsersCount",
      subtitle: "MOST POPULAR",
      accentColor: const Color(0xFF2DD4BF),
      isRoom: true,
      collection: "rooms",
    );
  }
}

class OverallTab extends StatelessWidget {
  const OverallTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "GLOBAL BEST",
      field: "xp",
      subtitle: "OVERALL RANKING",
      accentColor: const Color(0xFFFACC15),
    );
  }
}

class _BaseRankingScreen extends StatelessWidget {
  final String title;
  final String field;
  final String subtitle;
  final Color accentColor;
  final bool isRoom;
  final String collection;
  final bool showFlag;

  const _BaseRankingScreen({
    required this.title,
    required this.field,
    required this.subtitle,
    required this.accentColor,
    this.isRoom = false,
    this.collection = "users",
    this.showFlag = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .orderBy(field, descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));

          final items = snapshot.data!.docs;
          return ListView.builder(
            itemExtent: 77.0,
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;
              return _RankingItem(
                uid: items[index].id,
                rank: index + 1,
                name: isRoom ? (data['name'] ?? 'Room') : (data['displayName'] ?? "User"),
                subText: isRoom ? "Room ID: ${items[index].id.substring(0, 6)}" : "@${data['username'] ?? 'user'}",
                photoUrl: isRoom ? (data['coverUrl'] ?? "") : (data['profilePhotoUrl'] ?? ""),
                score: (data[field] ?? 0).toString(),
                accentColor: accentColor,
                countryCode: (isRoom || !showFlag) ? null : (data['countryCode'] ?? "US"),
                scoreLabel: isRoom ? "AUDIENCE" : (field == "benchXP" ? "SENT" : (field == "princeXP" ? "RCVD" : "XP")),
                isRoom: isRoom,
                frameUrl: isRoom ? null : (data['profileFrame'] as String?),
                vipTier: isRoom ? null : (data['vipTier'] as String?),
                level: isRoom ? null : (data['level'] as int?),
                tags: isRoom ? null : (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
              ).animate().fadeIn(delay: Duration(milliseconds: (index * 40).clamp(0, 1000))).slideX(begin: 0.1);
            },
          );
        },
      ),
    );
  }
}

class _RankingItem extends ConsumerWidget {
  final String uid;
  final int rank;
  final String name;
  final String subText;
  final String photoUrl;
  final String score;
  final Color accentColor;
  final String? countryCode;
  final String scoreLabel;
  final bool isRoom;
  final String? frameUrl;
  final String? vipTier;
  final int? level;
  final List<String>? tags;

  const _RankingItem({
    required this.uid,
    required this.rank,
    required this.name,
    required this.subText,
    required this.photoUrl,
    required this.score,
    required this.accentColor,
    this.countryCode,
    required this.scoreLabel,
    this.isRoom = false,
    this.frameUrl,
    this.vipTier,
    this.level,
    this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color getRankColor() {
      if (rank == 1) return const Color(0xFFFFD700);
      if (rank == 2) return const Color(0xFFE2E8F0);
      if (rank == 3) return const Color(0xFFCD7F32);
      return Colors.white10;
    }

    return InkWell(
      onTap: () {
        if (isRoom) {
          RoomNavigationHelper.joinRoom(context, ref, uid);
        } else {
          context.push(AppRoutes.userProfile, extra: uid);
        }
      },
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
            child: Text("$rank", style: TextStyle(color: rank <= 3 ? getRankColor() : Colors.black26, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              if (isRoom) 
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                )
              else
                AppAvatar(
                  imageUrl: photoUrl,
                  frameUrl: frameUrl,
                  vipTier: vipTier,
                  userLevel: level,
                  tags: tags,
                  radius: 26,
                  showFrame: true,
                  frameMultiplier: 1.5,
                ),
              if (countryCode != null) Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(child: Image.network("https://flagcdn.com/w40/${countryCode!.toLowerCase()}.png", width: 14, height: 10, fit: BoxFit.cover)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(subText, style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(scoreLabel, style: const TextStyle(color: Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    ));
  }
}
