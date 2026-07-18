import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../models/family_model.dart';
import '../providers/family_provider.dart';
import '../router/app_router.dart';

class FamilyBadgeWidget extends ConsumerWidget {
  final String familyId;
  final double? avatarSize;
  final bool showName;
  final bool showRank;
  final VoidCallback? onTap;

  const FamilyBadgeWidget({
    super.key,
    required this.familyId,
    this.avatarSize = 24,
    this.showName = true,
    this.showRank = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyStreamProvider(familyId));

    return familyAsync.when(
      data: (family) {
        if (family == null) return const SizedBox.shrink();
        return _buildBadge(family);
      },
      loading: () => const SizedBox(height: 20, width: 60),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBadge(FamilyModel family) {
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.familySurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (family.avatarUrl != null)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: family.avatarUrl!,
                  width: avatarSize,
                  height: avatarSize,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor,
                ),
                child: Icon(Icons.shield, color: Colors.white, size: avatarSize! * 0.6),
              ),
            if (showName) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  family.name,
                  style: const TextStyle(
                    color: AppColors.familyText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
            if (showRank) ...[
              const SizedBox(width: 4),
              Text(
                family.rankName,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FamilyBadgeCompact extends ConsumerWidget {
  final String familyId;
  final VoidCallback? onTap;

  const FamilyBadgeCompact({
    super.key,
    required this.familyId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyStreamProvider(familyId));

    return familyAsync.when(
      data: (family) {
        if (family == null) return const SizedBox.shrink();
        final gradient = FamilyModel.themeGradientForLevel(family.level);
        return GestureDetector(
          onTap: onTap ?? () => context.push(AppRoutes.familyDetail, extra: familyId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withOpacity(0.8),
                  gradient[1].withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (family.avatarUrl != null)
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: family.avatarUrl!,
                      width: 14,
                      height: 14,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  family.name.length > 10 ? '${family.name.substring(0, 10)}...' : family.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  family.rankName,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
