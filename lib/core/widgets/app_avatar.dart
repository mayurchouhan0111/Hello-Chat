import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/vip_provider.dart';
import '../../utils/level_utils.dart';
import 'svga_player.dart';

class AppAvatar extends ConsumerWidget {
  final String imageUrl;
  final String? frameUrl;
  final String? badgeUrl;
  final List<String>? tags;
  final String? vipTier;
  final int? userLevel;
  final double radius;
  final bool showFrame;
  final double frameMultiplier;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.frameUrl,
    this.badgeUrl,
    this.tags,
    this.vipTier,
    this.userLevel,
    this.radius = 20.0,
    this.showFrame = true,
    this.frameMultiplier = 1.5, // Increased size
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String finalFrameUrl = frameUrl ?? '';
    final bool isExplicitNone = finalFrameUrl.toLowerCase() == 'none';
    
    final localVipTier = vipTier;
    int parsedVipLevel = 0;
    if (localVipTier != null && localVipTier != 'none') {
      parsedVipLevel = _getVipLevel(localVipTier);
    }

    final bool hasExplicitFrame = finalFrameUrl.isNotEmpty && finalFrameUrl != 'none';

    if (isExplicitNone) {
      finalFrameUrl = '';
    } else if (hasExplicitFrame) {
      // USER-EXPLICIT FRAME: Highest priority per VIP policy.
      // VIP cosmetics are OPTIONAL — user MUST NOT be forced to display VIP items.
      // If user equipped Rocket/Admin/Custom/VIP frame via Warehouse, it displays.
      final lowerUrl = finalFrameUrl.toLowerCase();
      if (lowerUrl.contains('rocket_frame') || lowerUrl.contains('rocket.svga')) {
        finalFrameUrl = 'assets/ref/frames/frames/rocket.svga';
      } else if (lowerUrl.contains('super-admin.png') || lowerUrl.contains('superadmin.png') || lowerUrl.contains('super_admin.png')) {
        finalFrameUrl = 'assets/images/super/super-admin.svga';
      } else if (lowerUrl.contains('admin.png') && !lowerUrl.contains('super')) {
        finalFrameUrl = 'assets/images/super/admin.svga';
      } else if (lowerUrl.contains('reseller.png')) {
        finalFrameUrl = 'assets/images/super/reseller.svga';
      } else {
        final lowerFrame = finalFrameUrl.toLowerCase();
        bool matched = false;
        for (int i = 1; i <= 8; i++) {
          if (lowerFrame.contains('vip/vip%20$i/') ||
              lowerFrame.contains('vip/vip $i/') ||
              lowerFrame.contains('vip$i.png') ||
              lowerFrame.contains('vip$i.svga')) {
            finalFrameUrl = _getVipFramePath(i);
            matched = true;
            break;
          }
        }
        if (!matched && lowerFrame.startsWith('http') && lowerFrame.contains('vip')) {
          finalFrameUrl = '';
        }
      }
    }
    // NO implicit VIP frame fallback — VIP frames are OPTIONAL per policy.
    // User must explicitly equip from Warehouse to show VIP frame.

    // Only apply tag-based frames if no frame is already resolved
    if (finalFrameUrl.isEmpty && tags != null) {
      if (tags!.contains('SuperAdmin')) {
        finalFrameUrl = 'assets/images/super/super-admin.svga';
      } else if (tags!.contains('Admin')) {
        finalFrameUrl = 'assets/images/super/admin.svga';
      } else if (tags!.contains('Reseller')) {
        finalFrameUrl = 'assets/images/super/reseller.svga';
      } else if (tags!.contains('Official')) {
        finalFrameUrl = 'assets/images/super/official.png';
      }
    }

    // Now calculate sizes
    double customFrameMultiplier = frameMultiplier;
    if (tags != null && (tags!.contains('Admin') || tags!.contains('SuperAdmin'))) {
      customFrameMultiplier *= 0.85;
    }

    if (finalFrameUrl.toLowerCase().endsWith('.svga')) {
      // SVGA frames don't have as much internal padding as the old PNGs.
      // We scale them down so they fit snugly around the avatar circle.
      // This forces the multiplier to be around 1.35.
      customFrameMultiplier = 1.35; 
    }

    final double avatarSize = radius * 2;
    final double frameSize = avatarSize * customFrameMultiplier;

    final bool hasFrame = showFrame && finalFrameUrl.isNotEmpty;
    final Color borderColor = (userLevel != null && userLevel! > 1 && !hasFrame)
        ? LevelUtils.getLevelColor(userLevel!)
        : Colors.white;
    final double borderWidth = (userLevel != null && userLevel! > 1 && !hasFrame) ? 2.0 : 0.5;
    final List<BoxShadow> boxShadows = (userLevel != null && userLevel! > 1 && !hasFrame)
        ? [
            BoxShadow(
              color: LevelUtils.getLevelColor(userLevel!).withOpacity(0.45),
              blurRadius: 8,
              spreadRadius: 1.5,
            )
          ]
        : [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, spreadRadius: 0),
          ];

    final double frameOffset = (avatarSize - frameSize) / 2;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. The Base Avatar (Background Layer)
        RepaintBoundary(
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: boxShadows,
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: (radius * 3.0).toInt().clamp(60, 300),
                      memCacheHeight: (radius * 3.0).toInt().clamp(60, 300),
                      placeholder: (_, __) => Container(color: Colors.grey[100]),
                      errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                    )
                  : Icon(Icons.person, color: AppColors.textTertiary, size: radius),
            ),
          ),
        ),

        // 2. The VIP Frame Layer (Foreground Layer - Overlay)
        if (showFrame && finalFrameUrl.isNotEmpty)
          Positioned(
            left: frameOffset,
            top: frameOffset,
            width: frameSize,
            height: frameSize,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Transform.translate(
                  offset: finalFrameUrl.toLowerCase().endsWith('.svga') 
                      ? Offset.zero 
                      : Offset(0, -radius * 0.15),
                  child: SizedBox(
                    width: frameSize,
                    height: frameSize,
                    child: finalFrameUrl.startsWith('assets/')
                      ? finalFrameUrl.toLowerCase().endsWith('.svga')
                          ? SvgaPlayer(key: ValueKey(finalFrameUrl), assetPath: finalFrameUrl)
                          : Image.asset(
                              finalFrameUrl,
                              fit: BoxFit.contain,
                            )
                      : (Uri.tryParse(finalFrameUrl)?.hasAbsolutePath == true)
                        ? finalFrameUrl.toLowerCase().endsWith('.svga')
                            ? SvgaPlayer(key: ValueKey(finalFrameUrl), url: finalFrameUrl)
                            : CachedNetworkImage(
                                imageUrl: finalFrameUrl,
                                fit: BoxFit.contain,
                                memCacheWidth: (frameSize * 2.0).toInt().clamp(60, 400),
                                memCacheHeight: (frameSize * 2.0).toInt().clamp(60, 400),
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              )
                        : const SizedBox.shrink(),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 2.seconds),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

int _getVipLevel(String tierName) {
  final clean = tierName.toLowerCase().replaceAll(' ', '');
  if (clean.startsWith('vip')) {
    final numStr = clean.substring(3);
    final val = int.tryParse(numStr);
    if (val != null && val >= 1 && val <= 8) return val;
  }
  if (clean == 'svip1') return 1;
  if (clean == 'svip2') return 2;
  if (clean == 'svip3') return 3;
  if (clean == 'svip4') return 4;
  if (clean == 'svip5') return 5;
  if (clean == 'svip6') return 6;
  if (clean == 'svip7') return 7;
  if (clean == 'knight' || clean == 'viscount') return 2;
  if (clean == 'earl' || clean == 'marquis') return 4;
  if (clean == 'duke' || clean == 'king') return 6;
  if (clean == 'emperor') return 8;
  if (clean == 'elite') return 5;
  return 0;
}

String _getVipFramePath(int level) {
  if (level == 1) return 'assets/VIP/VIP 1/Frame.svga';
  if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Frame.svga';
  if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Frame.svga';
  if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Frame.svga';
  if (level == 5) return 'assets/VIP/VIP 5/VIP 5/User Frame.svga';
  if (level == 6) return 'assets/VIP/VIP 6/VIP 6/User Frame.svga';
  if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Frame.svga';
  if (level == 8) return 'assets/VIP/VIP 8/VIP 8/User Frame.svga';
  return '';
}
