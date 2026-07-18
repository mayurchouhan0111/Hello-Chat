import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../constants/app_colors.dart';
import '../models/family_model.dart';
import '../models/family_battle_model.dart';
import '../providers/family_provider.dart';

class FamilyBattleCard extends ConsumerWidget {
  final String familyId;
  final VoidCallback? onTap;

  const FamilyBattleCard({super.key, required this.familyId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyStreamProvider(familyId));
    final activeBattleAsync = ref.watch(activeBattleProvider(familyId));

    return familyAsync.when(
      data: (family) {
        if (family == null) return const SizedBox.shrink();
        return activeBattleAsync.when(
          data: (battle) => _buildCard(family, battle),
          loading: () => _buildCard(family, null),
          error: (_, __) => _buildCard(family, null),
        );
      },
      loading: () => const SizedBox(height: 120),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(FamilyModel family, FamilyBattleModel? battle) {
    final battleImageUrl = battle?.imageUrl;
    final isActive = battle?.status == 'active';
    final themeIdx = FamilyModel.themeIndexForLevel(family.level);
    final primaryGradient = _themePrimaryGradient(themeIdx);
    final badgeColor = _themeBadgeColor(themeIdx);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isActive ? AppColors.familyRed.withOpacity(0.4) : badgeColor.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: isActive ? AppColors.familyRed.withOpacity(0.15) : badgeColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Container(
            color: AppColors.familySurface.withOpacity(0.5),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: battleImageUrl != null
                            ? LinearGradient(
                                colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(colors: primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: battleImageUrl != null
                          ? CachedNetworkImage(imageUrl: battleImageUrl, fit: BoxFit.cover)
                          : _buildDefaultBannerArt(badgeColor),
                    ),
                    if (battleImageUrl != null)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.familyRed : badgeColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: (isActive ? AppColors.familyRed : badgeColor).withOpacity(0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.fiber_manual_record_rounded : Icons.sports_kabaddi_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const Gap(4),
                                Text(
                                  isActive ? 'LIVE BATTLE' : 'CLAN ARENA',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LVL ${family.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const Gap(6),
                          Text(
                            family.rankName,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.familyRed,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.familyRed.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record_rounded, size: 8, color: Colors.white),
                              Gap(4),
                              Text(
                                'LIVE',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_fire_department_rounded, size: 16, color: badgeColor),
                                const Gap(4),
                                Text(
                                  '${family.totalCombatPoints}',
                                  style: TextStyle(color: AppColors.familyText, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const Text('Combat Power', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 10, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.familyGold),
                              const Gap(4),
                              Text(
                                '${family.totalBattlePoints}',
                                style: const TextStyle(color: AppColors.familyGold, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const Text('Battle Wins', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 10, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.08),
                    border: Border(top: BorderSide(color: badgeColor.withOpacity(0.1))),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_kabaddi_rounded, size: 12, color: badgeColor),
                      const Gap(4),
                      Text(
                        isActive ? 'TAP TO FIGHT' : 'ENTER ARENA',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Gap(4),
                      Icon(Icons.chevron_right_rounded, size: 14, color: badgeColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBannerArt(Color badgeColor) {
    return Center(
      child: Icon(Icons.sports_kabaddi_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
    );
  }

  List<Color> _themePrimaryGradient(int idx) {
    switch (idx) {
      case 1: return AppColors.familyThemeBPrimary;
      case 2: return AppColors.familyThemeCPrimary;
      case 3: return AppColors.familyThemeDPrimary;
      default: return AppColors.familyThemeAPrimary;
    }
  }

  Color _themeBadgeColor(int idx) {
    switch (idx) {
      case 1: return AppColors.familyThemeBBadge;
      case 2: return AppColors.familyThemeCBadge;
      case 3: return AppColors.familyThemeDBadge;
      default: return AppColors.familyThemeABadge;
    }
  }
}
