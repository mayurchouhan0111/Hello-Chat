import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../utils/level_utils.dart';
import '../models/svip_level_model.dart';
import '../utils/svga_static_util.dart';
import 'svga_player.dart';

class AppAvatar extends ConsumerWidget {
  final String imageUrl;
  final String? frameUrl;
  final String? badgeUrl;
  final List<String>? tags;
  final String? vipTier;
  final int? svipLevel;
  final int? userLevel;
  final double radius;
  final bool showFrame;
  final double frameMultiplier;
  final bool staticFrame;
  final double? maxFps;
  final Size? maxRenderSize;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.frameUrl,
    this.badgeUrl,
    this.tags,
    this.vipTier,
    this.svipLevel,
    this.userLevel,
    this.radius = 20.0,
    this.showFrame = true,
    this.frameMultiplier = 1.5, // Increased size
    this.staticFrame = false,
    this.maxFps,
    this.maxRenderSize,
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
      final lowerUrl = finalFrameUrl.toLowerCase();
      if (lowerUrl.contains('rocket_frame') || lowerUrl.contains('rockeet_svga') || lowerUrl.contains('rocket.svga')) {
        finalFrameUrl = 'assets/Helo chat/Rockeet_SVGA.svga';
      } else if (lowerUrl.contains('super-admin') || lowerUrl.contains('superadmin')) {
        finalFrameUrl = 'assets/Helo chat/Superadmin.svga';
      } else if (lowerUrl.contains('admin') && !lowerUrl.contains('super')) {
        finalFrameUrl = 'assets/images/super/admin.svga';
      } else if (lowerUrl.contains('reseller')) {
        finalFrameUrl = 'assets/images/super/reseller.svga';
      } else if (lowerUrl.contains('agency')) {
        finalFrameUrl = 'assets/Helo chat/Agency.svga';
      } else if (lowerUrl.contains('official')) {
        finalFrameUrl = 'assets/Helo chat/Official.svga';
      } else if (lowerUrl.contains('cp_frame_3') || lowerUrl.contains('3.svga')) {
        finalFrameUrl = 'assets/Helo chat/3.svga';
      } else if (lowerUrl.contains('cp_frame_2') || lowerUrl.contains('2.svga')) {
        finalFrameUrl = 'assets/Helo chat/2.svga';
      } else if (lowerUrl.contains('cp_frame_1') || lowerUrl.contains('cp_frame') || lowerUrl.contains('cp.svga') || lowerUrl.contains('1.svga')) {
        finalFrameUrl = 'assets/Helo chat/1.svga';
      } else if (lowerUrl.contains('top 1') || lowerUrl.contains('top1')) {
        finalFrameUrl = 'assets/Helo chat/Top 1.svga';
      } else if (lowerUrl.contains('top 2') || lowerUrl.contains('top2')) {
        finalFrameUrl = 'assets/Helo chat/Top 2.svga';
      } else if (lowerUrl.contains('top 3') || lowerUrl.contains('top3')) {
        finalFrameUrl = 'assets/Helo chat/Top 3.svga';
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

    // Resolve SVIP Kit Frame asset if user has active svipLevel
    if (finalFrameUrl.isEmpty && (svipLevel ?? 0) > 0) {
      final svipModel = SVIPLevelModel.getLevelByTier(svipLevel!);
      finalFrameUrl = svipModel.frameAsset;
    }

    // Only apply tag-based frames if no frame is already resolved
    if (finalFrameUrl.isEmpty && tags != null) {
      if (tags!.contains('SuperAdmin')) {
        finalFrameUrl = 'assets/Helo chat/Superadmin.svga';
      } else if (tags!.contains('Admin')) {
        finalFrameUrl = 'assets/images/super/admin.svga';
      } else if (tags!.contains('Agency')) {
        finalFrameUrl = 'assets/Helo chat/Agency.svga';
      } else if (tags!.contains('Reseller')) {
        finalFrameUrl = 'assets/images/super/reseller.svga';
      } else if (tags!.contains('Official')) {
        finalFrameUrl = 'assets/Helo chat/Official.svga';
      }
    }

    // Resolve static frame if requested
    if (staticFrame && finalFrameUrl.toLowerCase().endsWith('.svga')) {
      finalFrameUrl = SvgaStaticUtil.staticPathForSvga(finalFrameUrl, category: 'frame');
    }

    // Now calculate sizes
    double customFrameMultiplier = frameMultiplier;
    if (tags != null && (tags!.contains('Admin') || tags!.contains('SuperAdmin'))) {
      customFrameMultiplier *= 0.85;
    }

    if (finalFrameUrl.toLowerCase().endsWith('.svga')) {
      // SVGA frames don't have as much internal padding as PNGs.
      // Scale proportionally with frameMultiplier so SVGA frames match requested avatar sizes.
      customFrameMultiplier = (frameMultiplier * 0.85).clamp(1.2, 1.85); 
    }

    final String lowerFrame = finalFrameUrl.toLowerCase();
    final bool isSvip1Frame = (svipLevel == 1) || lowerFrame.contains('svip 1') || lowerFrame.contains('svip_1') || lowerFrame.contains('svip1');
    if (isSvip1Frame && lowerFrame.contains('frame')) {
      customFrameMultiplier *= 0.84; // Reduced frame radius specifically for SVIP 1 frame per user request
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
                          ? SvgaPlayer(
                              key: ValueKey(finalFrameUrl),
                              assetPath: finalFrameUrl,
                              maxFps: maxFps,
                              maxRenderSize: maxRenderSize ?? Size(frameSize * 2, frameSize * 2),
                              pauseWhenInvisible: true,
                            )
                          : Image.asset(
                              finalFrameUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            )
                      : (Uri.tryParse(finalFrameUrl)?.hasAbsolutePath == true)
                        ? finalFrameUrl.toLowerCase().endsWith('.svga')
                            ? SvgaPlayer(
                                key: ValueKey(finalFrameUrl),
                                url: finalFrameUrl,
                                maxFps: maxFps,
                                maxRenderSize: maxRenderSize ?? Size(frameSize * 2, frameSize * 2),
                                pauseWhenInvisible: true,
                              )
                            : CachedNetworkImage(
                                imageUrl: finalFrameUrl,
                                fit: BoxFit.contain,
                                memCacheWidth: (frameSize * 2.0).toInt().clamp(60, 400),
                                memCacheHeight: (frameSize * 2.0).toInt().clamp(60, 400),
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              )
                        : const SizedBox.shrink(),
                  ),
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
