import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/utils/level_utils.dart';

class LevelDetailScreen extends ConsumerWidget {
  const LevelDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
        error: (err, _) => Center(
          child: Text("Error: $err", style: const TextStyle(color: Color(0xFFEF4444))),
        ),
        data: (user) {
          if (user == null) return const Center(child: Text("No user data"));

          final calculatedLevel = LevelUtils.calculateLevel(user.xp);
          final progress = LevelUtils.getLevelProgress(user.xp);
          final progressPercent = (progress * 100).toStringAsFixed(1);
          final levelColor = LevelUtils.getLevelColor(calculatedLevel);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                // 1. Hero Level Status Card
                _buildHeroLevelCard(context, user, progress, progressPercent, levelColor, calculatedLevel),

                const Gap(20),

                // 2. XP Earning Channels (How to Level Up)
                _buildXPEarningCards(),

                const Gap(20),

                // 3. Medal Showcase (Rank Badges)
                _buildMedalRewardSection(calculatedLevel),

                const Gap(20),

                // 4. XP Brackets Table
                _buildXPBracketsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 15),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "Level System",
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 16),
          ),
          onPressed: () {},
          tooltip: 'Level Ranks',
        ),
        const Gap(6),
      ],
    );
  }

  // ─── 1. Hero Level Status Card ─────────────────────────────────
  Widget _buildHeroLevelCard(
    BuildContext context,
    dynamic user,
    double progress,
    String percent,
    Color levelColor,
    int calculatedLevel,
  ) {
    final xpStart = LevelUtils.getTotalXPForLevel(calculatedLevel);
    final xpNext = LevelUtils.getTotalXPForLevel(calculatedLevel + 1);
    final currentLevelXP = user.xp - xpStart;
    final neededXP = xpNext - xpStart;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar + Frame Stack
          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 46,
            frameUrl: user.profileFrame,
            userLevel: calculatedLevel,
            frameMultiplier: 1.6,
          ),

          const Gap(16),

          // Level Shield & Title
          _buildLevelShield(calculatedLevel),

          const Gap(16),

          // Percentage & Progress Track
          Column(
            children: [
              // Progress Bar
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0284C7), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Gap(10),

              // Level Numbers & XP Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Lv$calculatedLevel",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    "${_formatNumber(currentLevelXP)} / ${_formatNumber(neededXP)} XP ($percent%)",
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Lv${(calculatedLevel + 1).clamp(1, 100)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB45309),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelShield(int level) {
    int index = 0;
    if (level >= 80) {
      index = 5;
    } else if (level >= 50) {
      index = 4;
    } else if (level >= 30) {
      index = 3;
    } else if (level >= 20) {
      index = 2;
    } else if (level >= 10) {
      index = 1;
    } else {
      index = 0;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          "assets/images/levels/level_badge_$index.png",
          width: 38,
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 30),
        ),
        const Gap(8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Level $level Master",
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              _getTierTitle(level),
              style: TextStyle(
                color: LevelUtils.getLevelColor(level),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getTierTitle(int level) {
    if (level >= 90) return "★ Supreme Emperor Tier";
    if (level >= 70) return "♦ Grandmaster Tier";
    if (level >= 50) return "▲ Diamond Elite Tier";
    if (level >= 30) return "● Platinum Veteran Tier";
    if (level >= 15) return "■ Gold Challenger Tier";
    return "● Bronze Adventurer Tier";
  }

  // ─── 2. XP Earning Cards (How to Level Up) ─────────────────────
  Widget _buildXPEarningCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("HOW TO EARN XP", Icons.bolt_rounded),
          const Gap(12),
          Row(
            children: [
              // Sending Gifts
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFBCFE8), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDF2F8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFDB2777), size: 22),
                      ),
                      const Gap(8),
                      const Text(
                        "Sending Gifts",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(3),
                      const Text(
                        "500 💎 = 1 XP",
                        style: TextStyle(
                          color: Color(0xFFDB2777),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              // Receiving Gifts
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F3FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const Gap(8),
                      const Text(
                        "Receiving Gifts",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Gap(3),
                      const Text(
                        "1,000 💎 = 1 XP",
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Medal Rewards Section ───────────────────────────────────
  Widget _buildMedalRewardSection(int currentLevel) {
    final medalLevels = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("MEDAL REWARDS", Icons.military_tech_rounded),
          const Gap(12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: medalLevels.map((lv) {
                final isUnlocked = currentLevel >= lv;
                return _buildMedalChip(lv, isUnlocked);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalChip(int level, bool isUnlocked) {
    int index = LevelUtils.getLevelBadgeIndex(level);

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/images/levels_new/level_badge_$index.webp",
                width: 72,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 28),
              ),
              Positioned(
                bottom: 12,
                child: Text(
                  "Lv$level",
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Gap(4),
          Text(
            isUnlocked ? "UNLOCKED" : "LOCKED",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: isUnlocked ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. XP Brackets Table ───────────────────────────────────────
  Widget _buildXPBracketsSection() {
    final rules = [
      {'range': 'Lv.1 - 10', 'xp': '10K XP'},
      {'range': 'Lv.10 - 20', 'xp': '25K XP'},
      {'range': 'Lv.20 - 30', 'xp': '50K XP'},
      {'range': 'Lv.30 - 40', 'xp': '100K XP'},
      {'range': 'Lv.40 - 50', 'xp': '200K XP'},
      {'range': 'Lv.50 - 60', 'xp': '300K XP'},
      {'range': 'Lv.60 - 70', 'xp': '400K XP'},
      {'range': 'Lv.70 - 80', 'xp': '500K XP'},
      {'range': 'Lv.80 - 90', 'xp': '600K XP'},
      {'range': 'Lv.90 - 100', 'xp': '1.0M XP'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("XP REQUIREMENTS PER TIER", Icons.timeline_rounded),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                ...rules.map((rule) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trending_up_rounded, color: Color(0xFF0284C7), size: 16),
                            const Gap(8),
                            Text(
                              rule['range']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${rule['xp']} / Level",
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Gap(12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                    Gap(6),
                    Text(
                      "Maximum profile level cap is Level 100",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Icon(icon, size: 16, color: const Color(0xFF0284C7)),
        const Gap(6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
