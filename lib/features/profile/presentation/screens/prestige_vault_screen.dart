import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/vip_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/vip_tier_model.dart';
import '../../../../core/constants/app_colors.dart';

class PrestigeVaultScreen extends ConsumerStatefulWidget {
  const PrestigeVaultScreen({super.key});

  @override
  ConsumerState<PrestigeVaultScreen> createState() => _PrestigeVaultScreenState();
}

class _PrestigeVaultScreenState extends ConsumerState<PrestigeVaultScreen> {
  int _selectedTabIndex = 0; // 0: VIP, 1: NOBLE, 2: SVIP
  String? _expandedTierId; // To track which card is expanded

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          _buildLuxuryBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildPremiumAppBar(context),
                _buildVaultToggle(),
                const Gap(16),

                Expanded(
                  child: profileAsync.when(
                    data: (user) {
                      if (user == null) return const Center(child: Text("Sync Required", style: TextStyle(color: Colors.white24)));
                      
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _selectedTabIndex == 0 
                          ? _buildVIPTab(user) 
                          : _selectedTabIndex == 1 
                            ? _buildNobleTab(user) 
                            : _buildSVIPTab(user),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                    error: (e, __) => Center(child: Text("Offline Mode", style: TextStyle(color: Colors.white24))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF1E1E1E), Color(0xFF070707)],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          ),
          const Spacer(),
          const Column(
            children: [
              Text("PRESTIGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 4)),
              Text("ELITE VAULT v2.0", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildVaultToggle() {
    final titles = ["TITAN VIP", "ARISTOCRACY", "SVIP"];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amberAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(4),
                child: Center(
                  child: Text(
                    titles[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white54,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildVIPTab(UserModel user) {
    final tiersAsync = ref.watch(vipTiersProvider);
    return tiersAsync.when(
      data: (tiers) {
        final ownedTiers = tiers.where((t) => user.vipTier == t.name).toList();
        if (ownedTiers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white10, size: 64),
                Gap(16),
                Text("NO OWNED VIP ASSETS", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ownedTiers.length,
          itemBuilder: (context, index) => _buildExpandableTierCard(ownedTiers[index], true),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
      error: (e, __) => const SizedBox(),
    );
  }

  Widget _buildNobleTab(UserModel user) {
    final noblesAsync = ref.watch(nobleTiersProvider);
    return noblesAsync.when(
      data: (nobles) {
        final ownedNobles = nobles.where((n) => user.nobleTier == n.name).toList();
        if (ownedNobles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, color: Colors.white10, size: 64),
                Gap(16),
                Text("NO OWNED NOBLE ASSETS", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ownedNobles.length,
          itemBuilder: (context, index) => _buildExpandableTierCard(ownedNobles[index], true),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
      error: (e, __) => const SizedBox(),
    );
  }

  Widget _buildSVIPTab(UserModel user) {
    if (user.svipLevel == null || user.svipLevel! < 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_outlined, color: Colors.white10, size: 64),
            Gap(16),
            Text("NO OWNED SVIP ASSETS", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
         Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF1A1A1A)]),
          ),
          child: Column(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 40),
              const Gap(12),
              const Text("SVIP LOYALTY STATUS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Gap(4),
              Text("LEVEL ${user.svipLevel}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const Gap(24),
        _buildBenefitGrid([
          "Universal Kick Protection", "Server Broadcast On Login", "Custom UI Themes", "Priority Support", "Noble Auction Access", "Exclusive Badges"
        ]),
      ],
    ).animate().fadeIn();
  }

  // --- COMPONENTS ---

  Widget _buildExpandableTierCard(VIPTierModel tier, bool isOwned) {
    final bool isExpanded = _expandedTierId == tier.tierId;
    final Color themeColor = _parseColor(tier.themeColor);

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _expandedTierId = isExpanded ? null : tier.tierId;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 8),
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isOwned ? Colors.amberAccent : Colors.white.withOpacity(0.05), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Full Background Image
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: tier.backgroundImage.isNotEmpty ? tier.backgroundImage : "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?w=600&q=80",
                    fit: BoxFit.cover,
                  ),
                ),
                // Gradient Overlay for Readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      _buildTierBadge(tier.badgeIcon, themeColor, isOwned),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tier.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const Gap(2),
                            Text(tier.entryRequirement, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
                        color: Colors.white38, size: 20
                      ),
                    ],
                  ),
                ),
                if (isOwned)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10)),
                      ),
                      child: const Text("OWNED", style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Expanded Details
        if (isExpanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("EXCLUSIVE PRIVILEGES", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Gap(12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: tier.benefits.map((b) => _buildMiniBenefit(b)).toList(),
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text("UNLOCK NOW", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
      ],
    );
  }

  Widget _buildTierBadge(String img, Color color, bool isOwned) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isOwned ? Colors.amberAccent : color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)],
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: img,
          width: 48.0,
          placeholder: (c, s) => const Icon(Icons.shield, color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildMiniBenefit(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: Colors.amberAccent, size: 10),
          const Gap(4),
          Text(text.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBenefitGrid(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("SVIP PRIVILEGES", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
        const Gap(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 12),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      items[index].toUpperCase(), 
                      style: const TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueAccent;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.blueAccent;
    }
  }
}