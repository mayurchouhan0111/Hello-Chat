import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/reward_model.dart';
import '../../../../core/providers/profile_provider.dart';

// ─────────────────────────────────────────────────────────────
//  ASSET PATHS
// ─────────────────────────────────────────────────────────────
class _RocketAssets {
  static const rewardPanelUi   = 'assets/images/rocket_reward/ui_reward_panel.png';
  static const rankingPanelUi  = 'assets/images/rocket_reward/ui_ranking_panel.png';
  static const iconCoin        = 'assets/images/rocket_reward/icon_coin.png';
}

// ─────────────────────────────────────────────────────────────
//  REWARD SECTION
// ─────────────────────────────────────────────────────────────

class RewardSection extends StatelessWidget {
  final RocketRewardState rewardState;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;

  const RewardSection({
    super.key,
    required this.rewardState,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rewards = rewardState.tabRewards[selectedTab] ?? [];
    final amount1 = rewards.isNotEmpty ? rewards[0].amount : 30000;
    final amount2 = rewards.length > 1 ? rewards[1].amount : 2000;
    final dur3 = rewards.length > 2 ? (rewards[2].duration ?? '24h') : '24h';

    final pill1 = _formatCoinPill(amount1);
    final pill2 = _formatExpPill(amount2);
    final pill3 = dur3.contains('72') ? '72h' : '24h';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCC00FF).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC00FF).withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Aspect ratio: 1376 / 768 = 1.7916
          final height = width / 1.7916;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Ultra High-Res Master Artwork
                    Positioned.fill(
                      child: Image.asset(
                        _RocketAssets.rewardPanelUi,
                        fit: BoxFit.fill,
                      ),
                    ),

                  // 2. Interactive Tabs
                  // Tab 1: Room Owner
                  Positioned(
                    left: width * 0.168,
                    top: height * 0.285,
                    width: width * 0.158,
                    height: height * 0.085,
                    child: _buildTabHitArea('Room Owner', width, height),
                  ),
                  // Tab 2: TOP 1
                  Positioned(
                    left: width * 0.336,
                    top: height * 0.285,
                    width: width * 0.158,
                    height: height * 0.085,
                    child: _buildTabHitArea('TOP 1', width, height),
                  ),
                  // Tab 3: TOP 2
                  Positioned(
                    left: width * 0.504,
                    top: height * 0.285,
                    width: width * 0.158,
                    height: height * 0.085,
                    child: _buildTabHitArea('TOP 2', width, height),
                  ),
                  // Tab 4: TOP 3
                  Positioned(
                    left: width * 0.672,
                    top: height * 0.285,
                    width: width * 0.158,
                    height: height * 0.085,
                    child: _buildTabHitArea('TOP 3', width, height),
                  ),

                  // 3. Dynamic Crisp Badges inside the 3 red circular base medals
                  // Card 1 Badge (Coins e.g. 30K)
                  Positioned(
                    left: width * 0.337 - (height * 0.09),
                    top: height * 0.775 - (height * 0.045),
                    width: height * 0.18,
                    height: height * 0.09,
                    child: Center(
                      child: Text(
                        pill1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: height * 0.042,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),

                  // Card 2 Badge (EXP e.g. 2K EXP)
                  Positioned(
                    left: width * 0.575 - (height * 0.09),
                    top: height * 0.775 - (height * 0.045),
                    width: height * 0.18,
                    height: height * 0.09,
                    child: Center(
                      child: Text(
                        pill2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: height * 0.035,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),

                  // Card 3 Badge (Frame Duration e.g. 24h)
                  Positioned(
                    left: width * 0.812 - (height * 0.09),
                    top: height * 0.775 - (height * 0.045),
                    width: height * 0.18,
                    height: height * 0.09,
                    child: Center(
                      child: Text(
                        pill3,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: height * 0.042,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  }

  Widget _buildTabHitArea(String tab, double w, double h) {
    final isSelected = tab == selectedTab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTabChanged(tab),
      child: isSelected
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h * 0.045),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDF60), Color(0xFFFFB800), Color(0xFFD67600)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: const Color(0xFFFFF6B8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF4A1000),
                    fontSize: h * 0.038,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }

  String _formatCoinPill(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return '$amount';
  }

  String _formatExpPill(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(0)}K EXP';
    return '$xp EXP';
  }
}

// ─────────────────────────────────────────────────────────────
//  RANKING SECTION
// ─────────────────────────────────────────────────────────────

class RankingSection extends StatelessWidget {
  final List<RankingModel> rankings;
  final bool isLoading;
  final String? error;

  const RankingSection({
    super.key,
    this.rankings = const [],
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = List<RankingModel>.generate(3, (i) {
      return i < rankings.length ? rankings[i] : RankingModel(rank: i + 1);
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Aspect ratio: 1376 / 768 = 1.7916
          final height = width / 1.7916;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Ultra High-Res Master Artwork
                    Positioned.fill(
                      child: Image.asset(
                        _RocketAssets.rankingPanelUi,
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 2. TOP 2 (Left Avatar)
                    if (top3[1].userId != null && top3[1].userId!.isNotEmpty)
                      Positioned(
                        left: width * 0.243 - (height * 0.105),
                        top: height * 0.525 - (height * 0.105),
                        width: height * 0.210,
                        height: height * 0.210,
                        child: _AvatarPortal(ranking: top3[1]),
                      ),

                    // 3. TOP 1 (Center Avatar - Elevated)
                    if (top3[0].userId != null && top3[0].userId!.isNotEmpty)
                      Positioned(
                        left: width * 0.500 - (height * 0.118),
                        top: height * 0.495 - (height * 0.118),
                        width: height * 0.236,
                        height: height * 0.236,
                        child: _AvatarPortal(ranking: top3[0]),
                      ),

                    // 4. TOP 3 (Right Avatar)
                    if (top3[2].userId != null && top3[2].userId!.isNotEmpty)
                      Positioned(
                        left: width * 0.757 - (height * 0.105),
                        top: height * 0.580 - (height * 0.105),
                        width: height * 0.210,
                        height: height * 0.210,
                        child: _AvatarPortal(ranking: top3[2]),
                      ),
                  ],
                ),
              ),

              // Contributor Details (Name & Coins) below the 3 podium stands
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: _PodiumDetails(ranking: top3[1])),
                    Expanded(child: _PodiumDetails(ranking: top3[0])),
                    Expanded(child: _PodiumDetails(ranking: top3[2])),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarPortal extends ConsumerWidget {
  final RankingModel ranking;

  const _AvatarPortal({required this.ranking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String avatarUrl = ranking.avatarUrl ?? '';
    final userId = ranking.userId;

    if (userId != null && userId.isNotEmpty && avatarUrl.isEmpty) {
      final profile = ref.watch(userProfileProvider(userId)).value;
      if (profile != null) {
        avatarUrl = profile.profilePhotoUrl;
      }
    }

    if (avatarUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PodiumDetails extends ConsumerWidget {
  final RankingModel ranking;

  const _PodiumDetails({required this.ranking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String name = ranking.username ?? '-';
    int score = ranking.score;
    final userId = ranking.userId;

    if (userId != null && userId.isNotEmpty) {
      final profile = ref.watch(userProfileProvider(userId)).value;
      if (profile != null) {
        name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        const Gap(2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _RocketAssets.iconCoin,
              height: 12,
              width: 12,
              errorBuilder: (_, __, ___) => const Text('🪙', style: TextStyle(fontSize: 9)),
            ),
            const Gap(3),
            Text(
              score > 0 ? _fmt(score) : '0',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
