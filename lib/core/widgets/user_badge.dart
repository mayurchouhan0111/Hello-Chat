import 'package:flutter/material.dart';

enum BadgeType {
  wealth,
  popularity,
  level,
  vip,
  noble,
  role,
  family,
  agency,
  achievement
}

class UserBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final String? prefix;
  final IconData? icon;
  final String? imageAsset;
  final EdgeInsetsGeometry? margin;

  const UserBadge({
    super.key,
    required this.label,
    required this.type,
    this.prefix,
    this.icon,
    this.imageAsset,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic font scaling for longer labels to prevent overflow/crowding
    final double baseFontSize = (label.length > 10) ? 7.5 : 8.5;

    return Container(
      margin: margin ?? const EdgeInsets.only(right: 6),
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Frame
          Positioned.fill(
            child: Image.asset(
              _getFrameAsset(),
              fit: BoxFit.fill,
            ),
          ),
          
          // Content with Visual Offset Adjustment
          Transform.translate(
            offset: _getVisualOffset(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imageAsset != null) ...[
                    Image.asset(
                      imageAsset!, 
                      height: 16,
                      width: 16, 
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 3),
                  ] else if (icon != null) ...[
                    Icon(
                      icon, 
                      size: 10, 
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 1.5, offset: Offset(0, 0.5))],
                    ),
                    const SizedBox(width: 3),
                  ],
                  if (prefix != null) ...[
                    Text(
                      prefix!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.1,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 1.5, offset: Offset(0, 0.5))],
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.visible,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _getVisualOffset() {
    switch (type) {
      case BadgeType.wealth:
      case BadgeType.achievement:
        return const Offset(0, -3); // Shift up for Shield frame (wings at bottom)
      case BadgeType.agency:
      case BadgeType.family:
        return const Offset(0, 1); // Shift down for Scroll frames as requested
      default:
        return Offset.zero;
    }
  }

  String _getFrameAsset() {
    const basePath = 'assets/images/extracted_badges/';
    switch (type) {
      case BadgeType.wealth: 
        return '${basePath}badge_frame_0_3.png'; // Gold Shield with Wings
      case BadgeType.vip: 
        return '${basePath}badge_frame_0_1.png'; // Gold Ornate
      case BadgeType.level: 
        return '${basePath}badge_frame_1_0.png'; // Green Rect with Leaves
      case BadgeType.popularity: 
        return '${basePath}badge_frame_1_3.png'; // Green Shield with Wings
      case BadgeType.noble: 
        return '${basePath}badge_frame_2_1.png'; // Blue Ornate
      case BadgeType.role: 
        return '${basePath}badge_frame_2_0.png'; // Blue Rect with Leaves
      case BadgeType.family: 
        return '${basePath}badge_frame_0_2.png'; // Gold Scroll
      case BadgeType.agency: 
        return '${basePath}badge_frame_2_2.png'; // Blue Scroll
      case BadgeType.achievement: 
        return '${basePath}badge_frame_0_3.png'; // Gold Shield (Jackpot)
    }
  }
}
