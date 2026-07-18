import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/models/family_member_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/widgets/family_progress_bar.dart';
import 'package:hello_chat/core/router/app_router.dart';

class FamilyDetailScreen extends ConsumerStatefulWidget {
  final String familyId;
  const FamilyDetailScreen({super.key, required this.familyId});

  @override
  ConsumerState<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends ConsumerState<FamilyDetailScreen> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(familyStreamProvider(widget.familyId));
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: AppColors.familyBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.familySurface.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.familyText, size: 16),
          ),
        ),
        title: const Text('CLAN PROFILE',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
                color: AppColors.familyText)),
        centerTitle: true,
      ),
      body: familyAsync.when(
        data: (family) {
          if (family == null) {
            return const Center(
                child: Text('Family not found',
                    style: TextStyle(color: AppColors.familyTextSecondary)));
          }
          final isMember =
              currentUid != null && family.memberUids.contains(currentUid);
          return _buildContent(family, currentUid, isMember);
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.familyGold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.familyText))),
      ),
    );
  }

  Widget _buildContent(
      FamilyModel family, String? currentUid, bool isMember) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(family),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(family),
                const Gap(16),
                _buildRankSection(family),
                const Gap(16),
                _buildMonthlyTarget(family),
                const Gap(16),
                _buildMembersPreview(family),
                const Gap(20),
                if (!isMember) _buildJoinButton(family, currentUid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FamilyModel family) {
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.familySurface,
            AppColors.familyBg,
          ],
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      badgeColor.withOpacity(0.25),
                      AppColors.familySurface,
                    ],
                  ),
                ),
                child: family.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: family.bannerUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Icon(Icons.shield_rounded,
                            color: badgeColor.withOpacity(0.3),
                            size: 48)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.familySurface,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: badgeColor, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: badgeColor.withOpacity(0.3),
                      blurRadius: 20),
                ],
              ),
              child: ClipOval(
                child: family.avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: family.avatarUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.familyCard,
                        child: Icon(Icons.shield,
                            color: badgeColor, size: 40)),
              ),
            ),
          ),
          const Gap(14),
          Text(family.name,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.familyText,
                  letterSpacing: 0.5)),
          if (family.country.isNotEmpty) ...[
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: AppColors.familyTextSecondary),
                const Gap(4),
                Text(family.country,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.familyTextSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(FamilyModel family) {
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badgeColor.withOpacity(0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: AppColors.familySurface.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(Icons.people_rounded,
                  '${family.memberCount ?? 0}', 'MEMBERS', badgeColor),
              _buildStatDivider(),
              _buildStatItem(Icons.emoji_events_rounded,
                  family.rankName ?? '-', 'RANK', badgeColor),
              _buildStatDivider(),
              _buildStatItem(Icons.local_fire_department_rounded,
                  _formatCompact(family.totalCombatPoints ?? 0), 'CP', badgeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const Gap(6),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: AppColors.familyText)),
        const Gap(2),
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppColors.familyTextSecondary,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white10,
    );
  }

  Widget _buildRankSection(FamilyModel family) {
    final level = family.level;
    final badgeColor = FamilyModel.badgeColorForLevel(level);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badgeColor.withOpacity(0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: AppColors.familySurface.withOpacity(0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.emoji_events_rounded,
                        color: badgeColor, size: 22),
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(family.rankName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              letterSpacing: 0.5)),
                      Text('Lv$level',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.familyTextSecondary)),
                    ],
                  ),
                ],
              ),
              const Gap(14),
              FamilyRankProgressBar(
                currentPoints: family.totalCombatPoints,
                requiredPoints: FamilyModel.pointsForNextLevel(level),
                height: 10,
                fillColor: badgeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyTarget(FamilyModel family) {
    final ratio = family.monthlyTarget > 0
        ? (family.currentMonthPoints / family.monthlyTarget).clamp(0.0, 1.0)
        : 0.0;
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badgeColor.withOpacity(0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: AppColors.familySurface.withOpacity(0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('MONTHLY TARGET',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.familyTextSecondary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  if (family.monthlyTargetCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF22C55E).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 10, color: Color(0xFF22C55E)),
                          const Gap(3),
                          const Text('COMPLETED',
                              style: TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Icon(Icons.diamond_rounded,
                      color: badgeColor, size: 16),
                  const Gap(6),
                  Text(_formatNumber(family.currentMonthPoints),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: badgeColor)),
                  Text(' / ${_formatNumber(family.monthlyTarget)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.familyTextSecondary)),
                ],
              ),
              const Gap(10),
              FamilyProgressBar(ratio: ratio, height: 8, fillColor: badgeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersPreview(FamilyModel family) {
    final membersAsync = ref.watch(familyMembersProvider(family.id));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: AppColors.familySurface.withOpacity(0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('MEMBERS',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.familyTextSecondary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900)),
                  const Gap(8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.familyGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${family.memberCount} / ${family.memberLimit}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.familyGold,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const Gap(12),
              membersAsync.when(
                data: (members) {
                  final display = members.take(6).toList();
                  return SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        ...List.generate(display.length, (i) {
                          return Align(
                            widthFactor: i == 0 ? 1 : 0.7,
                            child: _buildSmallAvatar(display[i]),
                          );
                        }),
                        if (members.length > 6)
                          Align(
                            widthFactor: 0.7,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.familyCard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.familyGold
                                        .withOpacity(0.3)),
                              ),
                              child: Center(
                                child: Text('+${members.length - 6}',
                                    style: const TextStyle(
                                        color: AppColors.familyGold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 42),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAvatar(FamilyMemberModel member) {
    final userAsync = ref.watch(cachedUserProfileProvider(member.userId));
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.familyGold.withOpacity(0.2)),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.profilePhotoUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.familyCard,
                child: const Icon(Icons.person,
                    size: 16, color: AppColors.familyTextSecondary),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
              color: AppColors.familyCard, shape: BoxShape.circle)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildJoinButton(FamilyModel family, String? currentUid) {
    if (currentUid == null) return const SizedBox.shrink();

    final appStatusAsync = ref.watch(
        userApplicationStatusProvider(
            (userId: currentUid, familyId: family.id)));

    return appStatusAsync.when(
      data: (status) {
        final isRequested = status == JoinRequestStatus.pending;
        final isFull = family.isFull;

        String label = 'APPLY TO JOIN';
        bool enabled = true;

        if (isRequested) {
          label = 'REQUEST PENDING';
          enabled = false;
        } else if (isFull) {
          label = 'FAMILY FULL';
          enabled = false;
        }

        return GestureDetector(
          onTap: enabled ? () => _showJoinConfirmDialog(family, currentUid) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: [
                        AppColors.familyGold,
                        AppColors.familyGold.withOpacity(0.8),
                      ],
                    )
                  : null,
              color: enabled ? null : Colors.white10,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.familyGold.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRequested
                              ? Icons.hourglass_empty_rounded
                              : isFull
                                  ? Icons.lock_rounded
                                  : Icons.add_rounded,
                          size: 18,
                          color:
                              enabled ? Colors.black : AppColors.familyTextSecondary,
                        ),
                        const Gap(8),
                        Text(label,
                            style: TextStyle(
                                color: enabled
                                    ? Colors.black
                                    : AppColors.familyTextSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1)),
                      ],
                    ),
            ),
          ),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.familyGold)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showJoinConfirmDialog(FamilyModel family, String currentUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.familySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.familyGold, width: 1),
        ),
        title: const Text('Join Clan',
            style: TextStyle(
                color: AppColors.familyText,
                fontWeight: FontWeight.w900)),
        content: Text('Apply to join ${family.name}?',
            style: const TextStyle(color: AppColors.familyTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.familyTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              context.pop();
              setState(() => _isJoining = true);
              try {
                final user = ref.read(currentUserProfileProvider).value;
                if (user == null) return;
                await ref.read(familyServiceProvider).applyToJoin(
                      userId: currentUid,
                      familyId: family.id,
                      userName: user.displayName,
                      userAvatar: user.profilePhotoUrl,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Request sent to ${family.name}!'),
                      backgroundColor: const Color(0xFF22C55E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.familyRed),
                  );
                }
              } finally {
                if (mounted) setState(() => _isJoining = false);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.familyGold),
            child: const Text('Apply',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
