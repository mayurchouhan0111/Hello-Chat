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
  achievement,
  admin
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
            margin: margin ?? const EdgeInsets.only(right: 6, bottom: 6),
            height: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
          ),
        );
      }

      // Render frame image/SVGA with text and icon layered in center!
      return RepaintBoundary(
        child: Container(
          margin: margin ?? const EdgeInsets.only(right: 6, bottom: 6),
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
                    if (icon != null) ...[
                      Icon(icon, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      label,
                      style: _getCinzelStyle(
                        (label.length > 10) ? 8.5 : 9.5,
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
    
    // Check for specialized tier matches from Developer Video Specification
    final upperLabel = label.toUpperCase().trim();
    final isAgencyTier = upperLabel.contains('AGENCY') && RegExp(r'[1-5]').hasMatch(upperLabel);
    final isHostTier = upperLabel.contains('HOST') && RegExp(r'[1-5]').hasMatch(upperLabel);
    final isSvipTier = upperLabel.startsWith('SVIP');

    int tierLevel = 1;
    final match = RegExp(r'(\d+)').firstMatch(upperLabel);
    if (match != null) {
      tierLevel = int.tryParse(match.group(1) ?? '1') ?? 1;
    }

    LinearGradient gradient;
    Border border;
    List<BoxShadow> shadows;
    IconData effectiveIcon;
    Color textColor = Colors.white;

    if (isAgencyTier || isHostTier) {
      // Exact gradients & borders from video reference CSS
      switch (tierLevel) {
        case 1: // Bronze
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B4513), Color(0xFFCD853F)],
          );
          border = Border.all(color: const Color(0xFFD2691E), width: 1.5);
          textColor = const Color(0xFFFFF8DC);
          effectiveIcon = Icons.military_tech_rounded;
          shadows = [
            BoxShadow(color: const Color(0xFF8B4513).withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 1.5)),
          ];
          break;
        case 2: // Silver
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF708090), Color(0xFFC0C0C0)],
          );
          border = Border.all(color: const Color(0xFFA9A9A9), width: 1.5);
          textColor = const Color(0xFFF8F8FF);
          effectiveIcon = Icons.military_tech_rounded;
          shadows = [
            BoxShadow(color: const Color(0xFF708090).withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 1.5)),
          ];
          break;
        case 3: // Gold
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDAA520), Color(0xFFFFD700)],
          );
          border = Border.all(color: const Color(0xFFFFA500), width: 1.5);
          effectiveIcon = Icons.military_tech_rounded;
          shadows = [
            BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 0.5),
            const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1.5)),
          ];
          break;
        case 4: // Diamond / Violet
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8A2BE2), Color(0xFFBA55D3)],
          );
          border = Border.all(color: const Color(0xFFDDA0DD), width: 1.5);
          effectiveIcon = Icons.diamond_rounded;
          shadows = [
            BoxShadow(color: const Color(0xFFBA55D3).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 0.5),
            const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1.5)),
          ];
          break;
        case 5: // Crown / Radiant Sun
        default:
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF4500), Color(0xFFFFD700)],
          );
          border = Border.all(color: const Color(0xFFFF6347), width: 1.5);
          effectiveIcon = Icons.workspace_premium_rounded;
          shadows = [
            BoxShadow(color: const Color(0xFFFF4500).withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 1),
            const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1.5)),
          ];
          break;
      }
    } else if (isSvipTier) {
      // Luxury SVIP Badges
      if (upperLabel.contains('STAR')) {
        gradient = const LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFFD54F)]);
        border = Border.all(color: const Color(0xFFFFECB3), width: 1.5);
        effectiveIcon = Icons.star_rounded;
        shadows = [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)];
      } else {
        switch (tierLevel) {
          case 1:
            gradient = const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFFDAA520)]);
            border = Border.all(color: const Color(0xFFD2691E), width: 1.2);
            effectiveIcon = Icons.shield_rounded;
            shadows = [BoxShadow(color: const Color(0xFF8B4513).withValues(alpha: 0.4), blurRadius: 6)];
            break;
          case 2:
            gradient = const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFFB0BEC5)]);
            border = Border.all(color: const Color(0xFFCFD8DC), width: 1.2);
            effectiveIcon = Icons.shield_rounded;
            shadows = [BoxShadow(color: const Color(0xFF90A4AE).withValues(alpha: 0.4), blurRadius: 6)];
            break;
          case 3:
            gradient = const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700)]);
            border = Border.all(color: const Color(0xFFFFDF00), width: 1.5);
            effectiveIcon = Icons.stars_rounded;
            shadows = [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.55), blurRadius: 8, spreadRadius: 0.5)];
            break;
          case 4:
            gradient = const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF8E24AA)]);
            border = Border.all(color: const Color(0xFFBA68C8), width: 1.5);
            effectiveIcon = Icons.security_rounded;
            shadows = [BoxShadow(color: const Color(0xFFAB47BC).withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 0.5)];
            break;
          case 5:
            gradient = const LinearGradient(colors: [Color(0xFF880E4F), Color(0xFFE91E63)]);
            border = Border.all(color: const Color(0xFFFF4081), width: 1.5);
            effectiveIcon = Icons.workspace_premium_rounded;
            shadows = [BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 1)];
            break;
          case 6:
          default:
            gradient = const LinearGradient(colors: [Color(0xFF1A1A24), Color(0xFFFF6F00), Color(0xFFFFD700)]);
            border = Border.all(color: const Color(0xFFFFD700), width: 1.8);
            effectiveIcon = Icons.local_fire_department_rounded;
            shadows = [
              BoxShadow(color: const Color(0xFFFF6F00).withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 1.5),
              const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
            ];
            break;
        }
      }
    } else {
      gradient = _getBadgeGradient(type);
      border = Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8);
      effectiveIcon = icon ?? _getBadgeIcon(type);
      shadows = [
        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1.5)),
      ];
    }

    return RepaintBoundary(
      child: Container(
        margin: margin ?? const EdgeInsets.only(right: 6, bottom: 4),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(50), // 50px pill shape per video CSS
          border: border,
          boxShadow: shadows,
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
              const SizedBox(width: 4),
            ] else ...[
              Icon(
                effectiveIcon,
                size: 12,
                color: textColor,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 0.5))],
              ),
              const SizedBox(width: 4),
            ],
            if (prefix != null) ...[
              Text(
                prefix!,
                style: TextStyle(
                  color: textColor,
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
                ).copyWith(color: textColor, fontWeight: FontWeight.w900),
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
        return const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFFCD853F)]);
      case BadgeType.achievement:
        return const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFFF8F00)]);
      case BadgeType.admin:
        return const LinearGradient(colors: [Color(0xFF00B8D4), Color(0xFF00E5FF)]);
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
      case BadgeType.admin:
        return Icons.admin_panel_settings_rounded;
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

/// Standalone Developer-Exact Badge Helpers
class AgencyLevelBadge extends StatelessWidget {
  final int level;
  final EdgeInsetsGeometry? margin;

  const AgencyLevelBadge({super.key, required this.level, this.margin});

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(1, 5);
    return UserBadge(
      label: '$clampedLevel AGENCY',
      type: BadgeType.agency,
      margin: margin,
    );
  }
}

class HostLevelBadge extends StatelessWidget {
  final int level;
  final EdgeInsetsGeometry? margin;

  const HostLevelBadge({super.key, required this.level, this.margin});

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(1, 5);
    return UserBadge(
      label: '$clampedLevel HOST',
      type: BadgeType.role,
      margin: margin,
    );
  }
}

class SvipTierBadge extends StatelessWidget {
  final int level;
  final bool isStar;
  final EdgeInsetsGeometry? margin;

  const SvipTierBadge({super.key, required this.level, this.isStar = false, this.margin});

  @override
  Widget build(BuildContext context) {
    if (isStar) {
      return UserBadge(
        label: 'SVIP Star',
        type: BadgeType.vip,
        margin: margin,
      );
    }
    final clampedLevel = level.clamp(1, 6);
    return UserBadge(
      label: 'SVIP $clampedLevel',
      type: BadgeType.vip,
      margin: margin,
    );
  }
}
