import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/app_button.dart';

class RoomStarProgressWidget extends StatelessWidget {
  final RoomModel room;

  const RoomStarProgressWidget({super.key, required this.room});

  // Thresholds
  static const List<int> thresholds = [0, 1000, 10000, 50000, 100000, 250000];

  int get currentLevel {
    final diamonds = room.weeklyEarnings;
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (diamonds >= thresholds[i]) return i;
    }
    return 0;
  }

  Color getLevelColor(int level) {
    switch (level) {
      case 0: return Colors.white54;
      case 1: return const Color(0xFF00E5FF); // Cyan
      case 2: return const Color(0xFF00C853); // Green
      case 3: return const Color(0xFF9C27B0); // Purple
      case 4: return const Color(0xFFFF4081); // Pink
      case 5: return const Color(0xFFFFD700); // Gold
      default: return const Color(0xFFFFD700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = currentLevel;
    final color = getLevelColor(level);

    return _buildLevelButton(context, level, color);
  }

  Widget _buildLevelButton(BuildContext context, int level, Color color) {
    return GestureDetector(
      onTap: () => _showLevelsOverlay(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: color, size: 14),
            const Gap(2),
            Text(
              "$level",
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ).animate(key: ValueKey(level)).scale(duration: 300.ms);
  }

  void _showLevelsOverlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Star Levels", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Gap(20),
              ...List.generate(5, (index) {
                final l = index + 1;
                final c = getLevelColor(l);
                final t = thresholds[l];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: c, size: 20),
                      const Gap(12),
                      Text("Star $l", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text("$t", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const Gap(4),
                      const PremiumDiamond(size: 10),
                    ],
                  ),
                );
              }),
              const Gap(16),
              AppButton(text: "Close", onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBoxTap() {
    // Logic for fully opening the box
  }
}
