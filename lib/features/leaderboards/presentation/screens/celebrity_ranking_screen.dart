import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../../../core/utils/badge_utils.dart';
import '../../../../utils/number_formatter.dart';
import '../../../../core/models/user_model.dart';

class CelebrityRankingScreen extends ConsumerStatefulWidget {
  const CelebrityRankingScreen({super.key});

  @override
  ConsumerState<CelebrityRankingScreen> createState() => _CelebrityRankingScreenState();
}

class _CelebrityRankingScreenState extends ConsumerState<CelebrityRankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _timeFilter = "DAILY";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A0A), Color(0xFF0F0F0F), Colors.black],
          ),
        ),
        child: Stack(
          children: [
            // Immersive Royal Background
            Positioned.fill(child: _buildRoyalBackground()),
            
            Column(
              children: [
                _buildAppBar(),
                _buildTabs(),
                _buildTimeFilters(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRankingContent("benchXP"),
                      _buildRankingContent("princeXP"),
                      _buildRankingContent("activeUsers", isRoom: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoyalBackground() {
    return Stack(
      children: [
        // Top Light Flare
        Positioned(
          top: -100, left: 0, right: 0,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [const Color(0xFFFFD700).withOpacity(0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        // Subtle Particle Layer
        ...List.generate(30, (i) => Positioned(
          top: math.Random().nextDouble() * 800,
          left: math.Random().nextDouble() * 400,
          child: Container(
            width: 1.5, height: 1.5,
            decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).moveY(begin: 0, end: -200, duration: (3 + i % 5).seconds).fade(begin: 0, end: 0.8),
        )),
      ],
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            const Column(
              children: [
                Text("CELEBRITY RANKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                Text("LEGENDS ONLY", style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ],
            ),
            IconButton(icon: const Icon(Icons.info_outline, color: Colors.white54, size: 24), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: const Color(0xFFFFD700),
        indicatorWeight: 3,
        labelColor: const Color(0xFFFFD700),
        unselectedLabelColor: Colors.white24,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
        tabs: const [Tab(text: "CONTRIBUTION"), Tab(text: "CHARM"), Tab(text: "ROOM")],
      ),
    );
  }

  Widget _buildTimeFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ["DAILY", "WEEKLY", "MONTHLY"].map((f) {
          final isSelected = _timeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _timeFilter = f),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 10)] : null,
              ),
              child: Text(f, style: TextStyle(color: isSelected ? Colors.black : Colors.white38, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingContent(String baseField, {bool isRoom = false}) {
    String field = baseField;
    if (!isRoom) {
      if (baseField == "benchXP") {
        field = _timeFilter == "DAILY" ? "dailyXP" : _timeFilter == "WEEKLY" ? "weeklyXP" : _timeFilter == "MONTHLY" ? "monthlyXP" : "benchXP";
      } else if (baseField == "princeXP") {
        field = _timeFilter == "DAILY" ? "dailyPrinceXP" : _timeFilter == "WEEKLY" ? "weeklyPrinceXP" : _timeFilter == "MONTHLY" ? "monthlyPrinceXP" : "princeXP";
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(isRoom ? 'rooms' : 'users')
          .orderBy(field, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || (snapshot.hasData && snapshot.data!.docs.isEmpty)) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(isRoom ? 'rooms' : 'users').limit(50).snapshots(),
            builder: (ctx, fallbackSnap) {
              if (fallbackSnap.hasError || !fallbackSnap.hasData) {
                return const Center(child: Text("Waiting for Legends...", style: TextStyle(color: Colors.white24)));
              }
              final fallbackDocs = List<QueryDocumentSnapshot>.from(fallbackSnap.data!.docs);
              fallbackDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aScore = (aData[field] as num?) ?? (aData['xp'] as num?) ?? (aData['level'] as num?) ?? 0;
                final bScore = (bData[field] as num?) ?? (bData['xp'] as num?) ?? (bData['level'] as num?) ?? 0;
                return bScore.compareTo(aScore);
              });
              return _buildRankingViewWithDocs(fallbackDocs, field, isRoom: isRoom);
            },
          );
        }

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        final docs = snapshot.data!.docs;
        return _buildRankingViewWithDocs(docs, field, isRoom: isRoom);
      },
    );
  }

  Widget _buildRankingViewWithDocs(List<QueryDocumentSnapshot> docs, String field, {required bool isRoom}) {
    if (docs.isEmpty) return const Center(child: Text("Waiting for Legends...", style: TextStyle(color: Colors.white24)));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // PRESTIGIOUS PODIUM SECTION
        SliverToBoxAdapter(
          child: Container(
            height: 420,
            padding: const EdgeInsets.only(top: 20),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // TOP 2 (Left)
                if (docs.length > 1) Positioned(
                  left: MediaQuery.of(context).size.width * 0.05,
                  top: 120,
                  child: _buildPodiumItem(rank: 2, doc: docs[1], field: field, isRoom: isRoom).animate().fadeIn().slideX(begin: -0.2),
                ),
                
                // TOP 3 (Right)
                if (docs.length > 2) Positioned(
                  right: MediaQuery.of(context).size.width * 0.05,
                  top: 140,
                  child: _buildPodiumItem(rank: 3, doc: docs[2], field: field, isRoom: isRoom).animate().fadeIn().slideX(begin: 0.2),
                ),

                // TOP 1 (Center) - Pushed High
                Positioned(
                   top: 20,
                   child: _buildPodiumItem(rank: 1, doc: docs[0], field: field, isRoom: isRoom).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                ),
              ],
            ),
          ),
        ),

        // RANKED LIST 4+
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildListTile(index + 4, docs[index+3], field, isRoom: isRoom),
              childCount: math.max(0, docs.length - 3),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPodiumItem({required int rank, required QueryDocumentSnapshot doc, required String field, required bool isRoom}) {
    final data = doc.data() as Map<String, dynamic>;
    final photoUrl = isRoom ? (data['coverUrl'] ?? "") : (data['profilePhotoUrl'] ?? "");
    final name = isRoom ? (data['name'] ?? "Room") : (data['displayName'] ?? "User");
    final scoreNum = (data[field] ?? 0);
    final score = formatCount(scoreNum is num ? scoreNum.toInt() : 0);
    final is1 = rank == 1;

    Color rankColor = is1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFE2E8F0) : const Color(0xFFF9A8D4));
    double avatarSize = is1 ? 130 : 95;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ROYAL LIGHT SHURIKEN (Rotating behind Rank 1)
            if (is1) Positioned(
               child: Container(
                 width: 240, height: 240,
                 decoration: BoxDecoration(
                   gradient: RadialGradient(colors: [rankColor.withOpacity(0.2), Colors.transparent]),
                 ),
               ).animate(onPlay: (c) => c.repeat()).rotate(duration: 10.seconds),
            ),

            // ANGELIC WINGS
            if (is1) Positioned(
              child: Opacity(
                opacity: 0.7,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_motion_rounded, size: 100, color: rankColor),
                    const SizedBox(width: 140),
                    Transform.flip(flipX: true, child: Icon(Icons.auto_awesome_motion_rounded, size: 100, color: rankColor)),
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 2.seconds),

            // GOLDEN FRAME
            Container(
              width: avatarSize + 16, height: avatarSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [rankColor, Colors.transparent, rankColor]),
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 5.seconds),

            // AVATAR
            Container(
              width: avatarSize, height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                image: photoUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(photoUrl), fit: BoxFit.cover) : null,
              ),
              child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white24, size: 50) : null,
            ),

            // CROWN
            if (is1) Positioned(
               top: -50,
               child: const Icon(Icons.workspace_premium_rounded, size: 60, color: Color(0xFFFFD700)).animate(onPlay: (c) => c.repeat()).shimmer().shake(),
            ),

            // RANK BANNER
            Positioned(
              bottom: -20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rankColor, width: 1),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Text("NO.$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 35),
        Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: is1 ? 18 : 14, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
        const SizedBox(height: 4),
        if (!isRoom) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: getBadgesForUser(UserModel.fromMap({...data, 'uid': doc.id})).map((b) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Transform.scale(scale: 0.6, child: b),
              )).toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: rankColor.withOpacity(0.2))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(score, style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: is1 ? 16 : 12)),
              const SizedBox(width: 4),
              Icon(Icons.diamond_rounded, color: rankColor, size: is1 ? 16 : 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(int rank, QueryDocumentSnapshot doc, String field, {required bool isRoom}) {
    final data = doc.data() as Map<String, dynamic>;
    final photoUrl = isRoom ? (data['coverUrl'] ?? "") : (data['profilePhotoUrl'] ?? "");
    final name = isRoom ? (data['name'] ?? "Room") : (data['displayName'] ?? "User");
    final scoreNum = (data[field] ?? 0);
    final score = formatCount(scoreNum is num ? scoreNum.toInt() : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text("$rank", style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 18))),
          CircleAvatar(
            radius: 26,
            backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                if (!isRoom) ...[
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: getBadgesForUser(UserModel.fromMap({...data, 'uid': doc.id})).map((b) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Transform.scale(scale: 0.5, child: b),
                      )).toList(),
                    ),
                  ),
                ],
                Text("@${data['username'] ?? 'user'}", style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(score, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(width: 2),
                  const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 14),
                ],
              ),
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFDC2626), size: 14),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (rank * 10).ms).slideX(begin: 0.1, curve: Curves.easeOutBack);
  }
}
