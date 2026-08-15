import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/svip_level_model.dart';
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
  final bool optimizeCrown;

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
    this.optimizeCrown = false,
  });

  int _getVipLevel(String vipTierName) {
    final clean = vipTierName.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final numStr = clean.substring(3);
      final val = int.tryParse(numStr);
      if (val != null) return val;
    }
    return 0;
  }

  String? _getVipCrownPath(int level) {
    if (level < 1 || level > 8) return null;
    if (level == 1) return 'assets/VIP/VIP 1/Crown 1.svga';
    return 'assets/VIP/VIP $level/VIP $level/Crown 1.svga';
  }

  @override
  Widget build(BuildContext context) {
    final svipLevel = user.svipLevel ?? 0;
    final vipLevel = _getVipLevel(user.vipTier);
    final hasVipBg = svipLevel > 0 || vipLevel > 0;

    String? crownPath;

    if (svipLevel > 0) {
      final svipModel = SVIPLevelModel.getLevelByTier(svipLevel);
      crownPath = svipModel.crownAsset;
    } else if (user.profileFrame.isNotEmpty && user.profileFrame.toLowerCase().endsWith('.svga')) {
      crownPath = user.profileFrame;
    } else {
      crownPath = _getVipCrownPath(vipLevel);
    }

    Color effectiveBg = backgroundColor;
    if (backgroundColor == Colors.white && hasVipBg) {
      if (svipLevel > 0) {
        effectiveBg = const Color(0xFF0C241B); // Rich SVIP Dark Emerald
      } else if (vipLevel > 0) {
        effectiveBg = const Color(0xFF18102E); // Rich VIP Royal Violet
      }
    }

    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: borderRadius ?? BorderRadius.circular(24),
          boxShadow: boxShadow,
        ),
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Upper Crown & Frame (Isolated in RepaintBoundary to eliminate profile card lag)
            if (crownPath != null && crownPath.isNotEmpty)
              Positioned(
                top: crownTop,
                left: crownLeft,
                right: crownRight,
                bottom: crownBottom,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: crownPath.toLowerCase().endsWith('.svga')
                        ? SvgaPlayer(
                            key: ValueKey('crown_$crownPath'),
                            assetPath: crownPath,
                            fit: fit,
                            maxFps: optimizeCrown ? 18.0 : null,
                            maxRenderSize: optimizeCrown ? const Size(320, 320) : null,
                            pauseWhenInvisible: optimizeCrown,
                          )
                        : Image.asset(
                            crownPath,
                            fit: fit,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
