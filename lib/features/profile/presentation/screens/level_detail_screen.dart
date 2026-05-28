import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/utils/level_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelDetailScreen extends ConsumerWidget {
  const LevelDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Level",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (user) {
          if (user == null) return const Center(child: Text("No user data"));

          final calculatedLevel = LevelUtils.calculateLevel(user.xp);
          final progress = LevelUtils.getLevelProgress(user.xp);
          final progressPercent = (progress * 100).toStringAsFixed(1);
          final levelColor = LevelUtils.getLevelColor(calculatedLevel);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Top Section (Avatar & Progress)
                _buildTopSection(context, user, progress, progressPercent, levelColor, calculatedLevel),

                const Gap(32),

                // 2. Medal Reward
                _buildMedalRewardSection(),

                const Gap(32),

                // 3. XP Rules & Level Up Guide
                _buildXPRulesSection(),

                const Gap(40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, user, double progress, String percent, Color levelColor, int calculatedLevel) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE0F7FA).withOpacity(0.5),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          const Gap(20),
          // Avatar
          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 50,
            frameUrl: user.profileFrame,
            userLevel: calculatedLevel,
            frameMultiplier: 1.8,
          ),
          const Gap(12),
          // Level Badge Shield
          _buildLevelShield(calculatedLevel),
          const Gap(24),
          
          // Progress Bar with Percentage Bubble
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Percentage Bubble
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    const Gap(30),
                    Align(
                      alignment: Alignment(progress * 2 - 1, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4DD0E1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$percent%",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(10, 5),
                            painter: TrianglePainter(color: const Color(0xFF4DD0E1)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                // The Bar
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4DD0E1), Color(0xFF00ACC1)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                // Level Labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Lv$calculatedLevel",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                    ),
                    Text(
                      LevelUtils.getXPProgressText(user.xp),
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
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

  Widget _buildMedalRewardSection() {
    final medals = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

    return Column(
      children: [
        const Text(
          "Medal Reward",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(8),
        const Text(
          "The higher your level is, the cooler medal you'll get.",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(24),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.1)),
          ),
          child: Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: medals.map((lv) => _buildLevelChip(lv)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelChip(int level) {
    final color = LevelUtils.getLevelColor(level);
    int index = LevelUtils.getLevelBadgeIndex(level);

    return Container(
      width: 100,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/images/levels_new/level_badge_$index.webp",
                width: 80,
                height: 40,
                fit: BoxFit.contain,
              ),
              Positioned(
                bottom: 14,
                child: Text(
                  "Lv$level",
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForLevel(int level) {
    if (level >= 90) return Icons.star;
    if (level >= 80) return Icons.workspace_premium;
    if (level >= 70) return Icons.military_tech;
    if (level >= 50) return Icons.stars;
    return Icons.diamond;
  }

  Widget _buildPendantRewardSection() {
    final pendants = [
      {'range': '56-66', 'color': 'silver'},
      {'range': '67-77', 'color': 'gold'},
      {'range': '78-90', 'color': 'shiny_gold'},
      {'range': '91-95', 'color': 'red_royal'},
      {'range': '96-100', 'color': 'emperor'},
    ];

    return Column(
      children: [
        const Text(
          "Pendant reward",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(8),
        const Text(
          "The higher your level is, the more honorable pendant you'll get.",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 20,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: pendants.map((p) => _buildPendantItem(p['range']!, p['color']!)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPendantItem(String range, String type) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Image.network(
                  "https://picsum.photos/seed/$range/100",
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              // Frame Placeholder - using icons or containers to mimic the look
              _buildMockFrame(type),
            ],
          ),
        ),
        const Gap(12),
        Text(
          "Level $range",
          style: const TextStyle(color: Color(0xFF4DD0E1), fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMockFrame(String type) {
    Color frameColor;
    double thickness = 4;
    IconData? topIcon;
    
    switch (type) {
      case 'silver':
        frameColor = const Color(0xFFB0BEC5);
        topIcon = Icons.star;
        break;
      case 'gold':
        frameColor = const Color(0xFFFFD700);
        topIcon = Icons.star;
        break;
      case 'shiny_gold':
        frameColor = const Color(0xFFFFA000);
        topIcon = Icons.stars;
        thickness = 6;
        break;
      case 'red_royal':
        frameColor = const Color(0xFFFF5252);
        topIcon = Icons.workspace_premium;
        thickness = 6;
        break;
      case 'emperor':
        frameColor = const Color(0xFFFFD54F);
        topIcon = Icons.auto_awesome;
        thickness = 8;
        break;
      default:
        frameColor = Colors.grey;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 85,
          height: 85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: frameColor, width: thickness),
            boxShadow: [
              BoxShadow(color: frameColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
            ],
          ),
        ),
        Positioned(
          top: -5,
          child: Icon(topIcon, color: frameColor, size: 24),
        ),
        if (type == 'emperor' || type == 'red_royal')
          Positioned(
            bottom: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: frameColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLevelShield(int level) {
    int index = 0;
    if (level >= 80) index = 5;
    else if (level >= 50) index = 4;
    else if (level >= 30) index = 3;
    else if (level >= 20) index = 2;
    else if (level >= 10) index = 1;
    else index = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          "assets/images/levels/level_badge_$index.png",
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
        const SizedBox(height: 4),
        Text(
          "Lv.$level",
          style: GoogleFonts.cinzel(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildXPRulesSection() {
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

    return Column(
      children: [
        const Text(
          "How to Level Up",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(8),
        const Text(
          "Earn XP by participating and interacting to boost your profile level.",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Gap(24),
        // 1. Diamonds to XP rate cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Sender Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF4081).withOpacity(0.08),
                        const Color(0xFFFF80AB).withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF4081).withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4081).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.outbox_rounded, color: Color(0xFFFF4081), size: 24),
                      ),
                      const Gap(10),
                      const Text(
                        "Sending Gifts",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const Gap(4),
                      Text(
                        "500 💎 = 1 XP",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFF4081),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(16),
              // Receiver Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9C27B0).withOpacity(0.08),
                        const Color(0xFFBA68C8).withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.move_to_inbox_rounded, color: Color(0xFF9C27B0), size: 24),
                      ),
                      const Gap(10),
                      const Text(
                        "Receiving Gifts",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const Gap(4),
                      Text(
                        "1,000 💎 = 1 XP",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF9C27B0),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(28),
        // 2. XP Brackets title
        const Text(
          "XP Required Per Level Up",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(16),
        // 3. Brackets list
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              ...rules.map((rule) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up_rounded, color: Colors.cyan[600], size: 18),
                          const Gap(8),
                          Text(
                            rule['range']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyan[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${rule['xp']} per level",
                          style: TextStyle(
                            color: Colors.cyan[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              Divider(color: Colors.grey[200]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                    const Gap(6),
                    Text(
                      "Maximum Level cap is exactly Level 100",
                      style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
