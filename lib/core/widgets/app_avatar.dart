import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/vip_provider.dart';

class AppAvatar extends ConsumerWidget {
  final String imageUrl;
  final String? frameUrl;
  final String? badgeUrl;
  final String? vipTier;
  final double radius;
  final bool showFrame;
  final double frameMultiplier;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.frameUrl,
    this.badgeUrl,
    this.vipTier,
    this.radius = 20.0,
    this.showFrame = true,
    this.frameMultiplier = 1.75,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Calculate dimensions
    final double avatarSize = radius * 2;
    final double frameSize = avatarSize * frameMultiplier; 

    // 2. Resolve final Frame URL with fallback
    String finalFrameUrl = frameUrl ?? '';

    if (vipTier != null && vipTier != 'none') {
      final tiers = ref.watch(vipTiersProvider).value;
      if (tiers != null) {
        final myTier = tiers.where((t) {
          final tid = t.tierId;
          final tname = t.name;
          return (tid.isNotEmpty && tid == vipTier) || (tname.isNotEmpty && tname == vipTier);
        }).firstOrNull;
        
        if (myTier != null && showFrame && finalFrameUrl.isEmpty) {
          finalFrameUrl = myTier.profileFrame;
        }
      }
    }

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
            border: Border.all(color: Colors.white, width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, spreadRadius: 0),
            ],
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
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: (Uri.tryParse(finalFrameUrl)?.hasAbsolutePath == true)
                ? Image.network(
                    finalFrameUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 2.seconds),
          ),
      ],
    );
  }
}
