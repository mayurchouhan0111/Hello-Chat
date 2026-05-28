import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:go_router/go_router.dart';

class FamilyListScreen extends ConsumerStatefulWidget {
  const FamilyListScreen({super.key});

  @override
  ConsumerState<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends ConsumerState<FamilyListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CLAN RANKINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Gap(8),
          _buildTabBar(),
          const Gap(8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRankingView('Prestige'),
                _buildRankingView('Combat'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        indicator: RoundUnderlineTabIndicator(
          borderSide: BorderSide(width: 4, color: AppColors.primary),
          width: 30,
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black38,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'PRESTIGE'),
          Tab(text: 'COMBAT'),
        ],
      ),
    );
  }

  Widget _buildRankingView(String type) {
    final familiesAsync = ref.watch(allFamiliesProvider);

    return familiesAsync.when(
      data: (families) {
        final sorted = List<FamilyModel>.from(families);
        if (type == 'Prestige') {
          sorted.sort((a, b) => b.totalBattlePoints.compareTo(a.totalBattlePoints));
        } else {
          sorted.sort((a, b) => b.totalCombatPoints.compareTo(a.totalCombatPoints));
        }

        if (sorted.isEmpty) return const Center(child: Text("No Families yet"));

        final topThree = sorted.take(3).toList();
        final others = sorted.skip(3).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPodium(topThree, type),
            const Gap(32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GLOBAL ROSTER', 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 1)),
                Text('${sorted.length} CLANS', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.black38)),
              ],
            ),
            const Gap(16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: others.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) {
                final family = others[i];
                final pts = type == 'Prestige' ? family.totalBattlePoints : family.totalCombatPoints;
                return _buildCompactFamilyTile(family, i + 4, pts);
              },
            ),
            const Gap(40),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text("Error fetching ranking")),
    );
  }

  Widget _buildPodium(List<FamilyModel> top, String type) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (top.length > 1) Padding(padding: const EdgeInsets.only(bottom: 0), child: _buildPodiumItem(top[1], 2, const Color(0xFF94A3B8), type)),
        if (top.isNotEmpty) _buildPodiumItem(top[0], 1, const Color(0xFFFACC15), type),
        if (top.length > 2) Padding(padding: const EdgeInsets.only(bottom: 0), child: _buildPodiumItem(top[2], 3, const Color(0xFFD97706), type)),
      ],
    );
  }

  Widget _buildPodiumItem(FamilyModel family, int rank, Color color, String type) {
    double size = rank == 1 ? 100 : 80;
    final pts = type == 'Prestige' ? family.totalBattlePoints : family.totalCombatPoints;
    final userData = ref.watch(userProfileProvider(ref.watch(authStateProvider).value?.uid ?? '')).value;

    return GestureDetector(
      onTap: () => context.push(userData?.familyId != null ? AppRoutes.familyList : AppRoutes.familyPortal),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size, height: size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
                ),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: ClipOval(
                    child: family.avatarUrl != null 
                      ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover)
                      : Icon(Icons.groups_rounded, color: color, size: size * 0.5),
                    ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
                  child: Text('#$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const Gap(12),
          SizedBox(
            width: rank == 1 ? 110 : 90,
            child: Text(
              family.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('${(pts / 1000).toStringAsFixed(1)}k', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFamilyTile(FamilyModel family, int rank, int pts) {
    return InkWell(
      onTap: () => _showClanDetails(family),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32, 
              child: Text(
                rank.toString().padLeft(2, '0'), 
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black26, fontSize: 16)
              )
            ),
            const Gap(4),
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: Colors.black.withOpacity(0.05), width: 2)
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14), 
                child: family.avatarUrl != null 
                  ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover) 
                  : const Icon(Icons.groups_rounded, color: Colors.black12, size: 24)
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(family.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5)),
                  const Gap(2),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 12, color: Colors.black26),
                      const Gap(4),
                      Text('${family.memberUids.length} Battle Members', style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pts > 1000000 ? '${(pts/1000000).toStringAsFixed(1)}M' : pts > 1000 ? '${(pts/1000).toStringAsFixed(1)}K' : '$pts', 
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)
                ),
                const Text('PTS', style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ],
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
                _buildModalStat('Points', '${family.totalBattlePoints}', Icons.bolt_rounded),
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
            
            // Action Button
            Padding(
              padding: const EdgeInsets.all(32),
              child: Consumer(
                builder: (context, ref, _) {
                  final user = ref.watch(userProfileProvider(ref.watch(authStateProvider).value?.uid ?? '')).value;
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
                },
              ),
            ),
          ],
        ),
      ),
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

// CUSTOM ROUNDED INDICATOR
class RoundUnderlineTabIndicator extends Decoration {
  final BorderSide borderSide;
  final double width;

  const RoundUnderlineTabIndicator({
    this.borderSide = const BorderSide(width: 4.0, color: Colors.black87),
    this.width = 24.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundUnderlinePainter(this, onChanged);
  }
}

class _RoundUnderlinePainter extends BoxPainter {
  final RoundUnderlineTabIndicator decoration;

  _RoundUnderlinePainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint paint = decoration.borderSide.toPaint()..strokeCap = StrokeCap.round;
    
    // Position it at the bottom middle of the label
    final double xPos = rect.left + (rect.width / 2);
    final double yPos = rect.bottom - (decoration.borderSide.width / 2);
    canvas.drawLine(
      Offset(xPos - (decoration.width / 2), yPos),
      Offset(xPos + (decoration.width / 2), yPos),
      paint,
    );
  }
}
