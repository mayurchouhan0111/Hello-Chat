import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/utils/level_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

          final progress = LevelUtils.getLevelProgress(user.xp);
          final progressPercent = (progress * 100).toStringAsFixed(1);
          final levelColor = LevelUtils.getLevelColor(user.level);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Top Section (Avatar & Progress)
                _buildTopSection(context, user, progress, progressPercent, levelColor),

                const Gap(32),

                // 2. Medal Reward
                _buildMedalRewardSection(),

                const Gap(40),

                // 3. Pendant Reward
                // _buildPendantRewardSection(),

                const Gap(40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, user, double progress, String percent, Color levelColor) {
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
            frameMultiplier: 1.8,
          ),
          const Gap(12),
          // Level Badge Shield
          _buildLevelShield(user.level),
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
                      "Lv${user.level}",
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
    final medals = [1, 11, 23, 34, 45, 56, 67, 78, 89, 100];

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
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.1)),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: medals.map((lv) => _buildLevelChip(lv)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelChip(int level) {
    final color = LevelUtils.getLevelColor(level);
    int index = LevelUtils.getLevelBadgeIndex(level);

    return Container(
      width: 70,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                "assets/images/levels/level_badge_$index.png",
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              Positioned(
                bottom: 10,
                child: Text(
                  "Lv$level",
                  style: const TextStyle(
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
    int index = LevelUtils.getLevelBadgeIndex(level);
    return Container(
      height: 80,
      width: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            "assets/images/levels/level_badge_$index.png",
            fit: BoxFit.contain,
          ),
          Positioned(
            bottom: 18,
            child: Text(
              "Lv.$level",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ],
      ),
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
