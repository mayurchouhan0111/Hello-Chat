import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/app_button.dart';

class RoomStarProgressWidget extends StatelessWidget {
  final RoomModel room;

  const RoomStarProgressWidget({super.key, required this.room});

  // Thresholds
  static const List<int> thresholds = [0, 1000, 10000, 50000, 100000, 250000];

  int get currentLevel => room.currentStarLevel;

  Color getLevelColor(int level) {
    switch (level) {
      case 0: return const Color(0xFF6B7280); // Neutral Grey
      case 1: return const Color(0xFF00E5FF); // Cyan
      case 2: return const Color(0xFF00C853); // Green
      case 3: return const Color(0xFF9C27B0); // Purple
      case 4: return const Color(0xFFFF4081); // Pink
      case 5: return const Color(0xFFFFD700); // Gold
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = currentLevel;
    final color = getLevelColor(level);

    return _buildLevelButton(context, level, color);
  }

  Widget _buildLevelButton(BuildContext context, int level, Color color) {
    final isZero = level == 0;
    return GestureDetector(
      onTap: () => _showLevelsOverlay(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isZero
                ? [const Color(0xFF4B5563), const Color(0xFF374151)]
                : [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isZero
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 2,
                    spreadRadius: -1,
                    offset: const Offset(0, 1),
                  ),
                ],
          border: Border.all(
            color: isZero ? Colors.white12 : Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: isZero ? Colors.white38 : Colors.white,
                  size: 14,
                ),
                const Gap(4),
                Text(
                  "$level Star",
                  style: TextStyle(
                    color: isZero ? Colors.white60 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: isZero
                        ? null
                        : const [
                            Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(key: ValueKey(level)).scale(duration: 300.ms);
  }

  void _showLevelsOverlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: 320,
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
              const Gap(6),
              const Text(
                "⭐ Resets to 0 Stars after 24 hours without carry-over",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Gap(16),
              // Level 0
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.star_outline_rounded, color: Color(0xFF6B7280), size: 20),
                    Gap(12),
                    Text("0 Star (Default)", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    Spacer(),
                    Text("0", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    Gap(4),
                    PremiumDiamond(size: 10),
                  ],
                ),
              ),
              ...List.generate(5, (index) {
                final l = index + 1;
                final c = getLevelColor(l);
                final t = thresholds[l];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: c, size: 20),
                      const Gap(12),
                      Text("Star $l", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text("$t", style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
}
