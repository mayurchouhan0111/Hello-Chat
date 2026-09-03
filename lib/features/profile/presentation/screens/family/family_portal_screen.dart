import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/family_progress_bar.dart';
import 'package:hello_chat/core/widgets/member_level_info_dialog.dart';

// ─── Clan Command Design Tokens (Light + Royal Gold) ─────────────
const Color _cInk = Color(0xFF0F172A);
const Color _cMuted = Color(0xFF64748B);
const Color _cFaint = Color(0xFF94A3B8);
const Color _cBorder = Color(0xFFE2E8F0);
const Color _cDivider = Color(0xFFF1F5F9);
const Color _cPageBg = Color(0xFFF8FAFC);

const Color _cGold = Color(0xFFD97706);
const Color _cGoldDeep = Color(0xFFB45309);
const Color _cGoldSoft = Color(0xFFFEF3C7);
const Color _cGoldBorder = Color(0xFFFDE68A);
const Color _cPremiumGold = Color(0xFFD4AF37);
const Color _cPremiumDeep = Color(0xFF996515);

const Color _cRed = Color(0xFFDC2626);
const Color _cRedSoft = Color(0xFFFFF1F2);
const Color _cGreen = Color(0xFF059669);
const Color _cGreenSoft = Color(0xFFECFDF5);
const Color _cCyan = Color(0xFF0284C7);
const Color _cCyanSoft = Color(0xFFF0F9FF);
const Color _cBlue = Color(0xFF2563EB);
const Color _cBlueSoft = Color(0xFFEFF6FF);
const Color _cPurple = Color(0xFF9333EA);
const Color _cPurpleSoft = Color(0xFFFAF5FF);

BoxDecoration _cardDeco({Color borderColor = _cBorder}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: borderColor, width: 1.2),
  boxShadow: [
    BoxShadow(
      color: _cInk.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

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
      backgroundColor: _cPageBg,
      appBar: _buildAppBar(),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text(
                'User not found',
                style: TextStyle(color: _cMuted, fontWeight: FontWeight.w600),
              ),
            );
          }
          if (user.familyId == null) return _buildNoFamilyView(user);

          final familyAsync = ref.watch(familyStreamProvider(user.familyId!));
          return familyAsync.when(
            data: (family) {
              if (family == null) return _buildNoFamilyView(user);
              return _buildFamilyDashboard(family, user);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: _cGold),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e', style: const TextStyle(color: _cRed)),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: _cGold),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: _cRed)),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _cPageBg,
            shape: BoxShape.circle,
            border: Border.all(color: _cBorder),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _cInk,
            size: 15,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _cGoldSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: _cGold, size: 16),
          ),
          const Gap(8),
          const Text(
            'CLAN COMMAND',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 1.5,
              color: _cInk,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push(AppRoutes.familyList),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _cGoldSoft,
              shape: BoxShape.circle,
              border: Border.all(color: _cGoldBorder),
            ),
            child: const Icon(
              Icons.leaderboard_rounded,
              color: _cGold,
              size: 16,
            ),
          ),
          tooltip: 'Clan Rankings',
        ),
        const Gap(4),
      ],
    );
  }

  // ─── No Family View (Dynasty Creation/Discovery) ───────────────
  Widget _buildNoFamilyView(UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: _cardDeco().copyWith(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                // Golden Crest Ring
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_cGoldSoft, _cGoldBorder],
                    ),
                    border: Border.all(color: _cGold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _cGold.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, color: _cGold, size: 44),
                  ),
                ),
                const Gap(18),
                const Text(
                  'Forge Your Dynasty',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _cInk,
                    letterSpacing: 0.3,
                  ),
                ),
                const Gap(8),
                const Text(
                  'Establish an elite clan or enlist under a\npowerful banner for epic clan battles & perks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _cMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const Gap(24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.createFamily),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_cGold, _cGoldDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _cGold.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_moderator_rounded,
                                  color: Colors.white, size: 16),
                              Gap(6),
                              Text(
                                'CREATE CLAN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.familyList),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _cPageBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _cBorder, width: 1.2),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore_rounded, color: _cInk, size: 16),
                              Gap(6),
                              Text(
                                'EXPLORE',
                                style: TextStyle(
                                  color: _cInk,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(24),
          _buildSectionHeader('TOP CLAN LEADERBOARD', Icons.leaderboard_rounded),
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
              child: CircularProgressIndicator(color: _cGold),
            ),
            error: (_, __) => const Text(
              'Error loading families',
              style: TextStyle(color: _cRed),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Clan Dashboard ───────────────────────────────────────────
  Widget _buildFamilyDashboard(FamilyModel family, UserModel user) {
    final membersAsync = ref.watch(familyMembersProvider(family.id));
    final myMemberAsync = ref.watch(
        familyMemberProvider((familyId: family.id, userId: user.uid)));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Royal Hero Header
          _buildRoyalHeader(family, user),

          // 2. Main Content Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3. Quick Stats Matrix (Warriors, Tier, Combat PWR)
                _buildQuickStats(family),
                const Gap(16),

                // 4. Elite Clan Arena Card
                _buildClanArenaCard(family),
                const Gap(16),

                // 5. Rank Progression Card
                _buildRankSection(family),
                const Gap(16),

                // 6. Monthly Tribute Target
                _buildMonthlyTarget(family),
                const Gap(16),

                // 7. Clan Vanguard & Members
                _buildMembersSection(family, membersAsync),
                const Gap(16),

                // 8. My Personal Standing
                _buildMyLevelSection(myMemberAsync, family),
                const Gap(16),

                // 9. Incoming Challenges (If any)
                _buildBattleRequestsSection(family, user),

                // 10. Supreme Commander Console
                _buildManagementSection(family, user),
                const Gap(16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Royal Golden Hero Header ───────────────────────────────
  Widget _buildRoyalHeader(FamilyModel family, UserModel user) {
    final isOwner = family.ownerId == user.uid;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Background Banner Image with Golden Warriors & Light Ribbons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Image.asset(
              'assets/images/clan_hero_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_cGoldSoft, _cPageBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Content Column
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                // Golden Laurel & Crown Crest Avatar
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Top Crown Shield Crest
                      Positioned(
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFDF00),
                                _cPremiumGold,
                                Color(0xFFAA771C),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: _cPremiumGold.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded,
                                  color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ),

                      // Avatar with Dual Golden Ring
                      Positioned(
                        bottom: 6,
                        child: Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFE066),
                                _cPremiumGold,
                                Color(0xFF996515),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cPremiumGold.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: ClipOval(
                              child: family.avatarUrl != null &&
                                      family.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: family.avatarUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 240,
                                      memCacheHeight: 240,
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.shield_rounded,
                                        color: _cGold,
                                        size: 40,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shield_rounded,
                                      color: _cGold,
                                      size: 40,
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom Laurel Leaves Decoration
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _cPremiumGold.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.energy_savings_leaf_rounded,
                                  color: _cPremiumGold, size: 12),
                              Gap(2),
                              Text('🌿', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(8),

                // Clan Title + Verified Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        family.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _cInk,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Gap(6),
                    const Icon(Icons.verified_rounded, color: _cGold, size: 20),
                  ],
                ),

                const Gap(4),

                // Sparkle / Diamond Ornament
                const Text(
                  '✦',
                  style: TextStyle(
                      color: _cGold, fontSize: 13, fontWeight: FontWeight.bold),
                ),

                const Gap(8),

                // Chips Row: Location, TAG, and ID
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Location
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _cBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: _cInk),
                          const Gap(4),
                          Text(
                            family.country.isNotEmpty
                                ? family.country
                                : 'Global',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _cInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tag Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _cGoldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _cGoldBorder),
                      ),
                      child: Text(
                        'TAG: [${(family.tag != null && family.tag!.isNotEmpty) ? family.tag! : "CLAN"}]',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _cGoldDeep,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // ID with 1-tap Copy
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: family.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Clan ID copied: ${family.id}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: _cInk,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _cBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: ${family.id.length > 8 ? family.id.substring(0, 8) : family.id}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _cInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Gap(4),
                            const Icon(Icons.copy_rounded,
                                size: 12, color: _cMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(12),

                // Notice Banner (Megaphone + Slogan + Edit Pencil)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cGoldBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: _cGold.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: _cGold, size: 20),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          (family.notice != null && family.notice!.isNotEmpty)
                              ? family.notice!
                              : 'Welcome warriors to our glorious dynasty!',
                          style: const TextStyle(
                            color: _cInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner)
                        GestureDetector(
                          onTap: () => _showEditSettingsDialog(family),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: _cGoldBorder,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: _cGoldDeep, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ─── 2. Triple Metrics Matrix ───────────────────────────────────
  Widget _buildQuickStats(FamilyModel family) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.people_alt_rounded,
              '${family.memberCount} / ${family.memberLimit}',
              'WARRIORS',
              _cBlue,
              _cBlueSoft,
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem(
              Icons.military_tech_rounded,
              family.rankName,
              'TIER',
              _cGold,
              _cGoldSoft,
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem(
              Icons.diamond_rounded,
              _formatCompact(family.totalCombatPoints),
              'COMBAT PWR',
              _cPurple,
              _cPurpleSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color, Color bgColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const Gap(8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: _cInk,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: _cMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 44, color: _cDivider);
  }

  // ─── 3. Elite Clan Arena Card ───────────────────────────────────
  Widget _buildClanArenaCard(FamilyModel family) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cInk,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cPremiumGold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Stadium Graphic Background
            Positioned.fill(
              child: Image.asset(
                'assets/images/clan_arena_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E293B), _cInk],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // Soft Dark Fade Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title + Level Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sports_kabaddi_rounded,
                              color: Color(0xFFFFD700), size: 18),
                          Gap(6),
                          Text(
                            'CLAN ARENA',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'LVL ${family.level} ${family.rankName}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Gap(60), // Space for golden battle shield illustration

                  // Stats Box (Combat Power | Battle Wins)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        // Left: Combat Power
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded,
                                      color: Color(0xFFF97316), size: 16),
                                  const Gap(4),
                                  Text(
                                    _formatCompact(family.totalCombatPoints),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(2),
                              const Text(
                                'Combat Power',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),

                        Container(width: 1, height: 32, color: Colors.white12),

                        // Right: Battle Wins / Points
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      color: Color(0xFFFFD700), size: 16),
                                  const Gap(4),
                                  Text(
                                    _formatCompact(family.totalBattlePoints),
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(2),
                              const Text(
                                'Battle Points',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(12),

                  // Enter Arena CTA Button
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.familyBattle,
                        extra: family.id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_cPremiumGold, _cPremiumDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFFFFDF00), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: _cPremiumGold.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_martial_arts_rounded,
                              color: Colors.white, size: 18),
                          Gap(8),
                          Text(
                            'ENTER ARENA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Gap(6),
                          Icon(Icons.keyboard_double_arrow_right_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. Rank Progression ───────────────────────────────────────
  Widget _buildRankSection(FamilyModel family) {
    final level = family.level;
    final badgeColor = FamilyModel.badgeColorForLevel(level);
    final currentPoints = family.totalCombatPoints;
    final requiredPoints = FamilyModel.pointsForNextLevel(level);

    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cGoldSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cGoldBorder),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _cGold,
                  size: 22,
                ),
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.rankName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _cInk,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Lv$level Clan Rank',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _cMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _cGoldSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _cGoldBorder),
                ),
                child: Text(
                  'Next: Lv${level + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    color: _cGoldDeep,
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),
          FamilyRankProgressBar(
            currentPoints: currentPoints,
            requiredPoints: requiredPoints,
            height: 9,
            fillColor: badgeColor,
          ),
        ],
      ),
    );
  }

  // ─── 5. Monthly Target ─────────────────────────────────────────
  Widget _buildMonthlyTarget(FamilyModel family) {
    final ratio = family.monthlyTarget > 0
        ? (family.currentMonthPoints / family.monthlyTarget).clamp(0.0, 1.0)
        : 0.0;
    final completed = family.monthlyTargetCompleted;
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);

    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MONTHLY TRIBUTE TARGET',
                style: TextStyle(
                  fontSize: 11,
                  color: _cMuted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Gap(6),
              const Icon(Icons.info_outline, color: _cFaint, size: 14),
              const Spacer(),
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 11, color: Color(0xFF16A34A)),
                      Gap(3),
                      Text(
                        'GOAL REACHED',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Gap(10),
          Row(
            children: [
              const Icon(Icons.diamond_rounded, color: _cGold, size: 16),
              const Gap(6),
              Text(
                _formatNumber(family.currentMonthPoints),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _cInk,
                ),
              ),
              Text(
                ' / ${_formatNumber(family.monthlyTarget)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _cMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(10),
          FamilyProgressBar(
            ratio: ratio,
            height: 8,
            fillColor: badgeColor,
            backgroundColor: _cDivider,
          ),
        ],
      ),
    );
  }

  // ─── 6. Clan Vanguard (Members) ────────────────────────────────
  Widget _buildMembersSection(
      FamilyModel family, AsyncValue<List<FamilyMemberModel>> membersAsync) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.familyMembers, extra: family.id),
            child: Row(
              children: [
                const Text(
                  'CLAN VANGUARD',
                  style: TextStyle(
                    fontSize: 11,
                    color: _cMuted,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _cGoldSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _cGoldBorder),
                  ),
                  child: Text(
                    '${family.memberCount} / ${family.memberLimit}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _cGoldDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 11,
                    color: _cGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(2),
                const Icon(Icons.chevron_right_rounded, color: _cGold, size: 16),
              ],
            ),
          ),
          const Gap(14),
          membersAsync.when(
            data: (members) {
              final display = members.take(4).toList();
              return Column(
                children: [
                  SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        _buildInviteAvatar(family),
                        const Gap(6),
                        ...List.generate(display.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildMemberAvatar(display[i], i),
                          );
                        }),
                        if (members.length > 4)
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.familyMembers,
                                extra: family.id),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _cDivider,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _cBorder, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '+${members.length - 4}',
                                  style: const TextStyle(
                                    color: _cInk,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  ...display.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.diamond_rounded,
                                size: 12, color: _cGold),
                            const Gap(4),
                            Expanded(
                              child: Text(
                                '${m.totalDiamondsSent} diamonds | ${_formatCompact(m.totalBattlePoints)} pts',
                                style: const TextStyle(
                                  color: _cMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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
            loading: () => const SizedBox(height: 46),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteAvatar(FamilyModel family) {
    return GestureDetector(
      onTap: () => _showInviteDialog(family),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _cGoldSoft,
          shape: BoxShape.circle,
          border: Border.all(color: _cGold, width: 1.5),
        ),
        child: const Icon(Icons.add, color: _cGold, size: 22),
      ),
    );
  }

  Widget _buildMemberAvatar(FamilyMemberModel member, int rankIndex) {
    final userAsync = ref.watch(cachedUserProfileProvider(member.userId));
    final ringColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFCBD5E1), // Silver
      const Color(0xFFCD7F32), // Bronze
      const Color(0xFF94A3B8), // Normal
    ];
    final ringColor = ringColors[rankIndex.clamp(0, 3)];

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: user.profilePhotoUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: _cDivider),
              errorWidget: (_, __, ___) => Container(
                color: _cDivider,
                child: const Icon(Icons.person, color: _cFaint, size: 20),
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: _cDivider,
          shape: BoxShape.circle,
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── 7. My Individual Rank ─────────────────────────────────────
  Widget _buildMyLevelSection(
      AsyncValue<FamilyMemberModel?> memberAsync, FamilyModel family) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => MemberLevelInfoDialog.show(context),
            child: Row(
              children: [
                const Text(
                  'MY CLAN STANDING',
                  style: TextStyle(
                    fontSize: 11,
                    color: _cMuted,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Rules',
                  style: TextStyle(
                    fontSize: 11,
                    color: _cBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(2),
                const Icon(Icons.info_outline_rounded,
                    color: _cBlue, size: 14),
              ],
            ),
          ),
          const Gap(14),
          memberAsync.when(
            data: (member) {
              if (member == null) {
                return const Text(
                  'Not a member',
                  style: TextStyle(color: _cMuted, fontSize: 13),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildLevelBadge(member.memberLevel),
                      const Gap(10),
                      Text(
                        'Level ${member.memberLevel} Warrior',
                        style: const TextStyle(
                          color: _cInk,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Lv${member.memberLevel + 1}',
                        style: const TextStyle(
                          color: _cRed,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  FamilyRankProgressBar(
                    currentPoints: member.memberXP,
                    requiredPoints: member.xpToNextLevel,
                    height: 8,
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: _cGold, size: 12),
                      const Gap(4),
                      Expanded(
                        child: Text(
                          '${_formatNumber(member.totalDiamondsSent)} diamonds | ${_formatNumber(member.totalBattlePoints)} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _cMuted,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }

  Widget _buildLevelBadge(int level) {
    return GestureDetector(
      onTap: () => MemberLevelInfoDialog.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cRed, Color(0xFFF87171)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _cRed.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          '$level',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ─── 8. Battle Challenges ──────────────────────────────────────
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
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _cRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'BATTLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Gap(8),
                  const Text(
                    'INCOMING CHALLENGES',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _cInk,
                      letterSpacing: 0.5,
                    ),
                  ),
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

  // ─── 9. Supreme Commander Management Console ─────────────────────
  Widget _buildManagementSection(FamilyModel family, UserModel user) {
    final isOwner = family.ownerId == user.uid;
    final isAdmin = isOwner || user.isFamilyOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('COMMAND CENTER', Icons.dashboard_customize_rounded),
        const Gap(12),

        // 1. Warrior Operations Quick Action Hub (4-across)
        if (isAdmin) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: _cardDeco(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionBtn(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Invite',
                  color: _cGreen,
                  bgColor: _cGreenSoft,
                  borderColor: const Color(0xFFA7F3D0),
                  onTap: () => _showInviteDialog(family),
                ),
                _buildQuickActionBtn(
                  icon: Icons.mark_email_unread_rounded,
                  label: 'Requests',
                  color: _cCyan,
                  bgColor: _cCyanSoft,
                  borderColor: const Color(0xFFBAE6FD),
                  onTap: () => context.push(AppRoutes.joinRequests,
                      extra: family.id),
                ),
                _buildQuickActionBtn(
                  icon: Icons.military_tech_rounded,
                  label: 'Officers',
                  color: _cGold,
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: _cGoldBorder,
                  onTap: () => _showPromoteAdminDialog(family),
                ),
                _buildQuickActionBtn(
                  icon: Icons.person_remove_rounded,
                  label: 'Expel',
                  color: const Color(0xFFE11D48),
                  bgColor: _cRedSoft,
                  borderColor: const Color(0xFFFECDD3),
                  onTap: () => _showKickMemberDialog(family),
                ),
              ],
            ),
          ),
          const Gap(14),
        ],

        // 2. Dynasty Governance Administration (List Tiles)
        if (isOwner) ...[
          Container(
            decoration: _cardDeco(),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Column(
              children: [
                _buildAdminTile(
                  icon: Icons.settings_suggest_rounded,
                  title: 'Clan Settings & Rules',
                  subtitle: 'Notice, clan tag, join mode & targets',
                  iconColor: const Color(0xFF4F46E5),
                  iconBg: const Color(0xFFEEF2FF),
                  onTap: () => _showEditSettingsDialog(family),
                ),
                const Divider(
                    height: 1, color: _cDivider, indent: 48),
                _buildAdminTile(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transfer Ownership',
                  subtitle: 'Pass leadership to another member',
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFF7ED),
                  onTap: () => _showTransferOwnershipDialog(family),
                ),
                const Divider(
                    height: 1, color: _cDivider, indent: 48),
                _buildAdminTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Disband Clan',
                  subtitle: 'Permanently dissolve clan dynasty',
                  iconColor: _cRed,
                  iconBg: _cRedSoft,
                  onTap: () => _showDisbandDialog(family),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],

        // 3. Leave Clan (For non-owners)
        if (!isOwner) ...[
          GestureDetector(
            onTap: () => _showLeaveDialog(family, user),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _cRedSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.exit_to_app_rounded, color: _cRed, size: 18),
                  Gap(8),
                  Text(
                    'LEAVE CLAN',
                    style: TextStyle(
                      color: _cRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const Gap(7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _cInk,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? _cRed : _cInk,
          fontWeight: FontWeight.w900,
          fontSize: 13.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: _cMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _cFaint,
        size: 20,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: _cGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Icon(icon, size: 15, color: _cGold),
        const Gap(6),
        Text(
          title,
          style: const TextStyle(
            color: _cInk,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  // ─── Responsive Light Dialogs ──────────────────────────────────
  RoundedRectangleBorder _dialogShape() => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: const BorderSide(color: _cBorder, width: 1),
  );

  TextStyle _dialogTitleStyle({Color color = _cInk}) => TextStyle(
    color: color,
    fontWeight: FontWeight.w900,
    fontSize: 16,
  );

  ButtonStyle _dialogGoldButton() => ElevatedButton.styleFrom(
    backgroundColor: _cGold,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  ButtonStyle _dialogRedButton() => ElevatedButton.styleFrom(
    backgroundColor: _cRed,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _dialogLoading({Color color = Colors.white}) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );

  void _showInviteDialog(FamilyModel family) {
    final uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        var loading = false;
        var errorText = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Invite Member', style: _dialogTitleStyle()),
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the User ID to invite:',
                    style: TextStyle(color: _cMuted, fontSize: 13),
                  ),
                  const Gap(12),
                  TextField(
                    controller: uidController,
                    style: const TextStyle(color: _cInk, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'User ID',
                      hintStyle: const TextStyle(color: _cFaint),
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                    ),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const Gap(8),
                    Text(
                      errorText,
                      style: const TextStyle(
                        color: _cRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: _cMuted)),
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
                        setDialogState(() {
                          loading = true;
                          errorText = '';
                        });
                        try {
                          await ref
                              .read(familyServiceProvider)
                              .addMember(family.id, uid);
                          if (ctx.mounted) {
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Member added!')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            loading = false;
                            errorText = e.toString();
                          });
                        }
                      },
                style: _dialogGoldButton(),
                child: loading
                    ? _dialogLoading()
                    : const Text('Invite',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Leave Clan', style: _dialogTitleStyle()),
            content: Text(
              'Are you sure you want to leave ${family.name}?',
              style: const TextStyle(color: _cMuted, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: _cMuted)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        await ref
                            .read(familyServiceProvider)
                            .leaveFamily(user.uid, family.id);
                        if (ctx.mounted) {
                          context.pop();
                          context.pop();
                        }
                      },
                style: _dialogRedButton(),
                child: loading
                    ? _dialogLoading()
                    : const Text('Leave',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Disband Clan', style: _dialogTitleStyle(color: _cRed)),
            content: const Text(
              'This action is irreversible. All members will be removed and clan data dissolved.',
              style: TextStyle(color: _cMuted, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: _cMuted)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        setDialogState(() => loading = true);
                        await ref
                            .read(familyServiceProvider)
                            .disbandFamily(family);
                        if (ctx.mounted) {
                          context.pop();
                          context.pop();
                        }
                      },
                style: _dialogRedButton(),
                child: loading
                    ? _dialogLoading()
                    : const Text('Disband',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Expel Member', style: _dialogTitleStyle()),
            content: membersAsync.when(
              data: (members) {
                final nonOwner = members.where((m) => !m.isOwner).toList();
                if (nonOwner.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No members to expel.',
                        style: TextStyle(color: _cMuted)),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                    minWidth: double.maxFinite,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: nonOwner.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _cDivider),
                    itemBuilder: (_, i) {
                      final member = nonOwner[i];
                      final userId = member.userId;
                      final isUserLoading = loading == userId;
                      return Consumer(builder: (context, ref, _) {
                        final userAsync =
                            ref.watch(cachedUserProfileProvider(userId));
                        return userAsync.when(
                          data: (user) {
                            final name =
                                (user != null && user.displayName.trim().isNotEmpty)
                                    ? user.displayName
                                    : ((user != null &&
                                            user.username.trim().isNotEmpty)
                                        ? user.username
                                        : userId);
                            final avatarUrl = user?.profilePhotoUrl ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _cBorder),
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                            Icons.person,
                                            color: _cMuted,
                                            size: 22,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: _cMuted,
                                          size: 22,
                                        ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: _cInk,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                member.role.toUpperCase(),
                                style: const TextStyle(
                                  color: _cFaint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: isUserLoading
                                  ? _dialogLoading(color: _cRed)
                                  : IconButton(
                                      icon: const Icon(
                                          Icons.person_remove_rounded,
                                          color: _cRed),
                                      onPressed: () async {
                                        setDialogState(
                                            () => loading = userId);
                                        await ref
                                            .read(familyServiceProvider)
                                            .kickMember(family.id, userId);
                                        if (ctx.mounted)
                                          setDialogState(() => loading = '');
                                      },
                                    ),
                            );
                          },
                          loading: () => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            leading: const CircleAvatar(
                              backgroundColor: _cDivider,
                              child: Icon(Icons.person, color: _cBorder),
                            ),
                            title: Text(
                              userId,
                              style:
                                  const TextStyle(color: _cMuted, fontSize: 13),
                            ),
                          ),
                          error: (_, __) => ListTile(
                            title:
                                Text(userId, style: const TextStyle(fontSize: 13)),
                          ),
                        );
                      });
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _cGold),
                ),
              ),
              error: (e, _) => Text('$e',
                  style: const TextStyle(color: _cRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: _cMuted)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Manage Officers', style: _dialogTitleStyle()),
            content: membersAsync.when(
              data: (members) {
                final eligible = members.where((m) => !m.isOwner).toList();
                if (eligible.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No other members.',
                        style: TextStyle(color: _cMuted)),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                    minWidth: double.maxFinite,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: eligible.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _cDivider),
                    itemBuilder: (_, i) {
                      final m = eligible[i];
                      final isAdmin = m.isAdmin;
                      final isUserLoading = loading == m.userId;

                      return Consumer(builder: (context, ref, _) {
                        final userAsync =
                            ref.watch(cachedUserProfileProvider(m.userId));
                        return userAsync.when(
                          data: (user) {
                            final name =
                                (user != null && user.displayName.trim().isNotEmpty)
                                    ? user.displayName
                                    : ((user != null &&
                                            user.username.trim().isNotEmpty)
                                        ? user.username
                                        : m.userId);
                            final avatarUrl = user?.profilePhotoUrl ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isAdmin ? _cGold : _cBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Icon(
                                            isAdmin
                                                ? Icons.admin_panel_settings_rounded
                                                : Icons.person,
                                            color: isAdmin
                                                ? _cGold
                                                : _cMuted,
                                          ),
                                        )
                                      : Icon(
                                          isAdmin
                                              ? Icons.admin_panel_settings_rounded
                                              : Icons.person,
                                          color: isAdmin ? _cGold : _cMuted,
                                        ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: _cInk,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? _cGoldSoft
                                          : _cDivider,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isAdmin ? 'OFFICER' : 'WARRIOR',
                                      style: TextStyle(
                                        color: isAdmin
                                            ? _cGoldDeep
                                            : _cMuted,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isUserLoading
                                  ? _dialogLoading(color: _cGold)
                                  : TextButton(
                                      onPressed: () async {
                                        setDialogState(
                                            () => loading = m.userId);
                                        if (isAdmin) {
                                          await ref
                                              .read(familyServiceProvider)
                                              .demoteAdmin(
                                                  family.id, m.userId);
                                        } else {
                                          await ref
                                              .read(familyServiceProvider)
                                              .promoteAdmin(
                                                  family.id, m.userId);
                                        }
                                        if (ctx.mounted)
                                          setDialogState(() => loading = '');
                                      },
                                      child: Text(
                                        isAdmin ? 'Demote' : 'Promote',
                                        style: TextStyle(
                                          color: isAdmin
                                              ? _cRed
                                              : const Color(0xFF059669),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                            );
                          },
                          loading: () => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            leading: const CircleAvatar(
                              backgroundColor: _cDivider,
                              child: Icon(Icons.person, color: _cBorder),
                            ),
                            title: Text(
                              m.userId,
                              style:
                                  const TextStyle(color: _cMuted, fontSize: 13),
                            ),
                          ),
                          error: (_, __) => ListTile(
                            title:
                                Text(m.userId, style: const TextStyle(fontSize: 13)),
                          ),
                        );
                      });
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _cGold),
                ),
              ),
              error: (e, _) => Text('$e',
                  style: const TextStyle(color: _cRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: _cMuted)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Transfer Ownership', style: _dialogTitleStyle()),
            content: membersAsync.when(
              data: (members) {
                final eligible =
                    members.where((m) => m.userId != family.ownerId).toList();
                if (eligible.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No other members.',
                        style: TextStyle(color: _cMuted)),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                    minWidth: double.maxFinite,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: eligible.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _cDivider),
                    itemBuilder: (_, i) {
                      final userId = eligible[i].userId;
                      final isUserLoading = loading == userId;

                      return Consumer(builder: (context, ref, _) {
                        final userAsync =
                            ref.watch(cachedUserProfileProvider(userId));
                        return userAsync.when(
                          data: (user) {
                            final name =
                                (user != null && user.displayName.trim().isNotEmpty)
                                    ? user.displayName
                                    : ((user != null &&
                                            user.username.trim().isNotEmpty)
                                        ? user.username
                                        : userId);
                            final avatarUrl = user?.profilePhotoUrl ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _cGold, width: 1.5),
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                            Icons.person,
                                            color: _cGold,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: _cGold,
                                        ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  color: _cInk,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: const Text(
                                'Tap to transfer clan ownership',
                                style:
                                    TextStyle(color: _cFaint, fontSize: 11),
                              ),
                              trailing: isUserLoading
                                  ? _dialogLoading(color: _cGold)
                                  : IconButton(
                                      icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: _cGold),
                                      onPressed: () async {
                                        final confirm =
                                            await showDialog<bool>(
                                          context: ctx,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            shape: _dialogShape(),
                                            title: const Text(
                                              'Confirm Transfer?',
                                              style: TextStyle(
                                                color: _cInk,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: Text(
                                              'Transfer clan ownership to $name? You will become a regular member.',
                                              style: const TextStyle(
                                                  color: _cMuted),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                      color: _cMuted),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                style: _dialogGoldButton(),
                                                child: const Text('Transfer'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true) return;
                                        setDialogState(
                                            () => loading = userId);
                                        await ref
                                            .read(familyServiceProvider)
                                            .transferOwnership(
                                                family.id, userId);
                                        if (ctx.mounted)
                                          setDialogState(() => loading = '');
                                      },
                                    ),
                            );
                          },
                          loading: () => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            leading: const CircleAvatar(
                              backgroundColor: _cGoldSoft,
                              child: Icon(Icons.person, color: _cGold),
                            ),
                            title: Text(
                              userId,
                              style:
                                  const TextStyle(color: _cMuted, fontSize: 13),
                            ),
                          ),
                          error: (_, __) => ListTile(
                            title:
                                Text(userId, style: const TextStyle(fontSize: 13)),
                          ),
                        );
                      });
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _cGold),
                ),
              ),
              error: (e, _) => Text('$e',
                  style: const TextStyle(color: _cRed)),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close', style: TextStyle(color: _cMuted)),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditSettingsDialog(FamilyModel family) {
    final noticeCtrl = TextEditingController(text: family.notice ?? '');
    final tagCtrl = TextEditingController(text: family.tag ?? '');
    var selectedMode = family.joinMode;
    var monthlyTarget = family.monthlyTarget;

    showDialog(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Clan Settings', style: _dialogTitleStyle()),
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clan Notice',
                    style: TextStyle(
                        color: _cMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                  const Gap(4),
                  TextField(
                    controller: noticeCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: _cInk, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                    ),
                  ),
                  const Gap(12),
                  const Text(
                    'Clan Tag',
                    style: TextStyle(
                        color: _cMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                  const Gap(4),
                  TextField(
                    controller: tagCtrl,
                    maxLength: 4,
                    style: const TextStyle(color: _cInk, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      counterText: '',
                    ),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      const Text(
                        'Join Mode: ',
                        style: TextStyle(
                            color: _cInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const Gap(8),
                      DropdownButton<JoinMode>(
                        value: selectedMode,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                            color: _cInk, fontWeight: FontWeight.bold),
                        items: JoinMode.values
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m.name)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedMode = v!),
                      ),
                    ],
                  ),
                  const Gap(12),
                  const Text(
                    'Monthly Target (Diamonds)',
                    style: TextStyle(
                        color: _cMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                  const Gap(4),
                  TextField(
                    controller:
                        TextEditingController(text: monthlyTarget.toString()),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _cInk, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                    ),
                    onChanged: (v) =>
                        monthlyTarget = int.tryParse(v) ?? monthlyTarget,
                  ),
                  const Gap(16),
                  const Text(
                    'CLAN POLICIES',
                    style: TextStyle(
                      color: _cGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Gap(8),
                  Consumer(builder: (context, ref, _) {
                    final policiesAsync =
                        ref.watch(familyPoliciesProvider(family.id));
                    return policiesAsync.when(
                      data: (policies) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...policies.asMap().entries.map((entry) {
                            final i = entry.key;
                            final p = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _cPageBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _cBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          style: const TextStyle(
                                            color: _cInk,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          p.description,
                                          style: const TextStyle(
                                              color: _cMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      await ref
                                          .read(familyServiceProvider)
                                          .removeFamilyPolicy(family.id, i);
                                      ref.invalidate(
                                          familyPoliciesProvider(family.id));
                                    },
                                    child: const Icon(Icons.close,
                                        color: _cRed, size: 18),
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
                                color: _cGoldSoft,
                                border: Border.all(color: _cGoldBorder),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      color: _cGoldDeep, size: 16),
                                  Gap(4),
                                  Text(
                                    'Add Policy',
                                    style: TextStyle(
                                      color: _cGoldDeep,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                        height: 30,
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _cGold),
                        ),
                      ),
                      error: (_, __) => const SizedBox(height: 30),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: _cMuted)),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        await ref
                            .read(familyServiceProvider)
                            .updateFamilySettings(
                              family.id,
                              notice: noticeCtrl.text,
                              tag: tagCtrl.text.toUpperCase(),
                              joinMode: selectedMode,
                              monthlyTarget: monthlyTarget,
                            );
                        if (ctx.mounted) context.pop();
                      },
                style: _dialogGoldButton(),
                child: saving
                    ? _dialogLoading()
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: Colors.white,
            shape: _dialogShape(),
            title: Text('Add Policy', style: _dialogTitleStyle()),
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title',
                      style: TextStyle(color: _cMuted, fontSize: 11.5)),
                  const Gap(4),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: _cInk, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                    ),
                  ),
                  const Gap(12),
                  const Text('Description',
                      style: TextStyle(color: _cMuted, fontSize: 11.5)),
                  const Gap(4),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: _cInk, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _cPageBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: adding ? null : () => context.pop(),
                child: const Text('Cancel', style: TextStyle(color: _cMuted)),
              ),
              ElevatedButton(
                onPressed: adding
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        setDialogState(() => adding = true);
                        await ref
                            .read(familyServiceProvider)
                            .addFamilyPolicy(
                              family.id,
                              titleCtrl.text.trim(),
                              descCtrl.text.trim(),
                            );
                        ref.invalidate(familyPoliciesProvider(family.id));
                        if (ctx.mounted) context.pop();
                      },
                style: _dialogGoldButton(),
                child: adding
                    ? _dialogLoading()
                    : const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

// ─── Family Discovery Card (Leaderboard) ───────────────────────
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
        decoration: _cardDeco().copyWith(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _cGold.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: family.avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: family.avatarUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: _cGoldSoft,
                        child: const Icon(Icons.shield,
                            color: _cGold, size: 24),
                      ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _cInk,
                    ),
                  ),
                  const Gap(3),
                  Row(
                    children: [
                      const Icon(Icons.people_rounded,
                          size: 12, color: _cMuted),
                      const Gap(4),
                      Text(
                        '${family.memberCount} members',
                        style: const TextStyle(
                          color: _cMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(10),
                      const Icon(Icons.emoji_events_rounded,
                          size: 12, color: _cGold),
                      const Gap(3),
                      Text(
                        family.rankName,
                        style: const TextStyle(
                          color: _cGold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                )),
              );
              return appStatusAsync.when(
                data: (status) {
                  final isJoined = family.memberUids.contains(user.uid);
                  final isRequested = status == JoinRequestStatus.pending;
                  String label = 'JOIN';
                  Color color = _cGold;
                  Color textColor = Colors.white;
                  bool enabled = true;
                  if (isJoined) {
                    label = 'JOINED';
                    color = const Color(0xFFDCFCE7);
                    textColor = const Color(0xFF16A34A);
                    enabled = false;
                  } else if (isRequested) {
                    label = 'PENDING';
                    color = _cGoldSoft;
                    textColor = _cGoldDeep;
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
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: enabled
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
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
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              label,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
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
    );
  }
}

// ─── Battle Request Card ─────────────────────────────────────────
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _cRed.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _cRed.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: req.challengerAvatar != null
                  ? CachedNetworkImage(
                      imageUrl: req.challengerAvatar!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFFFEE2E2),
                      child: const Icon(Icons.shield,
                          size: 18, color: _cRed),
                    ),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  req.challengerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: _cInk,
                  ),
                ),
                const Text(
                  'challenges you to battle!',
                  style: TextStyle(fontSize: 11, color: _cMuted),
                ),
              ],
            ),
          ),
          if (_isRejecting || _isAccepting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _cRed),
            )
          else ...[
            GestureDetector(
              onTap: _isAccepting ? null : () => _handleReject(req),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close,
                    size: 16, color: _cRed),
              ),
            ),
            const Gap(6),
            GestureDetector(
              onTap: _isRejecting ? null : () => _handleAccept(req),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cRed, Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _cRed.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'FIGHT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleAccept(FamilyBattleRequestModel req) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await ref.read(familyServiceProvider).acceptBattleRequest(
            req.id,
            req.challengerFamilyId,
            widget.familyId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Battle accepted! Starting now...'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
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