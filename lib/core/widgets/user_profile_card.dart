import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/svip_level_model.dart';
import '../utils/svga_static_util.dart';
import 'svga_player.dart';

class UserProfileCard extends StatelessWidget {
  final UserModel user;
  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final Color backgroundColor;
  final BoxFit fit;
  final double crownTop;
  final double? crownBottom;
  final double crownLeft;
  final double crownRight;
  final double? crownHeight;
  final bool showCrown;
  final bool showStrip;
  final bool optimizeCrown;
  final bool staticDecor;

  const UserProfileCard({
    super.key,
    required this.user,
    required this.child,
    this.borderRadius,
    this.padding,
    this.boxShadow,
    this.backgroundColor = Colors.white,
    this.fit = BoxFit.fill,
    this.crownTop = -60,
    this.crownBottom = -10,
    this.crownLeft = -10,
    this.crownRight = -10,
    this.crownHeight,
    this.showCrown = true,
    this.showStrip = true,
    this.optimizeCrown = false,
    this.staticDecor = false,
  });

  int _getSvipLevel(UserModel user) {
    if (user.svipLevel != null && user.svipLevel! > 0) return user.svipLevel!;
    for (final tag in user.tags) {
      final clean = tag.toLowerCase().replaceAll(' ', '');
      if (clean.startsWith('svip')) {
        final val = int.tryParse(clean.substring(4));
        if (val != null && val > 0) return val;
      }
    }
    for (final badge in user.badges) {
      final clean = badge.toLowerCase().replaceAll(' ', '');
      if (clean.startsWith('svip')) {
        final val = int.tryParse(clean.substring(4));
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  int _getVipLevel(UserModel user) {
    final clean = user.vipTier.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final val = int.tryParse(clean.substring(3));
      if (val != null && val > 0) return val;
    }
    for (final tag in user.tags) {
      final cleanTag = tag.toLowerCase().replaceAll(' ', '');
      if (cleanTag.startsWith('vip') && !cleanTag.startsWith('svip')) {
        final val = int.tryParse(cleanTag.substring(3));
        if (val != null && val > 0) return val;
      }
    }
    for (final badge in user.badges) {
      final cleanBadge = badge.toLowerCase().replaceAll(' ', '');
      if (cleanBadge.startsWith('vip') && !cleanBadge.startsWith('svip')) {
        final val = int.tryParse(cleanBadge.substring(3));
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  String? _getVipCrownPath(int level) {
    if (level < 1 || level > 8) return null;
    if (level == 1) return 'assets/VIP/VIP 1/Crown 1.svga';
    if (level == 8) return 'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga';
    return 'assets/VIP/VIP $level/VIP $level/Crown 1.svga';
  }

  String? _getVipStripPath(int level) {
    if (level < 1 || level > 8) return null;
    if (level == 1) return 'assets/VIP/VIP 1/Strip.svga';
    return 'assets/VIP/VIP $level/VIP $level/Strip.svga';
  }

  @override
  Widget build(BuildContext context) {
    final svipLevel = _getSvipLevel(user);
    final vipLevel = _getVipLevel(user);
    final hasVipBg = svipLevel > 0 || vipLevel > 0;

    String? crownPath;
    String? stripPath;

    if (user.equippedCrown.isNotEmpty && user.equippedCrown != 'none') {
      crownPath = user.equippedCrown;
    } else if (user.badgeIcon.isNotEmpty && user.badgeIcon != 'none') {
      crownPath = user.badgeIcon;
    } else if (svipLevel > 0) {
      final svipModel = SVIPLevelModel.getLevelByTier(svipLevel);
      crownPath = svipModel.crownAsset;
    } else if (vipLevel > 0) {
      crownPath = _getVipCrownPath(vipLevel);
      stripPath = _getVipStripPath(vipLevel);
    }

    Color effectiveBg = backgroundColor;
    Gradient? effectiveGradient;

    if (backgroundColor == Colors.white && hasVipBg) {
      if (svipLevel > 0) {
        effectiveBg = const Color(0xFF092017); // Rich SVIP Dark Emerald
        effectiveGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F3627), Color(0xFF061711)],
        );
      } else if (vipLevel > 0) {
        effectiveBg = const Color(0xFF160F2B); // Rich VIP Royal Violet
        effectiveGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF261447), Color(0xFF110B22)],
        );
      }
    }

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveBg,
          gradient: effectiveGradient,
          borderRadius: borderRadius ?? BorderRadius.circular(24),
          boxShadow: boxShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. VIP Card Background Strip Decoration
            if (showStrip && stripPath != null && stripPath.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: ClipRRect(
                  borderRadius: (borderRadius as BorderRadius?) ?? const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Opacity(
                    opacity: 0.75,
                    child: stripPath.toLowerCase().endsWith('.svga')
                        ? (staticDecor
                            ? Image.asset(
                                SvgaStaticUtil.staticPathForSvga(stripPath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              )
                            : SvgaPlayer(
                                key: ValueKey('strip_$stripPath'),
                                assetPath: stripPath,
                                fit: BoxFit.cover,
                                maxFps: 15.0,
                                maxRenderSize: const Size(480, 120),
                                pauseWhenInvisible: true,
                              ))
                        : Image.asset(
                            stripPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),

            // 2. Upper Crown (SVIP or VIP Background Wings & Stage)
            if (showCrown && crownPath != null && crownPath.isNotEmpty)
              Positioned(
                top: crownTop,
                left: crownLeft,
                right: crownRight,
                bottom: crownBottom,
                height: crownHeight ?? (crownBottom == null ? 300 : null),
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: Builder(
                      builder: (context) {
                        final staticPath = SvgaStaticUtil.staticPathForSvga(crownPath, category: 'crown');

                        return crownPath!.toLowerCase().endsWith('.svga')
                            ? (staticDecor
                                ? Image.asset(
                                    staticPath,
                                    fit: fit,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                : SvgaPlayer(
                                    key: ValueKey('crown_$crownPath'),
                                    assetPath: crownPath,
                                    fit: fit,
                                    maxFps: optimizeCrown ? 18.0 : 24.0,
                                    maxRenderSize: optimizeCrown ? const Size(240, 240) : const Size(320, 320),
                                    pauseWhenInvisible: true,
                                  ))
                            : Image.asset(
                                crownPath,
                                fit: fit,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              );
                      },
                    ),
                  ),
                ),
              ),

            child,
          ],
        ),
      ),
    );
  }
}
