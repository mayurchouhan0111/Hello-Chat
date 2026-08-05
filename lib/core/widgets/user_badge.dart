import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/level_utils.dart';
import '../utils/svga_static_util.dart';
import 'svga_player.dart';

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
  final bool preferStaticFrame;

  const UserBadge({
    super.key,
    required this.label,
    required this.type,
    this.prefix,
    this.icon,
    this.imageAsset,
    this.customFrameAsset,
    this.margin,
    this.preferStaticFrame = false,
  });

  static final TextStyle _cinzelBase = GoogleFonts.cinzel(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle _getCinzelStyle(double fontSize, List<Shadow> shadows) {
    return _cinzelBase.copyWith(
      fontSize: fontSize,
      shadows: shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine frame asset if provided
    String? frameAsset = (type == BadgeType.level && label.startsWith('Lv.'))
        ? _getLevelBadgeAsset(label)
        : customFrameAsset;

    if (preferStaticFrame && frameAsset != null && frameAsset.endsWith('.svga')) {
      frameAsset = SvgaStaticUtil.staticPathForSvga(frameAsset);
    }

    if (frameAsset != null && frameAsset.isNotEmpty) {
      final bool isSvga = frameAsset.endsWith('.svga');
      final bool isPreRenderedTag = frameAsset.contains('SVIP Kit') || frameAsset.toLowerCase().contains('tag');

      if (isPreRenderedTag) {
        return RepaintBoundary(
          child: Container(
            margin: margin ?? const EdgeInsets.only(right: 6, bottom: 4),
            height: 24,
            child: frameAsset.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: frameAsset,
                    height: 24,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => _buildDefaultGradientPill(),
                  )
                : Image.asset(
                    frameAsset,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildDefaultGradientPill(),
                  ),
          ),
        );
      }

      // Render frame image/SVGA with text and icon layered in center!
      return RepaintBoundary(
        child: Container(
          margin: margin ?? const EdgeInsets.only(right: 6, bottom: 4),
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              isSvga
                  ? (frameAsset.startsWith('http')
                      ? SvgaPlayer(url: frameAsset, fit: BoxFit.contain, maxFps: 15, pauseWhenInvisible: true)
                      : SvgaPlayer(key: ValueKey(frameAsset), assetPath: frameAsset, fit: BoxFit.contain, maxFps: 15, pauseWhenInvisible: true))
                  : (frameAsset.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: frameAsset,
                          height: 24,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox(),
                        )
                      : Image.asset(
                          frameAsset,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null && type != BadgeType.level) ...[
                      Icon(
                        icon,
                        size: 11,
                        color: Colors.white,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 0.5))],
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      label,
                      style: _getCinzelStyle(
                        (label.length > 10) ? 8.0 : 9.5,
                        const [Shadow(color: Colors.black54, blurRadius: 2.5, offset: Offset(0, 0.5))],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Default clean gradient pill badge
    return _buildDefaultGradientPill();
  }

  Widget _buildDefaultGradientPill() {
    final double baseFontSize = (label.length > 12) ? 8.0 : (label.length > 8 ? 9.0 : 10.0);
    final LinearGradient gradient = _getBadgeGradient(type);
    final IconData effectiveIcon = icon ?? _getBadgeIcon(type);

    return RepaintBoundary(
      child: Container(
        margin: margin ?? const EdgeInsets.only(right: 6, bottom: 4),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null) ...[
              Image.asset(
                imageAsset!,
                height: 13,
                width: 13,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 3),
            ] else ...[
              Icon(
                effectiveIcon,
                size: 11,
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: _getCinzelStyle(
                  baseFontSize,
                  const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getBadgeGradient(BadgeType type) {
    switch (type) {
      case BadgeType.wealth:
        return const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFFFB300)]);
      case BadgeType.popularity:
        return const LinearGradient(colors: [Color(0xFFFF4081), Color(0xFFFF6E40)]);
      case BadgeType.level:
        return const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E63)]);
      case BadgeType.vip:
        return const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]);
      case BadgeType.noble:
        return const LinearGradient(colors: [Color(0xFFD84315), Color(0xFFFF8F00)]);
      case BadgeType.role:
        return const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)]);
      case BadgeType.family:
        return const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]);
      case BadgeType.agency:
        return const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]);
      case BadgeType.achievement:
        return const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFFF8F00)]);
    }
  }

  IconData _getBadgeIcon(BadgeType type) {
    switch (type) {
      case BadgeType.wealth:
        return Icons.diamond_rounded;
      case BadgeType.popularity:
        return Icons.local_fire_department_rounded;
      case BadgeType.level:
        return Icons.shield_rounded;
      case BadgeType.vip:
        return Icons.workspace_premium_rounded;
      case BadgeType.noble:
        return Icons.stars_rounded;
      case BadgeType.role:
        return Icons.verified_rounded;
      case BadgeType.family:
        return Icons.groups_rounded;
      case BadgeType.agency:
        return Icons.business_center_rounded;
      case BadgeType.achievement:
        return Icons.emoji_events_rounded;
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
}
