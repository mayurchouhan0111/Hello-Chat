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
    final diamonds = room.weeklyEarnings;
    
    // Overall progress towards max level (250k)
    final double overallProgress = (diamonds / thresholds.last).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // 1. Level Button
          _buildLevelButton(context, level, color),
          
          const Gap(12),
          
          // 2. Progress Track
          Expanded(
            child: _buildProgressTrack(level, color, diamonds),
          ),
          
          const Gap(12),
          
          // 3. Gift Box
          _buildGiftBox(level, color, overallProgress),
        ],
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, int level, Color color) {
    return GestureDetector(
      onTap: () => _showLevelsOverlay(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: color, size: 16),
            const Gap(4),
            Text(
              "$level Star",
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate(key: ValueKey(level)).shimmer(duration: 2.seconds).scale(duration: 300.ms);
  }

  Widget _buildProgressTrack(int level, Color color, int diamonds) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Base Line
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        
        // Active Progress Line
        LayoutBuilder(
          builder: (context, constraints) {
            // Find current progress between nodes
            double progressRatio = 0;
            if (level < thresholds.length - 1) {
              final lower = thresholds[level];
              final upper = thresholds[level + 1];
              progressRatio = ((diamonds - lower) / (upper - lower)).clamp(0.0, 1.0);
            } else {
              progressRatio = 1.0;
            }

            // Total progress across 5 spans
            final double totalProgress = (level + progressRatio) / (thresholds.length - 1);

            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 2,
                width: constraints.maxWidth * totalProgress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.5), color]),
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 4),
                  ],
                ),
              ),
            );
          },
        ),

        // Node Stars
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final nodeLevel = index + 1;
            final isReached = level >= nodeLevel;
            final nodeColor = isReached ? getLevelColor(nodeLevel) : Colors.white24;
            
            final star = Icon(
              Icons.star_rounded,
              size: isReached ? 12 : 10,
              color: nodeColor,
            ).animate(target: isReached ? 1 : 0).scale(duration: 400.ms);
            
            return isReached ? star.shimmer(duration: 2.seconds) : star;
          }),
        ),
      ],
    );
  }

  Widget _buildGiftBox(int level, Color color, double progress) {
    // Progressive opening: as we approach Star 5, the box opens more.
    // If level 5, it is "full/glow" but only "fully opens" on click.
    final bool isHighlyCharged = level >= 4;
    final double openFactor = progress; // 0.0 to 1.0

    return GestureDetector(
      onTap: () => _handleBoxTap(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isHighlyCharged)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 5),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),
          
          Icon(
            level >= 5 ? Icons.card_giftcard_rounded : Icons.inventory_2_outlined,
            color: color,
            size: 24,
          ).animate(key: ValueKey(level))
           .scale(duration: 400.ms, curve: Curves.easeOutBack)
           .rotate(begin: -0.05 * openFactor, end: 0.05 * openFactor, duration: 1.seconds),
        ],
      ),
    );
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
