import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/vip_provider.dart';
import '../../utils/level_utils.dart';

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
    double customFrameMultiplier = frameMultiplier;

    if (tags != null && (tags!.contains('Admin') || tags!.contains('SuperAdmin'))) {
      customFrameMultiplier *= 0.85;
    }

    final double avatarSize = radius * 2;
    final double frameSize = avatarSize * customFrameMultiplier;

    if (finalFrameUrl.isEmpty && vipTier != null && vipTier != 'none') {
      final tiers = ref.watch(vipTiersProvider).value;
      if (tiers != null) {
        final myTier = tiers.where((t) {
          final tid = t.tierId;
          final tname = t.name;
          return (tid.isNotEmpty && tid == vipTier) || (tname.isNotEmpty && tname == vipTier);
        }).firstOrNull;
        
        if (myTier != null && showFrame) {
          finalFrameUrl = myTier.profileFrame;
        }
      }
    }

    if (tags != null && finalFrameUrl.isEmpty) {
       if (tags!.contains('SuperAdmin')) {
         finalFrameUrl = 'assets/images/super/super-admin.png';
       } else if (tags!.contains('Admin')) {
         finalFrameUrl = 'assets/images/super/admin.png';
       } else if (tags!.contains('Reseller')) {
         finalFrameUrl = 'assets/images/super/reseller.png';
       } else if (tags!.contains('Official')) {
         finalFrameUrl = 'assets/images/super/official.png';
       }
    }

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

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. The Base Avatar (Background Layer)
        Container(
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

        // 2. The VIP Frame Layer (Foreground Layer - Overlay)
        if (showFrame && finalFrameUrl.isNotEmpty)
          IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, -radius * 0.15),
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: finalFrameUrl.startsWith('assets/')
                  ? Image.asset(
                      finalFrameUrl,
                      fit: BoxFit.contain,
                    )
                  : (Uri.tryParse(finalFrameUrl)?.hasAbsolutePath == true)
                    ? Image.network(
                        finalFrameUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 2.seconds),
            ),
          ),
      ],
    );
  }
}
