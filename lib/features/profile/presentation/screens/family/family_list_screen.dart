import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:go_router/go_router.dart';

class FamilyListScreen extends ConsumerStatefulWidget {
  const FamilyListScreen({super.key});

  @override
  ConsumerState<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends ConsumerState<FamilyListScreen> {
  bool _isJoining = false;

  String _selectedPeriod = 'Weekly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Dark Royal Backdrop
      appBar: AppBar(
        title: const Text('CLAN RANKINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildRankingView(),
    );
  }

  Widget _buildRankingView() {
    final familiesAsync = ref.watch(allFamiliesProvider);

    return familiesAsync.when(
      data: (families) {
        final sorted = List<FamilyModel>.from(families);
        
        // If Firestore has no families yet, provide demo champion clans so UI is never empty
        if (sorted.isEmpty) {
          sorted.addAll([
            FamilyModel(id: 'demo1', name: 'DRAGON DYNASTY', tag: 'DRG', description: 'Royal Dragon Clan', level: 98, totalCombatPoints: 12500000, memberUids: List.generate(46, (i) => 'm$i'), ownerId: 'o1', createdAt: DateTime.now()),
            FamilyModel(id: 'demo2', name: 'ROYAL PHOENIX', tag: 'PHX', description: 'Phoenix Elite', level: 85, totalCombatPoints: 8200000, memberUids: List.generate(42, (i) => 'm$i'), ownerId: 'o2', createdAt: DateTime.now()),
            FamilyModel(id: 'demo3', name: 'VALHALLA LIONS', tag: 'VLH', description: 'Valhalla Kings', level: 74, totalCombatPoints: 5900000, memberUids: List.generate(38, (i) => 'm$i'), ownerId: 'o3', createdAt: DateTime.now()),
            FamilyModel(id: 'demo4', name: 'VANGUARD TITANS', tag: 'VNG', description: 'Vanguard Army', level: 68, totalCombatPoints: 4700000, memberUids: List.generate(35, (i) => 'm$i'), ownerId: 'o4', createdAt: DateTime.now()),
            FamilyModel(id: 'demo5', name: 'IMPERIAL KINGS', tag: 'IMP', description: 'Imperial Dynasty', level: 62, totalCombatPoints: 3400000, memberUids: List.generate(30, (i) => 'm$i'), ownerId: 'o5', createdAt: DateTime.now()),
          ]);
        }

        sorted.sort((a, b) => b.totalCombatPoints.compareTo(a.totalCombatPoints));

        final topThree = sorted.take(3).toList();
        final rosterList = sorted.length > 3 ? sorted.skip(3).toList() : sorted;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Top 3 Champions Podium
            _buildPodium(topThree),
            const Gap(24),

            // 2. Time Filter Bar
            _buildPeriodFilterBar(),
            const Gap(24),
            
            // 3. Roster Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 16, decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(2))),
                    const Gap(8),
                    const Text('GLOBAL CLAN ROSTER', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1.5)),
                  ],
                ),
                Text('${sorted.length} CLANS', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFFFD700))),
              ],
            ),
            const Gap(16),
            
            // 4. Roster Tiles List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rosterList.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) {
                final family = rosterList[i];
                final rank = sorted.indexOf(family) + 1;
                return _buildCompactFamilyTile(family, rank, family.totalCombatPoints);
              },
            ),
            const Gap(40),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (_, __) => const Center(child: Text("Error fetching ranking", style: TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildPeriodFilterBar() {
    final periods = ['Daily', 'Weekly', 'All-Time'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFD4A843) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodium(List<FamilyModel> top) {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top.length > 1)
            Expanded(child: _buildPodiumItem(top[1], 2, const Color(0xFF94A3B8), 110)),
          if (top.isNotEmpty)
            Expanded(child: _buildPodiumItem(top[0], 1, const Color(0xFFFFD700), 145)),
          if (top.length > 2)
            Expanded(child: _buildPodiumItem(top[2], 3, const Color(0xFFD97706), 95)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(FamilyModel family, int rank, Color color, double podiumHeight) {
    final bool isGold = rank == 1;
    final double avatarRadius = isGold ? 38 : 30;
    final pts = family.totalCombatPoints;
    final ptsFormatted = pts >= 1000000 
        ? '${(pts / 1000000).toStringAsFixed(1)}M CP' 
        : '${(pts / 1000).toStringAsFixed(1)}K CP';

    return GestureDetector(
      onTap: () => _showClanDetails(family),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Avatar Ring
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer Glow
                Container(
                  width: avatarRadius * 2 + 8,
                  height: avatarRadius * 2 + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, spreadRadius: 1),
                    ],
                  ),
                ),
                // Inner Ring
                Container(
                  width: avatarRadius * 2,
                  height: avatarRadius * 2,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F172A)),
                    child: ClipOval(
                      child: family.avatarUrl != null && family.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.shield_rounded, color: color, size: avatarRadius * 0.9))
                          : Icon(Icons.shield_rounded, color: color, size: avatarRadius * 0.9),
                    ),
                  ),
                ),
                // Level Pill
                Positioned(
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color, width: 1.2),
                    ),
                    child: Text(
                      'Lv.${family.level}',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),

            // Clan Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                family.name.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isGold ? 12 : 10,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(2),

            // CP Text
            Text(
              ptsFormatted,
              style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),

            // 3D Hexagonal Podium Base (Simulated with layered containers)
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // 3D Base Face
                Container(
                  width: double.infinity,
                  height: podiumHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF232732), Color(0xFF0B0F17)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10, offset: const Offset(0, -2)),
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: isGold ? 28 : 22,
                      shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
                // Top Polygon Lid Line
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333846),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    border: Border(bottom: BorderSide(color: color.withOpacity(0.4), width: 2)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFamilyTile(FamilyModel family, int rank, int pts) {
    final clanName = family.name.trim().isNotEmpty ? family.name.trim() : "Clan #$rank";
    final memberCount = family.memberUids.isNotEmpty ? family.memberUids.length : 1;
    final ptsText = pts >= 1000000 
        ? '${(pts / 1000000).toStringAsFixed(1)}M' 
        : '${(pts / 1000).toStringAsFixed(1)}K';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showClanDetails(family),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // 1. Rank Index Badge
                SizedBox(
                  width: 28,
                  child: Text(
                    '#${rank.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD700), fontSize: 13, letterSpacing: -0.5),
                  ),
                ),
                const Gap(4),

                // 2. Clan Avatar with Golden Ring
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.25), blurRadius: 6),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F172A)),
                        child: ClipOval(
                          child: family.avatarUrl != null && family.avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 18))
                              : const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFD700), width: 1),
                        ),
                        child: Text(
                          '${family.level}',
                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),

                // 3. Middle Meta Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        clanName.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white, letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: Color(0xFF94A3B8), size: 10),
                          const Gap(3),
                          Text(
                            '$memberCount/100',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(6),

                // 4. Neon CP Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_outlined, color: Color(0xFF38BDF8), size: 10),
                      const Gap(2),
                      Text(
                        '$ptsText CP',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const Gap(6),

                // 5. Glowing Action Button
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF10B981)]),
                  ),
                  alignment: Alignment.center,
                  child: const Text('VIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClanDetails(FamilyModel family) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const Gap(12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
            const Gap(24),
            // Header with Avatar
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 4),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20)],
              ),
              child: ClipOval(
                child: family.avatarUrl != null 
                  ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.groups_rounded, size: 60, color: Colors.grey),
              ),
            ),
            const Gap(16),
            Text(family.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
            if (family.tag != null) 
              Text('[${family.tag}]', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            const Gap(24),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModalStat('Members', '${family.memberUids.length}', Icons.people_rounded),
                _buildModalStat('Points', '${family.totalCombatPoints}', Icons.bolt_rounded),
                _buildModalStat('Level', '${family.level}', Icons.trending_up_rounded),
              ],
            ),
            const Gap(32),
            
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ABOUT CLAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black26, letterSpacing: 1)),
                  const Gap(8),
                  Text(
                    family.description.isEmpty ? 'No description available for this clan.' : family.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),

            Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(userProfileProvider(ref.watch(authStateProvider).value?.uid ?? '')).value;
                final canChallenge = user?.familyId != null && user?.familyId != family.id;
                return Column(
                  children: [
                    if (canChallenge)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(AppRoutes.familyBattle, extra: user!.familyId);
                            },
                            icon: const Icon(Icons.sports_kabaddi_rounded, size: 18, color: Colors.white),
                            label: const Text('CHALLENGE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    if (canChallenge) const Gap(8),
                    Padding(
                      padding: EdgeInsets.fromLTRB(32, 0, 32, canChallenge ? 0 : 32),
                      child: _buildJoinButton(family, user),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(FamilyModel family, UserModel? user) {
    final isAlreadyInFamily = user?.familyId != null;
    final isMyFamily = user?.familyId == family.id;

    if (isMyFamily) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: const BorderSide(color: AppColors.primary, width: 2),
          ),
          child: const Text('YOUR CLAN', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
        ),
      );
    }

    final appStatusAsync = ref.watch(userApplicationStatusProvider((userId: user?.uid ?? '', familyId: family.id)));

    return appStatusAsync.when(
      data: (status) {
        final isRequested = status == JoinRequestStatus.pending;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (isAlreadyInFamily || _isJoining || isRequested) ? null : () => _handleJoinClan(family),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequested ? Colors.orange : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isJoining
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    isRequested ? 'REQUESTED' : (isAlreadyInFamily ? 'ALREADY IN A CLAN' : 'SEND JOIN REQUEST'),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                  ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text("Error checking status"),
    );
  }

  Widget _buildModalStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.black26, size: 20),
        const Gap(4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900)),
      ],
    );
  }

  void _handleJoinClan(FamilyModel family) async {
    final user = ref.read(userProfileProvider(ref.read(authStateProvider).value?.uid ?? '')).value;
    if (user == null) return;

    setState(() => _isJoining = true);
    
    try {
      await ref.read(familyServiceProvider).applyToJoin(
        userId: user.uid,
        familyId: family.id,
        userName: user.displayName,
        userAvatar: user.profilePhotoUrl,
      );
      if (mounted) {
        setState(() => _isJoining = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Join request sent to ${family.name}!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    }
  }
}


