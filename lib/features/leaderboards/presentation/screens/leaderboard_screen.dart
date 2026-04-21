import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("GLOBAL RANKINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF2DD4BF).withOpacity(0.2), border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.5))),
              labelColor: const Color(0xFF2DD4BF),
              unselectedLabelColor: Colors.white38,
              tabs: const [Tab(text: "CONTRIBUTION"), Tab(text: "CHARM"), Tab(text: "ROOMS"), Tab(text: "OVERALL")],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ContributionRankingScreen(),
                CharmRankingScreen(),
                RoomRankingScreen(),
                OverallRankingScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContributionRankingScreen extends StatelessWidget {
  const ContributionRankingScreen({super.key});

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

class CharmRankingScreen extends StatelessWidget {
  const CharmRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "CHARM",
      field: "princeXP",
      subtitle: "TOP RECEIVERS",
      accentColor: const Color(0xFF8BC6EC),
    );
  }
}

class RoomRankingScreen extends StatelessWidget {
  const RoomRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "LIVE ROOMS",
      field: "activeUsers",
      subtitle: "MOST POPULAR",
      accentColor: const Color(0xFF2DD4BF),
      isRoom: true,
      collection: "rooms",
    );
  }
}

class OverallRankingScreen extends StatelessWidget {
  const OverallRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseRankingScreen(
      title: "GLOBAL BEST",
      field: "totalXP",
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

  const _BaseRankingScreen({
    required this.title,
    required this.field,
    required this.subtitle,
    required this.accentColor,
    this.isRoom = false,
    this.collection = "users",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            Text(subtitle, style: TextStyle(color: accentColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
      ),
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
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemBuilder: (context, index) {
              final data = items[index].data() as Map<String, dynamic>;
              return _RankingItem(
                rank: index + 1,
                name: isRoom ? (data['name'] ?? 'Room') : (data['displayName'] ?? "User"),
                subText: isRoom ? "Room ID: ${items[index].id.substring(0, 6)}" : "@${data['username'] ?? 'user'}",
                photoUrl: isRoom ? (data['coverUrl'] ?? "") : (data['profilePhotoUrl'] ?? ""),
                score: (data[field] ?? 0).toString(),
                accentColor: accentColor,
                countryCode: isRoom ? null : (data['countryCode'] ?? "US"),
                scoreLabel: isRoom ? "AUDIENCE" : (field == "benchXP" ? "SENT" : (field == "princeXP" ? "RCVD" : "XP")),
              ).animate().fadeIn(delay: Duration(milliseconds: (index * 40).clamp(0, 1000))).slideX(begin: 0.1);
            },
          );
        },
      ),
    );
  }
}

class _RankingItem extends StatelessWidget {
  final int rank;
  final String name;
  final String subText;
  final String photoUrl;
  final String score;
  final Color accentColor;
  final String? countryCode;
  final String scoreLabel;

  const _RankingItem({
    required this.rank,
    required this.name,
    required this.subText,
    required this.photoUrl,
    required this.score,
    required this.accentColor,
    this.countryCode,
    required this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color getRankColor() {
      if (rank == 1) return const Color(0xFFFFD700);
      if (rank == 2) return const Color(0xFFE2E8F0);
      if (rank == 3) return const Color(0xFFCD7F32);
      return Colors.white10;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: rank <= 3 ? Border.all(color: getRankColor().withOpacity(0.3), width: 1.5) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text("$rank", style: TextStyle(color: rank <= 3 ? getRankColor() : Colors.white24, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF334155),
                backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
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
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(subText, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(scoreLabel, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
