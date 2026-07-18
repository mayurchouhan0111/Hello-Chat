import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/models/family_member_model.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/models/family_battle_request_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/family_progress_bar.dart';
import 'package:hello_chat/core/widgets/family_battle_card.dart';
import 'package:hello_chat/core/widgets/member_level_info_dialog.dart';
class FamilyPortalScreen extends ConsumerStatefulWidget {
  const FamilyPortalScreen({super.key});

  @override
  ConsumerState<FamilyPortalScreen> createState() => _FamilyPortalScreenState();
}

class _FamilyPortalScreenState extends ConsumerState<FamilyPortalScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.familyBg,
      appBar: _buildAppBar(),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
                child: Text("User not found",
                    style: TextStyle(color: AppColors.familyText)));
          }
          if (user.familyId == null) return _buildNoFamilyView(user);

          final familyAsync = ref.watch(familyStreamProvider(user.familyId!));
          return familyAsync.when(
            data: (family) {
              if (family == null) return _buildNoFamilyView(user);
              return _buildFamilyDashboard(family, user);
            },
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.familyGold)),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.familyText))),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.familyGold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.familyText))),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
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
      title: const Text('CLAN COMMAND',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2,
              color: AppColors.familyText)),
    );
  }

  // ─── No Family View ───────────────────────────────────────────
  Widget _buildNoFamilyView(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Gap(40),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Container(
                color: AppColors.familySurface.withOpacity(0.5),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.familyCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.familyGold.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: AppColors.familyGold, size: 52),
                    ),
                    const Gap(20),
                    const Text('Build Your Legacy',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.familyText,
                            letterSpacing: 0.5)),
                    const Gap(8),
                    const Text(
                      'Create or join a family to unlock\nexclusive battles and rewards.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.familyTextSecondary,
                          fontSize: 13,
                          height: 1.5),
                    ),
                    const Gap(28),
                    Row(
                      children: [
                        Expanded(
                            child: _buildActionButton('CREATE',
                                Icons.add_rounded, () {
                          context.push(AppRoutes.createFamily);
                        }, isPrimary: true)),
                        const Gap(12),
                        Expanded(
                            child: _buildActionButton('DISCOVER',
                                Icons.search_rounded, () {
                          context.push(AppRoutes.familyList);
                        }, isPrimary: false)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(32),
          _buildSectionHeader('TOP CLANS'),
          const Gap(12),
          ref.watch(allFamiliesProvider).when(
            data: (families) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: families.length,
              separatorBuilder: (_, __) => const Gap(10),
              itemBuilder: (context, i) =>
                  _FamilyCard(family: families[i], user: user),
            ),
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.familyGold)),
            error: (_, __) => const Text('Error loading families',
                style:
                    TextStyle(color: AppColors.familyTextSecondary)),
          ),
        ],
      ),
    );
  }

  // ─── Dashboard ────────────────────────────────────────────────
  Widget _buildFamilyDashboard(FamilyModel family, UserModel user) {
    final membersAsync = ref.watch(familyMembersProvider(family.id));
    final myMemberAsync = ref.watch(
        familyMemberProvider((familyId: family.id, userId: user.uid)));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFamilyHeader(family),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FamilyBattleCard(
                  familyId: family.id,
                  onTap: () => context.push(AppRoutes.familyBattle, extra: family.id),
                ),
                const Gap(16),
                _buildQuickStats(family),
                const Gap(16),
                _buildRankSection(family),
                const Gap(16),
                _buildMonthlyTarget(family),
                const Gap(16),
                _buildMembersSection(family, membersAsync),
                const Gap(16),
                _buildMyLevelSection(myMemberAsync, family),
                const Gap(16),
                _buildBattleRequestsSection(family, user),
                _buildManagementSection(family, user),
                const Gap(16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────
  Widget _buildFamilyHeader(FamilyModel family) {
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.familySurface, AppColors.familyBg],
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
                      colors: [Colors.transparent, AppColors.familySurface],
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
                border: Border.all(color: badgeColor, width: 3),
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

  // ─── Quick Stats ──────────────────────────────────────────────
  Widget _buildQuickStats(FamilyModel family) {
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
              _buildStatItem(
                  Icons.people_rounded, '${family.memberCount ?? 0}', 'MEMBERS', badgeColor),
              _buildStatDivider(),
              _buildStatItem(Icons.emoji_events_rounded, family.rankName ?? '-',
                  'RANK', badgeColor),
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
    return Container(width: 1, height: 40, color: Colors.white10);
  }

  // ─── Rank ─────────────────────────────────────────────────────
  Widget _buildRankSection(FamilyModel family) {
    final level = family.level;
    final badgeColor = FamilyModel.badgeColorForLevel(level);
    final currentPoints = family.totalCombatPoints;
    final requiredPoints = FamilyModel.pointsForNextLevel(level);

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
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Lv${level + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: badgeColor)),
                  ),
                ],
              ),
              const Gap(14),
              FamilyRankProgressBar(
                currentPoints: currentPoints,
                requiredPoints: requiredPoints,
                height: 10,
                fillColor: badgeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Monthly Target ──────────────────────────────────────────
  Widget _buildMonthlyTarget(FamilyModel family) {
    final ratio = family.monthlyTarget > 0
        ? (family.currentMonthPoints / family.monthlyTarget).clamp(0.0, 1.0)
        : 0.0;
    final completed = family.monthlyTargetCompleted;
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
                  const Gap(6),
                  Icon(Icons.info_outline,
                      color: AppColors.familyTextSecondary, size: 14),
                  const Spacer(),
                  if (completed)
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
                          const Text('DONE',
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

  // ─── Members ──────────────────────────────────────────────────
  Widget _buildMembersSection(
      FamilyModel family, AsyncValue<List<FamilyMemberModel>> membersAsync) {
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
              GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.familyMembers, extra: family.id),
                child: Row(
                  children: [
                    const Text('MEMBERS',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.familyTextSecondary,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900)),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.familyGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                          '${family.memberCount} / ${family.memberLimit}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.familyGold,
                              fontWeight: FontWeight.w900)),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.familyTextSecondary, size: 20),
                  ],
                ),
              ),
              const Gap(12),
              membersAsync.when(
                data: (members) {
                  final display = members.take(3).toList();
                  return Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            _buildInviteAvatar(),
                            const Gap(4),
                            ...List.generate(display.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _buildMemberAvatar(display[i]),
                              );
                            }),
                            if (members.length > 3)
                              GestureDetector(
                                onTap: () => context.push(AppRoutes.familyMembers,
                                    extra: family.id),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.familyCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.familyGold
                                            .withOpacity(0.3)),
                                  ),
                                  child: Center(
                                    child: Text('+${members.length - 3}',
                                        style: const TextStyle(
                                            color: AppColors.familyGold,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Gap(8),
                      ...display.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.diamond_rounded, size: 10, color: AppColors.familyGold),
                            const Gap(4),
                            Expanded(
                              child: Text(
                                '${m.totalDiamondsSent} diamonds | ${_formatCompact(m.totalBattlePoints)} pts',
                                style: const TextStyle(
                                  color: AppColors.familyTextSecondary,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 44),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.familyCard,
        shape: BoxShape.circle,
        border:
            Border.all(color: AppColors.familyGold.withOpacity(0.5), width: 1.5),
      ),
      child: const Icon(Icons.add, color: AppColors.familyGold, size: 22),
    );
  }

  Widget _buildMemberAvatar(FamilyMemberModel member) {
    final userAsync = ref.watch(cachedUserProfileProvider(member.userId));
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.familyGold.withOpacity(0.2)),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.profilePhotoUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  color: AppColors.familyCard),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.familyCard,
                child: const Icon(Icons.person,
                    color: AppColors.familyTextSecondary, size: 18),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
              color: AppColors.familyCard, shape: BoxShape.circle)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── My Level ─────────────────────────────────────────────────
  Widget _buildMyLevelSection(
      AsyncValue<FamilyMemberModel?> memberAsync, FamilyModel family) {
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
                  const Text('MY PROGRESS',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.familyTextSecondary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.familyTextSecondary, size: 20),
                ],
              ),
              const Gap(12),
              memberAsync.when(
                data: (member) {
                  if (member == null) {
                    return const Text('Not a member',
                        style: TextStyle(
                            color: AppColors.familyTextSecondary));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildLevelBadge(member.memberLevel),
                          const Gap(10),
                          Text('Level ${member.memberLevel}',
                              style: const TextStyle(
                                  color: AppColors.familyText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text('Lv${member.memberLevel + 1}',
                              style: const TextStyle(
                                  color: AppColors.familyRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const Gap(10),
                      FamilyRankProgressBar(
                        currentPoints: member.memberXP,
                        requiredPoints: member.xpToNextLevel,
                        height: 8,
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Icon(Icons.diamond_rounded,
                              color: AppColors.familyGold, size: 12),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              '${_formatNumber(member.totalDiamondsSent)} diamonds | ${_formatNumber(member.totalBattlePoints)} pts',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.familyTextSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 60),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    return GestureDetector(
      onTap: () => MemberLevelInfoDialog.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.familyRed,
              const Color(0xFFFF6B6B),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.familyRed.withOpacity(0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text('$level',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ─── Battle Requests ──────────────────────────────────────────
  Widget _buildBattleRequestsSection(FamilyModel family, UserModel user) {
    final isOwner = family.ownerId == user.uid || user.isFamilyOwner;
    if (!isOwner) return const SizedBox.shrink();

    final incomingAsync = ref.watch(incomingBattleRequestsProvider(family.id));
    return incomingAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.familyRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('BATTLE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1)),
                  ),
                  const Gap(8),
                  const Text('INCOMING CHALLENGES',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.familyTextSecondary,
                          letterSpacing: 0.5)),
                ],
              ),
              const Gap(10),
              ...requests.map((req) => _BattleRequestCard(
                    request: req,
                    familyId: family.id,
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }



  // ─── Management Actions ───────────────────────────────────────
  Widget _buildManagementSection(FamilyModel family, UserModel user) {
    final isOwner = family.ownerId == user.uid;
    final isAdmin = isOwner || user.isFamilyOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          _buildSectionHeader('MANAGEMENT'),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('INVITE',
                    Icons.person_add_outlined, () => _showInviteDialog(family),
                    isPrimary: true),
              ),
              const Gap(10),
              Expanded(
                child: _buildActionButton('REQUESTS', Icons.mail_outline,
                    () {
                  context.push(AppRoutes.joinRequests, extra: family.id);
                }, isPrimary: false),
              ),
            ],
          ),
          const Gap(10),
        ],
        if (isAdmin) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton('KICK', Icons.person_remove_outlined,
                    () => _showKickMemberDialog(family),
                    isDestructive: true),
              ),
              const Gap(10),
              Expanded(
                child: _buildActionButton('PROMOTE', Icons.arrow_upward,
                    () => _showPromoteAdminDialog(family),
                    isPrimary: true),
              ),
            ],
          ),
          const Gap(10),
        ],
        if (isOwner) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton('SETTINGS', Icons.settings,
                    () => _showEditSettingsDialog(family),
                    isPrimary: false),
              ),
            ],
          ),
          const Gap(10),
        ],
        if (!isOwner) ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                    'LEAVE', Icons.exit_to_app_rounded,
                    () => _showLeaveDialog(family, user),
                    isDestructive: true),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap,
      {bool isPrimary = false, bool isDestructive = false}) {
    final color = isDestructive
        ? AppColors.familyRed
        : isPrimary
            ? AppColors.familyGold
            : AppColors.familyTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const Gap(6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.familyGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Text(title,
            style: const TextStyle(
                color: AppColors.familyTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
      ],
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────
  void _showInviteDialog(FamilyModel family) {
    final uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        var errorText = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Invite Member',
                style: TextStyle(
                    color: AppColors.familyText,
                    fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the User ID to invite:',
                    style: TextStyle(
                        color: AppColors.familyTextSecondary,
                        fontSize: 13)),
                const Gap(12),
                TextField(
                  controller: uidController,
                  style: const TextStyle(color: AppColors.familyText),
                  decoration: InputDecoration(
                    hintText: 'User ID',
                    hintStyle:
                        const TextStyle(color: AppColors.familyTextSecondary),
                    filled: true,
                    fillColor: AppColors.familyCard,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                if (errorText.isNotEmpty) ...[
                  const Gap(8),
                  Text(errorText,
                      style: const TextStyle(
                          color: AppColors.familyRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel',
                    style:
                        TextStyle(color: AppColors.familyTextSecondary)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final uid = uidController.text.trim();
                        if (uid.isEmpty) {
                          setDialogState(
                              () => errorText = 'Please enter a User ID');
                          return;
                        }
                        setDialogState(
                            () { loading = true; errorText = ''; });
                        try {
                          await ref
                              .read(familyServiceProvider)
                              .addMember(family.id, uid);
                          if (context.mounted) {
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Member added!')));
                          }
                        } catch (e) {
                          setDialogState(() {
                            loading = false;
                            errorText = e.toString();
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.familyGold,
                    foregroundColor: Colors.black),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Invite'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showLeaveDialog(FamilyModel family, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Leave Family',
                style: TextStyle(
                    color: AppColors.familyText,
                    fontWeight: FontWeight.w900)),
            content: Text('Leave ${family.name}?',
                style: const TextStyle(
                    color: AppColors.familyTextSecondary)),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel',
                    style:
                        TextStyle(color: AppColors.familyTextSecondary)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        await ref
                            .read(familyServiceProvider)
                            .leaveFamily(user.uid, family.id);
                        if (context.mounted) {
                          context.pop();
                          context.pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.familyRed),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Leave'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDisbandDialog(FamilyModel family) {
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyRed, width: 1),
            ),
            title: const Text('Disband Clan',
                style: TextStyle(
                    color: AppColors.familyText,
                    fontWeight: FontWeight.w900)),
            content: const Text(
                'This action is irreversible. All members will be removed.',
                style: TextStyle(
                    color: AppColors.familyTextSecondary)),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel',
                    style:
                        TextStyle(color: AppColors.familyTextSecondary)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        await ref
                            .read(familyServiceProvider)
                            .disbandFamily(family);
                        if (context.mounted) {
                          context.pop();
                          context.pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.familyRed),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Disband'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showKickMemberDialog(FamilyModel family) {
    final membersAsync = ref.read(familyMembersProvider(family.id));
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyRed, width: 1),
            ),
            title: const Text('Kick Member',
                style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900)),
            content: membersAsync.when(
              data: (members) {
                final nonOwner = members.where((m) => !m.isOwner).toList();
                if (nonOwner.isEmpty) return const Text('No members to kick.',
                    style: TextStyle(color: AppColors.familyTextSecondary));
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: nonOwner.length,
                    itemBuilder: (_, i) {
                      final userId = nonOwner[i].userId;
                      final isUserLoading = loading == userId;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person, color: AppColors.familyTextSecondary),
                        ),
                        title: Text(userId,
                            style: const TextStyle(color: AppColors.familyText, fontSize: 13)),
                        subtitle: Text(nonOwner[i].role,
                            style: const TextStyle(color: AppColors.familyTextSecondary)),
                        trailing: isUserLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.person_remove, color: AppColors.familyRed),
                                onPressed: () async {
                                  setDialogState(() => loading = userId);
                                  await ref.read(familyServiceProvider).kickMember(family.id, userId);
                                  if (ctx.mounted) setDialogState(() => loading = '');
                                },
                              ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.familyRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.familyTextSecondary)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showPromoteAdminDialog(FamilyModel family) {
    final membersAsync = ref.read(familyMembersProvider(family.id));
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Manage Admin',
                style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900)),
            content: membersAsync.when(
              data: (members) {
                final eligible = members.where((m) => !m.isOwner).toList();
                if (eligible.isEmpty) return const Text('No other members.',
                    style: TextStyle(color: AppColors.familyTextSecondary));
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: eligible.length,
                    itemBuilder: (_, i) {
                      final m = eligible[i];
                      final isAdmin = m.isAdmin;
                      final isUserLoading = loading == m.userId;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: isAdmin ? AppColors.familyGold : AppColors.familyTextSecondary),
                        ),
                        title: Text(m.userId,
                            style: const TextStyle(color: AppColors.familyText, fontSize: 13)),
                        subtitle: Text(isAdmin ? 'Admin' : 'Member',
                            style: const TextStyle(color: AppColors.familyTextSecondary)),
                        trailing: isUserLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : TextButton(
                                onPressed: () async {
                                  setDialogState(() => loading = m.userId);
                                  if (isAdmin) {
                                    await ref.read(familyServiceProvider).demoteAdmin(family.id, m.userId);
                                  } else {
                                    await ref.read(familyServiceProvider).promoteAdmin(family.id, m.userId);
                                  }
                                  if (ctx.mounted) setDialogState(() => loading = '');
                                },
                                child: Text(isAdmin ? 'Demote' : 'Promote',
                                    style: TextStyle(
                                        color: isAdmin ? AppColors.familyRed : AppColors.success,
                                        fontWeight: FontWeight.w900)),
                              ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.familyRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.familyTextSecondary)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showTransferOwnershipDialog(FamilyModel family) {
    final membersAsync = ref.read(familyMembersProvider(family.id));
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Transfer Ownership',
                style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900)),
            content: membersAsync.when(
              data: (members) {
                final eligible = members.where((m) => m.userId != family.ownerId).toList();
                if (eligible.isEmpty) return const Text('No other members.',
                    style: TextStyle(color: AppColors.familyTextSecondary));
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: eligible.length,
                    itemBuilder: (_, i) {
                      final userId = eligible[i].userId;
                      final isUserLoading = loading == userId;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.swap_horiz, color: AppColors.familyGold)),
                        title: Text(userId,
                            style: const TextStyle(color: AppColors.familyText, fontSize: 13)),
                        subtitle: Text('Tap to transfer ownership',
                            style: const TextStyle(color: AppColors.familyTextSecondary)),
                        trailing: isUserLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward, color: AppColors.familyGold),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: ctx,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: AppColors.familySurface,
                                      title: const Text('Confirm?', style: TextStyle(color: AppColors.familyText)),
                                      content: Text('Transfer ownership to $userId?',
                                          style: const TextStyle(color: AppColors.familyTextSecondary)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(c, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.familyGold),
                                            child: const Text('Transfer')),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  setDialogState(() => loading = userId);
                                  await ref.read(familyServiceProvider).transferOwnership(family.id, userId);
                                  if (ctx.mounted) setDialogState(() => loading = '');
                                },
                              ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.familyRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.familyTextSecondary)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditSettingsDialog(FamilyModel family) {
    final noticeCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    var selectedMode = family.joinMode;
    var monthlyTarget = family.monthlyTarget;

    showDialog(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Edit Settings',
                style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notice', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                  const Gap(4),
                  TextField(
                    controller: noticeCtrl, maxLines: 3,
                    style: const TextStyle(color: AppColors.familyText, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.familyCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const Gap(12),
                  const Text('Tag', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                  const Gap(4),
                  TextField(
                    controller: tagCtrl, maxLength: 4,
                    style: const TextStyle(color: AppColors.familyText, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.familyCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      counterText: '',
                    ),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      const Text('Join Mode: ', style: TextStyle(color: AppColors.familyText, fontSize: 13)),
                      const Gap(8),
                      DropdownButton<JoinMode>(
                        value: selectedMode,
                        dropdownColor: AppColors.familyCard,
                        style: const TextStyle(color: AppColors.familyText),
                        items: JoinMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                    ],
                  ),
                  const Gap(12),
                  const Text('Monthly Target', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                  const Gap(4),
                  TextField(
                    controller: TextEditingController(text: monthlyTarget.toString()),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.familyText, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.familyCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => monthlyTarget = int.tryParse(v) ?? monthlyTarget,
                  ),
                  const Gap(16),
                  const Text('FAMILY POLICIES', style: TextStyle(color: AppColors.familyGold, fontSize: 12, fontWeight: FontWeight.w900)),
                  const Gap(8),
                  Consumer(builder: (context, ref, _) {
                    final policiesAsync = ref.watch(familyPoliciesProvider(family.id));
                    return policiesAsync.when(
                      data: (policies) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...policies.asMap().entries.map((entry) {
                            final i = entry.key;
                            final p = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.familyCard,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.title, style: const TextStyle(color: AppColors.familyText, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(p.description, style: const TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      await ref.read(familyServiceProvider).removeFamilyPolicy(family.id, i);
                                      ref.invalidate(familyPoliciesProvider(family.id));
                                    },
                                    child: const Icon(Icons.close, color: AppColors.familyRed, size: 18),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Gap(4),
                          GestureDetector(
                            onTap: () => _showAddPolicyDialog(family),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.familyGold.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: AppColors.familyGold, size: 16),
                                  Gap(4),
                                  Text('Add Policy', style: TextStyle(color: AppColors.familyGold, fontSize: 11, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(height: 30, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.familyGold))),
                      error: (_, __) => const SizedBox(height: 30),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.familyTextSecondary)),
              ),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  setDialogState(() => saving = true);
                  await ref.read(familyServiceProvider).updateFamilySettings(family.id,
                    notice: noticeCtrl.text,
                    tag: tagCtrl.text.toUpperCase(),
                    joinMode: selectedMode,
                    monthlyTarget: monthlyTarget,
                  );
                  if (ctx.mounted) context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.familyGold, foregroundColor: Colors.black),
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showAddPolicyDialog(FamilyModel family) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        var adding = false;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.familySurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.familyGold, width: 1),
            ),
            title: const Text('Add Policy',
                style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Title', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                const Gap(4),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppColors.familyText, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.familyCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const Gap(12),
                const Text('Description', style: TextStyle(color: AppColors.familyTextSecondary, fontSize: 11)),
                const Gap(4),
                TextField(
                  controller: descCtrl, maxLines: 3,
                  style: const TextStyle(color: AppColors.familyText, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.familyCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: adding ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.familyTextSecondary)),
              ),
              ElevatedButton(
                onPressed: adding ? null : () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  setDialogState(() => adding = true);
                  await ref.read(familyServiceProvider).addFamilyPolicy(family.id, titleCtrl.text.trim(), descCtrl.text.trim());
                  ref.invalidate(familyPoliciesProvider(family.id));
                  if (ctx.mounted) context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.familyGold, foregroundColor: Colors.black),
                child: adding
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Add'),
              ),
            ],
          );
        });
      },
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

// ─── Family Discovery Card ──────────────────────────────────────
class _FamilyCard extends ConsumerStatefulWidget {
  final FamilyModel family;
  final UserModel user;
  const _FamilyCard({required this.family, required this.user});

  @override
  ConsumerState<_FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends ConsumerState<_FamilyCard> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final user = widget.user;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.familyDetail, extra: family.id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Container(
            color: AppColors.familySurface.withOpacity(0.5),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.familyGold.withOpacity(0.15)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: family.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: family.avatarUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover)
                        : Container(
                            color: AppColors.familyCard,
                            child: const Icon(Icons.shield,
                                color: AppColors.familyGold, size: 24)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(family.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppColors.familyText)),
                      const Gap(3),
                      Row(
                        children: [
                          Icon(Icons.people_rounded,
                              size: 10,
                              color: AppColors.familyTextSecondary),
                          const Gap(4),
                          Text('${family.memberCount} members',
                              style: const TextStyle(
                                  color: AppColors.familyTextSecondary,
                                  fontSize: 11)),
                          const Gap(10),
                          Icon(Icons.emoji_events_rounded,
                              size: 10, color: AppColors.familyGold),
                          const Gap(3),
                          Text(family.rankName,
                              style: const TextStyle(
                                  color: AppColors.familyGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                Consumer(builder: (context, ref, _) {
                  final appStatusAsync = ref.watch(
                      userApplicationStatusProvider((
                        userId: user.uid,
                        familyId: family.id,
                      )));
                  return appStatusAsync.when(
                    data: (status) {
                      final isJoined =
                          family.memberUids.contains(user.uid);
                      final isRequested =
                          status == JoinRequestStatus.pending;
                      String label = 'JOIN';
                      Color color = AppColors.familyGold;
                      bool enabled = true;
                      if (isJoined) {
                        label = 'JOINED';
                        color = const Color(0xFF22C55E);
                        enabled = false;
                      } else if (isRequested) {
                        label = 'PENDING';
                        color = Colors.orange;
                        enabled = false;
                      }
                      return GestureDetector(
                        onTap: enabled && !_isJoining
                            ? () async {
                                setState(() => _isJoining = true);
                                await ref
                                    .read(familyServiceProvider)
                                    .applyToJoin(
                                      userId: user.uid,
                                      familyId: family.id,
                                      userName: user.displayName,
                                      userAvatar: user.profilePhotoUrl,
                                    );
                                if (mounted) {
                                  setState(() => _isJoining = false);
                                }
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: enabled
                                ? color
                                : color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: enabled
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : Text(label,
                                  style: TextStyle(
                                      color: enabled
                                          ? Colors.black
                                          : color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 0.5)),
                        ),
                      );
                    },
                    loading: () => const SizedBox(width: 50, height: 24),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleRequestCard extends ConsumerStatefulWidget {
  final FamilyBattleRequestModel request;
  final String familyId;

  const _BattleRequestCard({
    required this.request,
    required this.familyId,
  });

  @override
  ConsumerState<_BattleRequestCard> createState() => _BattleRequestCardState();
}

class _BattleRequestCardState extends ConsumerState<_BattleRequestCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.familyGold.withOpacity(0.15)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: AppColors.familySurface.withOpacity(0.5),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.familyGold.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: req.challengerAvatar != null
                      ? CachedNetworkImage(
                          imageUrl: req.challengerAvatar!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover)
                      : Container(
                          color: AppColors.familyCard,
                          child: const Icon(Icons.shield, size: 18, color: AppColors.familyGold)),
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(req.challengerName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.familyText)),
                    const Text('challenges you!',
                        style: TextStyle(fontSize: 11, color: AppColors.familyTextSecondary)),
                  ],
                ),
              ),
              if (_isRejecting || _isAccepting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.familyGold),
                )
              else ...[
                GestureDetector(
                  onTap: _isAccepting ? null : () => _handleReject(req),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.familyRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, size: 18, color: AppColors.familyRed),
                  ),
                ),
                const Gap(6),
                GestureDetector(
                  onTap: _isRejecting ? null : () => _handleAccept(req),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.familyGold, AppColors.familyGold.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.familyGold.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text('FIGHT',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.black, letterSpacing: 1)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleAccept(FamilyBattleRequestModel req) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await ref.read(familyServiceProvider).acceptBattleRequest(req.id, req.challengerFamilyId, widget.familyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Battle accepted! Starting now...'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            context.push(AppRoutes.familyBattle, extra: widget.familyId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _handleReject(FamilyBattleRequestModel req) async {
    if (_isRejecting) return;
    setState(() => _isRejecting = true);
    try {
      await ref.read(familyServiceProvider).rejectBattleRequest(req.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Challenge rejected.'),
            backgroundColor: Colors.grey.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }
}
