import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/models/family_member_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/constants/family_light_theme.dart';

class FamilyMembersScreen extends ConsumerWidget {
  final String familyId;
  const FamilyMembersScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider(familyId));

    return Scaffold(
      backgroundColor: FamilyLight.pageBg,
      appBar: AppBar(
        backgroundColor: FamilyLight.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FamilyLight.fill,
              shape: BoxShape.circle,
              border: Border.all(color: FamilyLight.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: FamilyLight.ink, size: 16),
          ),
        ),
        title: const Text('MEMBERS',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
                color: FamilyLight.ink)),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FamilyLight.fill,
                      border: Border.all(color: FamilyLight.border),
                    ),
                    child: const Icon(Icons.people_outline_rounded,
                        size: 40,
                        color: FamilyLight.faint),
                  ),
                  const Gap(16),
                  const Text('No members yet',
                      style: TextStyle(
                          color: FamilyLight.muted,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Gap(6),
            itemBuilder: (context, index) =>
                _MemberTile(member: members[index], rank: index + 1),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: FamilyLight.gold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: FamilyLight.red))),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final FamilyMemberModel member;
  final int rank;
  const _MemberTile({required this.member, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(cachedUserProfileProvider(member.userId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return _buildTile(user);
      },
      loading: () => Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FamilyLight.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(color: FamilyLight.card.withOpacity(0.5)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTile(UserModel user) {
    final isTop3 = rank <= 3;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FamilyLight.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: isTop3
              ? FamilyLight.gold.withOpacity(0.04)
              : FamilyLight.card.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isTop3
                      ? FamilyLight.gold.withOpacity(0.15)
                      : FamilyLight.border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$rank',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: isTop3
                              ? FamilyLight.gold
                              : FamilyLight.muted)),
                ),
              ),
              const Gap(10),
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isTop3
                          ? FamilyLight.gold.withOpacity(0.3)
                          : FamilyLight.border),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.profilePhotoUrl.isNotEmpty
                        ? user.profilePhotoUrl
                        : 'https://api.dicebear.com/7.x/avataaars/png?seed=${user.uid}',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: FamilyLight.fill),
                    errorWidget: (_, __, ___) => Container(
                      color: FamilyLight.fill,
                      child: const Icon(Icons.person,
                          size: 18, color: FamilyLight.muted),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            style: TextStyle(
                              color: FamilyLight.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(6),
                        _buildLevelBadge(member.memberLevel),
                      ],
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            color: FamilyLight.gold, size: 11),
                        const Gap(3),
                        Text('${_formatNumber(member.combatPoints)} CP',
                            style: TextStyle(
                                color: FamilyLight.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const Gap(12),
                        Icon(Icons.diamond_rounded,
                            color: FamilyLight.gold, size: 11),
                        const Gap(3),
                        Text('${_formatNumber(member.totalDiamondsSent)}💎',
                            style: const TextStyle(
                                color: FamilyLight.muted,
                                fontSize: 11)),
                        const Gap(8),
                        Text('${_formatNumber(member.totalBattlePoints)}pts',
                            style: const TextStyle(
                                color: FamilyLight.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FamilyLight.red, Color(0xFFFF6B6B)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: FamilyLight.red.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text('$level',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900)),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
