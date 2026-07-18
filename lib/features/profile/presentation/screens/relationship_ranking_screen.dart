import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/relationship_ranking_model.dart';
import '../../../../core/constants/app_colors.dart';

class RelationshipRankingScreen extends ConsumerStatefulWidget {
  final bool isCp;
  const RelationshipRankingScreen({super.key, this.isCp = false});

  @override
  ConsumerState<RelationshipRankingScreen> createState() => _RelationshipRankingScreenState();
}

class _RelationshipRankingScreenState extends ConsumerState<RelationshipRankingScreen> {
  RankingPeriod _selectedPeriod = RankingPeriod.allTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isCp ? "CP Ranking" : "Friendship Ranking",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: ref.watch(relationshipRankingsProvider(_selectedPeriod)).when(
              data: (rankings) {
                if (rankings.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.leaderboard_outlined, color: Colors.white24, size: 56),
                        Gap(16),
                        Text("No rankings yet", style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rankings.length,
                  itemBuilder: (context, index) => _RankingTile(
                    ranking: rankings[index],
                    rank: index + 1,
                    highlight: index < 3,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.diamond)),
              error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      (RankingPeriod.daily, "Daily"),
      (RankingPeriod.weekly, "Weekly"),
      (RankingPeriod.monthly, "Monthly"),
      (RankingPeriod.allTime, "All Time"),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.diamond.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: AppColors.diamond.withOpacity(0.3)) : null,
                ),
                child: Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? AppColors.diamond : Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RankingTile extends ConsumerWidget {
  final RelationshipRankingModel ranking;
  final int rank;
  final bool highlight;

  const _RankingTile({
    required this.ranking,
    required this.rank,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.diamond.withOpacity(0.05) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: highlight ? Border.all(color: AppColors.diamond.withOpacity(0.2)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              "#$rank",
              style: TextStyle(
                color: highlight ? AppColors.diamond : Colors.white54,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.participants.join(" ❤️ "),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Text(
                  "Lv.${ranking.level} · ${ranking.intimacy} intimacy",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (highlight)
            Icon(
              rank == 1 ? Icons.emoji_events : rank == 2 ? Icons.emoji_events : Icons.emoji_events,
              color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown,
              size: 20,
            ),
        ],
      ),
    );
  }
}
