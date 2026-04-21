import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/constants/app_text_styles.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FamilyTheme {
  static const bg = AppColors.background; 
  static const surface = AppColors.surface;
  static const accent = AppColors.primary;
  static const border = Color(0xFFE5E7EB);
}

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
      backgroundColor: FamilyTheme.bg,
      appBar: _buildAppBar(context, userAsync.value),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text("User not found"));
          if (user.familyId == null) return _buildNoFamilyView(context, user);
          
          final familyAsync = ref.watch(familyStreamProvider(user.familyId!));
          return familyAsync.when(
            data: (family) {
              if (family == null) return _buildNoFamilyView(context, user);
              return _buildFamilyDashboard(context, family, user);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserModel? user) {
    return AppBar(
      title: const Text('FAMILY PORTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: AppColors.textPrimary)),
      backgroundColor: FamilyTheme.bg,
      elevation: 0,
      centerTitle: true,
      actions: [
        if (user?.familyId != null)
           _buildJoinRequestBadge(user!.familyId!),
      ],
    );
  }

  Widget _buildJoinRequestBadge(String familyId) {
    final requestsAsync = ref.watch(pendingRequestsProvider(familyId));
    return requestsAsync.when(
      data: (requests) => requests.isEmpty ? const SizedBox.shrink() : IconButton(
        icon: Stack(
          children: [
            const Icon(Icons.notifications_rounded, color: AppColors.primary),
            Positioned(
              right: 0, top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: Text('${requests.length}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        onPressed: () => context.push(AppRoutes.joinRequests, extra: familyId),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildNoFamilyView(BuildContext context, UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCompactCard(
            color: const Color(0xFFFDF2F8),
            borderColor: const Color(0xFFFBCFE8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.shield_rounded, color: AppColors.accent, size: 40),
                ),
                const Gap(16),
                const Text('Build Your Legacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const Gap(8),
                const Text('Create or join a family to unlock exclusive battles and rewards.', 
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                const Gap(24),
                _buildActionRow(context),
              ],
            ),
          ),
          const Gap(24),
          _buildSectionHeader("DISCOVER FAMILIES", "Top Performers"),
          const Gap(12),
          ref.watch(allFamiliesProvider).when(
            data: (families) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: families.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) => _FamilyListItemLight(family: families[i], user: user),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading families'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildBlinkitButton(
            "CREATE", Icons.add_rounded, AppColors.primary, 
            () => context.push(AppRoutes.createFamily)
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildBlinkitButton(
            "JOIN", Icons.search_rounded, Colors.orange, 
            () => context.push(AppRoutes.familyList)
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyDashboard(BuildContext context, FamilyModel family, UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(family),
          const Gap(16),
          _buildStatsGrid(family),
          const Gap(16),
          _buildBlinkitBattleBanner(family),
          const Gap(24),
          _buildSectionHeader("MEMBER ROSTER", "Contribution Active"),
          const Gap(12),
          _buildMemberList(family),
          const Gap(24),
          _buildManagementSection(family, user),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _buildHeroCard(FamilyModel family) {
    return _buildCompactCard(
      color: Colors.white,
      borderColor: AppColors.divider,
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider, width: 2),
              image: family.avatarUrl != null 
                ? DecorationImage(image: CachedNetworkImageProvider(family.avatarUrl!), fit: BoxFit.cover)
                : null,
            ),
            child: family.avatarUrl == null ? const Icon(Icons.groups_rounded, color: AppColors.textTertiary) : null,
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(family.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const Gap(4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(family.tag ?? "NO TAG", style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Gap(8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    const Gap(4),
                    Text('LVL ${family.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          _buildMoreMenu(family),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(FamilyModel family) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSmallStatCard("MEMBERS", "${family.memberUids.length}", Colors.teal)),
            const Gap(12),
            Expanded(child: _buildSmallStatCard("BATTLE PTS", "${family.totalBattlePoints}", Colors.indigo)),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(child: _buildSmallStatCard("COMBAT", "${family.totalCombatPoints}", Colors.pink)),
            const Gap(12),
            Expanded(child: _buildSmallStatCard("RANK", "#${family.rank}", Colors.orange)),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(String label, String value, Color color) {
    return _buildCompactCard(
      color: color.withOpacity(0.05),
      borderColor: color.withOpacity(0.2),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Gap(4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildBlinkitBattleBanner(FamilyModel family) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.familyBattle, extra: family.id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFACC15), // Zepto/Blinkit Yellow
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: const Icon(Icons.flash_on_rounded, color: Colors.yellow, size: 24),
            ),
            const Gap(16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Battles', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('Dominate the arena now', style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(FamilyModel family) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: family.memberUids.length,
      separatorBuilder: (_, __) => const Gap(8),
      itemBuilder: (context, i) => _MemberTileLight(uid: family.memberUids[i], rank: i + 1),
    );
  }

  Widget _buildManagementSection(FamilyModel family, UserModel user) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const Text("DEVELOPER SANDBOX", style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
         const Gap(12),
         Row(
           children: [
             Expanded(child: _buildBlinkitButton("SIMULATE", Icons.science_rounded, Colors.grey, () => ref.read(familyServiceProvider).seedMockMembers(family.id))),
             const Gap(12),
             Expanded(child: _buildBlinkitButton("GIFT XP", Icons.card_giftcard_rounded, Colors.grey, () => ref.read(familyServiceProvider).simulateBattleWin(family))),
           ],
         ),
       ],
     );
  }

  Widget _buildCompactCard({required Widget child, Color? color, Color? borderColor, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor ?? AppColors.divider, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const Gap(2),
            Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const Icon(Icons.arrow_right_alt_rounded, color: AppColors.textTertiary),
      ],
    );
  }

  Widget _buildBlinkitButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const Gap(8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu(FamilyModel family) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textTertiary),
      onSelected: (val) {
        if (val == 'leave') _showLeaveDialog(context, family, ref.read(currentUserProfileProvider).value!);
        if (val == 'disband') _showDisbandDialog(context, family);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'leave', child: Text('Leave')),
        const PopupMenuItem(value: 'disband', child: Text('Disband', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  void _showLeaveDialog(BuildContext context, FamilyModel family, UserModel user) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Leave Family', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Confirm leaving ${family.name}?'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(familyServiceProvider).leaveFamily(user.uid, family.id);
              if (context.mounted) { context.pop(); context.pop(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(100, 40)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showDisbandDialog(BuildContext context, FamilyModel family) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Disband Family', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Warning: This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(familyServiceProvider).disbandFamily(family);
              if (context.mounted) { context.pop(); context.pop(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(100, 40)),
            child: const Text('Disband'),
          ),
        ],
      ),
    );
  }
}

class _MemberTileLight extends ConsumerWidget {
  final String uid;
  final int rank;
  const _MemberTileLight({required this.uid, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final userData = user as UserModel;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('$rank', style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w900, fontSize: 12))),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.background,
                backgroundImage: userData.profilePhotoUrl.isNotEmpty ? CachedNetworkImageProvider(userData.profilePhotoUrl) : null,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    Text(userData.username, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${userData.combatPoints}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 14)),
                  const Text('pts', style: TextStyle(color: AppColors.textTertiary, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FamilyListItemLight extends StatefulWidget {
  final FamilyModel family;
  final UserModel user;
  const _FamilyListItemLight({required this.family, required this.user});

  @override
  State<_FamilyListItemLight> createState() => _FamilyListItemLightState();
}

class _FamilyListItemLightState extends State<_FamilyListItemLight> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
              image: widget.family.avatarUrl != null 
                ? DecorationImage(image: CachedNetworkImageProvider(widget.family.avatarUrl!), fit: BoxFit.cover)
                : null,
            ),
            child: widget.family.avatarUrl == null ? const Icon(Icons.groups, color: AppColors.textTertiary) : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.family.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Text('${widget.family.memberUids.length} members • Rank #${widget.family.rank}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          Consumer(builder: (context, ref, _) {
            final appStatusAsync = ref.watch(userApplicationStatusProvider((userId: widget.user.uid, familyId: widget.family.id)));
            
            return appStatusAsync.when(
              data: (status) {
                final isRequested = status == JoinRequestStatus.pending;
                final isJoined = widget.family.memberUids.contains(widget.user.uid);
                
                String label = 'JOIN';
                Color color = AppColors.primary;
                if (isJoined) {
                  label = 'JOINED';
                  color = Colors.green;
                } else if (isRequested) {
                  label = 'REQUESTED';
                  color = Colors.orange;
                }

                return GestureDetector(
                  onTap: (_isJoining || isRequested || isJoined) ? null : () async {
                    setState(() => _isJoining = true);
                    try {
                      await ref.read(familyServiceProvider).applyToJoin(
                        userId: widget.user.uid,
                        familyId: widget.family.id,
                        userName: widget.user.displayName,
                        userAvatar: widget.user.profilePhotoUrl,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Join request sent to ${widget.family.name}!"),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isJoining = false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isJoining ? Colors.grey : color, 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: _isJoining 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                );
              },
              loading: () => Container(width: 60, height: 30, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12))),
              error: (_, __) => const Text("?"),
            );
          }),
        ],
      ),
    );
  }
}
