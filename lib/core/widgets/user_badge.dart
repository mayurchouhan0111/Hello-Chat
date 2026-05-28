import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/level_utils.dart';

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
  final String? customFrameAsset;
  final EdgeInsetsGeometry? margin;

  const UserBadge({
    super.key,
    required this.label,
    required this.type,
    this.prefix,
    this.icon,
    this.imageAsset,
    this.customFrameAsset,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final double baseFontSize = (label.length > 10) ? 7.5 : 8.5;

    // Get frame asset - use unified LevelUtils for level type, else fallback
    final String frameAsset = (type == BadgeType.level && label.startsWith('Lv.'))
        ? _getLevelBadgeAsset(label)
        : (customFrameAsset ?? _getFrameAsset());

    return Container(
      margin: margin ?? const EdgeInsets.only(right: 6),
      height: (type == BadgeType.level) ? 22 : 38,
      constraints: const BoxConstraints(minWidth: 85),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              frameAsset,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox(),
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
                  ] else if (icon != null && type != BadgeType.level) ...[
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
                      style: GoogleFonts.cinzel(
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
        return const Offset(0, -3);
      case BadgeType.agency:
      case BadgeType.family:
        return const Offset(0, 1);
      default:
        return Offset.zero;
    }
  }

  String _getLevelBadgeAsset(String label) {
    final match = RegExp(r'Lv\.?(\d+)').firstMatch(label);
    if (match != null) {
      int level = int.tryParse(match.group(1) ?? '1') ?? 1;
      return LevelUtils.getLevelFrameAsset(level);
    }
    return 'assets/images/levels_new/level_badge_0.webp';
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
