import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/utils/badge_utils.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../utils/number_formatter.dart';

class ContributionRankingScreen extends ConsumerStatefulWidget {
  const ContributionRankingScreen({super.key});

  @override
  ConsumerState<ContributionRankingScreen> createState() => _ContributionRankingScreenState();
}

class _ContributionRankingScreenState extends ConsumerState<ContributionRankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RankingList(filter: 'daily'),
              _RankingList(filter: 'weekly'),
              _RankingList(filter: 'monthly'),
              _RankingList(filter: 'overall'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey[300]!,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: "Daily"),
          Tab(text: "Weekly"),
          Tab(text: "Monthly"),
          Tab(text: "Overall"),
        ],
      ),
    );
  }
}

class _RankingList extends ConsumerWidget {
  final String filter;
  const _RankingList({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We'll use benchXP for contribution as per existing logic, or a specific field if available
    final field = filter == 'daily' ? 'dailyXP' : 
                  filter == 'weekly' ? 'weeklyXP' : 
                  filter == 'monthly' ? 'monthlyXP' : 'benchXP';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(field, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No rankings found yet", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final user = UserModel.fromMap({...data, 'uid': doc.id});
            final score = data[field] ?? 0;

            return _RankingTile(index: index + 1, user: user, score: score);
          },
        );
      },
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _RankingTile extends StatelessWidget {
  final int index;
  final UserModel user;
  final dynamic score;

  const _RankingTile({
    required this.index,
    required this.user,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.userProfile, extra: user.uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
          // Rank
          SizedBox(
            width: 32,
            child: _buildRankBadge(),
          ),
          const Gap(8),
          // Avatar
          SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: AppAvatar(
                imageUrl: user.profilePhotoUrl,
                frameUrl: user.profileFrame,
                vipTier: user.vipTier,
                userLevel: user.level,
                tags: user.tags,
                radius: 25,
                showFrame: true,
                frameMultiplier: 1.6,
              ),
            ),
          ),
          const Gap(12),
          // Info Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(4),
                    Icon(
                      user.gender.toLowerCase() == 'male' ? Icons.male_rounded : Icons.female_rounded,
                      color: user.gender.toLowerCase() == 'male' ? Colors.blue : Colors.pink,
                      size: 14,
                    ),
                  ],
                ),
                const Gap(4),
                // Badge Row: User Badges from Utility
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatBadge(
                        icon: Icons.monetization_on_rounded,
                        color: Colors.amber[600]!,
                        value: formatCount(score is num ? score.toInt() : 0),
                      ),
                      const Gap(4),
                      ...getBadgesForUser(user).map((b) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Transform.scale(scale: 0.7, child: b),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildRankBadge() {
    if (index <= 3) {
      final color = index == 1 ? const Color(0xFFFFD700) : (index == 2 ? const Color(0xFF94A3B8) : const Color(0xFFB45309));
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.workspace_premium_rounded, color: color, size: 24),
            Text(
              "$index",
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    return Text(
      "$index",
      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 16),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatBadge({required IconData icon, required Color color, required String value, bool isDiamond = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const Gap(3),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildTagBadge(String label, {required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}
