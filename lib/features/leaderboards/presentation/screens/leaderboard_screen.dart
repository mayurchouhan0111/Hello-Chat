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
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialIndex.clamp(0, 4));
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
                Tab(text: "CONTRIBUTION 👑"),
                Tab(text: "CHARM 💖"),
                Tab(text: "ROOMS 🎙️"),
                Tab(text: "AGENCY 🏢"),
                Tab(text: "GAMES 🎲"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ContributionRankingScreen(),
          CharmTab(),
          RoomTab(),
          AgencyTab(),
          GameTab(),
        ],
      ),
    );
  }
}

class ContributionTab extends StatelessWidget {
  const ContributionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BaseRankingScreen(
      title: "CONTRIBUTION",
      field: "benchXP",
      subtitle: "TOP SENDERS",
      accentColor: Color(0xFFFF6A88),
    );
  }
}

class CharmTab extends StatelessWidget {
  const CharmTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BaseRankingScreen(
      title: "CHARM",
      field: "princeXP",
      subtitle: "TOP RECEIVERS",
      accentColor: Color(0xFF8BC6EC),
      showFlag: false,
    );
  }
}

class RoomTab extends StatelessWidget {
  const RoomTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BaseRankingScreen(
      title: "LIVE ROOMS",
      field: "currentUsersCount",
      subtitle: "MOST POPULAR",
      accentColor: Color(0xFF2DD4BF),
      isRoom: true,
      collection: "rooms",
    );
  }
}

class AgencyTab extends StatelessWidget {
  const AgencyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BaseRankingScreen(
      title: "TOP AGENCIES",
      field: "beansBalance",
      subtitle: "AGENCY PERFORMANCE",
      accentColor: Color(0xFFFF9100),
      isAgency: true,
      collection: "agencies",
    );
  }
}

class GameTab extends StatelessWidget {
  const GameTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BaseRankingScreen(
      title: "GAME WINNERS",
      field: "combatPoints",
      subtitle: "JACKPOT KINGS",
      accentColor: Color(0xFFFF0055),
      collection: "users",
    );
  }
}

class _BaseRankingScreen extends StatelessWidget {
  final String title;
  final String field;
  final String subtitle;
  final Color accentColor;
  final bool isRoom;
  final bool isAgency;
  final String collection;
  final bool showFlag;

  const _BaseRankingScreen({
    required this.title,
    required this.field,
    required this.subtitle,
    required this.accentColor,
    this.isRoom = false,
    this.isAgency = false,
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF8E54E9)));

          final items = snapshot.data!.docs;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 54, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text("No rankings available yet", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemExtent: 82.0,
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;
              
              String name = "User";
              String subText = "@user";
              String photoUrl = "";
              
              if (isRoom) {
                name = data['name'] ?? 'Live Room';
                subText = "Room ID: ${items[index].id.substring(0, 6)}";
                photoUrl = data['coverUrl'] ?? "";
              } else if (isAgency) {
                name = data['agencyName'] ?? data['name'] ?? 'Agency';
                subText = "Agency ID: ${items[index].id.substring(0, 6)}";
                photoUrl = data['logoUrl'] ?? data['agencyLogoUrl'] ?? "";
              } else {
                name = data['displayName'] ?? "User";
                subText = "@${data['username'] ?? 'user'}";
                photoUrl = data['profilePhotoUrl'] ?? "";
              }

              return _RankingItem(
                uid: items[index].id,
                rank: index + 1,
                name: name,
                subText: subText,
                photoUrl: photoUrl,
                score: (data[field] ?? 0).toString(),
                accentColor: accentColor,
                countryCode: (isRoom || isAgency || !showFlag) ? null : (data['countryCode'] ?? "US"),
                scoreLabel: isRoom ? "AUDIENCE" : (isAgency ? "BEANS" : (field == "benchXP" ? "SENT" : (field == "princeXP" ? "RCVD" : "PTS"))),
                isRoom: isRoom,
                isAgency: isAgency,
                frameUrl: (isRoom || isAgency) ? null : (data['profileFrame'] as String?),
                vipTier: (isRoom || isAgency) ? null : (data['vipTier'] as String?),
                level: (isRoom || isAgency) ? null : (data['level'] as int?),
                tags: (isRoom || isAgency) ? null : (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
              ).animate().fadeIn(delay: Duration(milliseconds: (index * 30).clamp(0, 800))).slideX(begin: 0.08);
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
  final bool isAgency;
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
    this.isAgency = false,
    this.frameUrl,
    this.vipTier,
    this.level,
    this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color getRankColor() {
      if (rank == 1) return const Color(0xFFFFD700);
      if (rank == 2) return const Color(0xFFC0C0C0);
      if (rank == 3) return const Color(0xFFCD7F32);
      return Colors.black26;
    }

    return InkWell(
      onTap: () {
        if (isRoom) {
          RoomNavigationHelper.joinRoom(context, ref, uid);
        } else if (!isAgency) {
          context.push(AppRoutes.userProfile, extra: uid);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                "$rank",
                style: TextStyle(
                  color: getRankColor(),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (isRoom || isAgency) 
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                        child: photoUrl.isEmpty ? Icon(isAgency ? Icons.business_rounded : Icons.meeting_room_rounded, color: Colors.grey) : null,
                      )
                    else
                      AppAvatar(
                        imageUrl: photoUrl,
                        frameUrl: frameUrl,
                        vipTier: vipTier,
                        userLevel: level,
                        tags: tags,
                        radius: 25,
                        showFrame: true,
                        frameMultiplier: 1.6,
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(subText, style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(score, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(scoreLabel, style: const TextStyle(color: Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
