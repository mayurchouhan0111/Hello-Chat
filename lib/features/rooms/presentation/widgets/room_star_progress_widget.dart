import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoomStarProgressWidget extends StatefulWidget {
  final int currentStars;
  final double progress; // 0.0 to 1.0

  const RoomStarProgressWidget({
    super.key,
    this.currentStars = 0,
    this.progress = 0.0,
  });

  @override
  State<RoomStarProgressWidget> createState() => _RoomStarProgressWidgetState();
}

class _RoomStarProgressWidgetState extends State<RoomStarProgressWidget> {
  bool _isExpanded = false;

  Color _getStarColor(int stars) {
    // Distinct premium colors for each star level
    switch (stars) {
      case 0: return Colors.white38;
      case 1: return const Color(0xFFFFD700); // Gold
      case 2: return const Color(0xFF00E5FF); // Cyan
      case 3: return const Color(0xFFE91E63); // Pink
      case 4: return const Color(0xFF9C27B0); // Purple
      case 5: return const Color(0xFFFF4500); // Red-Orange
      case 6: return const Color(0xFF6200EA); // Deep Purple
      case 7: return const Color(0xFF00C853); // Green
      case 8: return const Color(0xFFD50000); // Deep Red
      case 9: return const Color(0xFFFFAB00); // Amber
      default: return const Color(0xFF00E5FF).withBlue((stars * 10) % 255); // Dynamic
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getStarColor(widget.currentStars);
    final bool isBoxOpen = widget.currentStars >= 5;
    
    // Scale factor for "progressive" opening of the box if Stars >= 5
    final double overflowProgress = (widget.currentStars >= 5) 
        ? (widget.currentStars - 5) + widget.progress 
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon - Changes to Box at Star 5
          Icon(
            isBoxOpen ? Icons.inventory_2_rounded : Icons.stars_rounded, 
            color: activeColor, 
            size: 14 + (isBoxOpen ? (overflowProgress * 0.5).clamp(0.0, 3.0) : 0.0)
          ),
          const Gap(6),
          // Ticket Text
          Text(
            "Ticket ${widget.currentStars} Star",
            style: TextStyle(
              color: activeColor, 
              fontSize: 10, 
              fontWeight: FontWeight.w900,
            ),
          ),
          
          // Small Progress Bar (always horizontal, not expanding)
          if (widget.progress > 0) ...[
            const Gap(8),
            SizedBox(
              width: 30,
              height: 2,
              child: Stack(
                children: [
                  Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(1))),
                  FractionallySizedBox(
                    widthFactor: widget.progress.clamp(0.01, 1.0),
                    child: Container(decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(1))),
                  ),
                ],
              ),
            ),
          ],

          // Box Percentage when open
          if (isBoxOpen) ...[
            const Gap(6),
            Text(
              "${(overflowProgress * 10).toInt()}%", 
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)
            ),
          ],
        ],
      ),
    ).animate(key: ValueKey(widget.currentStars))
     .fadeIn(duration: 300.ms)
     .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 200.ms);
  }
}


