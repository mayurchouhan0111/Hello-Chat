import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/vip_tier_model.dart';
import 'package:hello_chat/core/providers/vip_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/services/gift_service.dart';
import 'package:go_router/go_router.dart';

// ── Color palette (Room Support System) ───────────────────────────────────
const _bg              = Color(0xFF070604);
const _surface         = Color(0xFF13100B);
const _surface2        = Color(0xFF1B1710);
const _borderGold      = Color(0xFF4A3A16);
const _gold            = Color(0xFFFFD700);
const _goldLight       = Color(0xFFFFE58F);
const _goldSub         = Color(0xFFD8B65C);
const _goldHeader      = Color(0xFFF7E7B4);
const _goldDim         = Color(0xFFFBC02D);
const _white           = Colors.white;

const _goldHeaderGradient = LinearGradient(
  colors: [
    Color(0xFFE5C058),
    Color(0xFFB38728),
    Color(0xFFFBF5B7),
    Color(0xFFDAA520),
    Color(0xFFA67C1E),
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _metallicBadgeGradient = LinearGradient(
  colors: [
    Color(0xFFFFF1B8),
    Color(0xFFD4AF37),
    Color(0xFFAA7C11),
    Color(0xFFF3E5AB),
    Color(0xFF8A6D1C),
  ],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class VIPShopScreen extends ConsumerStatefulWidget {
  const VIPShopScreen({super.key});

  @override
  ConsumerState<VIPShopScreen> createState() => _VIPShopScreenState();
}

class _VIPShopScreenState extends ConsumerState<VIPShopScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final tiersAsync   = ref.watch(vipTiersProvider);

    final userData = profileAsync.value;
    final balance  = (userData is UserModel) ? userData.diamondBalance : 0;

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _VipAppBar(balance: balance),
      ),
      body: Stack(
        children: [
          // ── Ambient background ──────────────────────────────────────────
          const _AmbientBackground(),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroSection(shimmer: _shimmerCtrl),
              ),

              // ── Category tabs ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: CategoryTabs(
                  selected: _selectedCategory,
                  onChanged: (cat) => setState(() => _selectedCategory = cat),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Tier list ─────────────────────────────────────────────
              tiersAsync.when(
                data: (tiers) {
                  final filtered = _selectedCategory == 'All'
                      ? tiers
                      : tiers.where((t) {
                    if (_selectedCategory == 'Starter') return t.level <= 2;
                    if (_selectedCategory == 'Pro')
                      return t.level > 2 && t.level <= 5;
                    if (_selectedCategory == 'Elite') return t.level > 5;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    const isAdmin = false;
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No VIP Tiers available.',
                                style: TextStyle(color: Colors.white38)),
                            // if (isAdmin) ...[
                            //   const SizedBox(height: 16),
                            //   _GoldButton(
                            //     label: 'Seed VIP Tiers (Admin)',
                            //     onTap: () async {
                            //       try {
                            //         await ref
                            //             .read(vipServiceProvider)
                            //             .feedSampleTiers();
                            //       } catch (e) {
                            //         debugPrint('Seed Error: $e');
                            //       }
                            //     },
                            //   ),
                            // ],
                          ],
                        ),
                      ),
                    );
                  }

                  final userData = profileAsync.value;
                  final currentVip = (userData is UserModel) ? userData.vipTier : 'none';
                  final remainingDays = (userData is UserModel) ? userData.vipRemainingDays : 0;

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final tier = filtered[index];
                          final isActive = currentVip.toLowerCase() == tier.name.toLowerCase();
                          return _AnimatedVipCard(
                            tier: tier,
                            index: index,
                            isActive: isActive,
                            remainingDays: remainingDays,
                            onTap: () => _showPurchaseSheet(context, tier),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: _GoldSpinner(),
                  ),
                ),
                error: (e, __) => SliverFillRemaining(
                  child: Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: Colors.white38)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () => _showDevSeedDialog(context),
      //   backgroundColor: Colors.tealAccent,
      //   icon: const Icon(Icons.science_rounded, color: Colors.black),
      //   label: const Text("DEV SEED", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      // ),
    );
  }

  void _showPurchaseSheet(BuildContext context, VIPTierModel tier) {
    final profileAsync = ref.read(currentUserProfileProvider);
    final userData = profileAsync.value;
    final isActive = userData is UserModel && userData.vipTier.toLowerCase() == tier.name.toLowerCase();
    final remainingDays = (userData is UserModel) ? userData.vipRemainingDays : 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VipPurchaseSheet(tier: tier, isActive: isActive, remainingDays: remainingDays),
    );
  }

  // void _showDevSeedDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: const Color(0xFF161616),
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(20),
  //         side: const BorderSide(color: Colors.tealAccent, width: 0.5),
  //       ),
  //       title: const Row(
  //         children: [
  //           Icon(Icons.science_rounded, color: Colors.tealAccent),
  //           SizedBox(width: 8),
  //           Text("Admin Seeding Panel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //         ],
  //       ),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         children: [
  //           const Text("Populate Firebase Firestore with default system catalog items:", style: TextStyle(color: Colors.white70, fontSize: 13)),
  //           const SizedBox(height: 16),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.workspace_premium, color: Colors.black),
  //             label: const Text("Seed VIP Tiers"),
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               try {
  //                 await ref.read(vipServiceProvider).feedSampleTiers();
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VIP Tiers Seeded!")));
  //                 }
  //               } catch (e) {
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  //                 }
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
  //           ),
  //           const SizedBox(height: 8),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.military_tech, color: Colors.black),
  //             label: const Text("Seed Noble Tiers"),
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               try {
  //                 await ref.read(vipServiceProvider).feedNobleTiers();
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Noble Tiers Seeded!")));
  //                 }
  //               } catch (e) {
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  //                 }
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
  //           ),
  //           const SizedBox(height: 8),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.storefront, color: Colors.black),
  //             label: const Text("Seed Prestige Boutique"),
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               try {
  //                 await ref.read(profileServiceProvider).feedPrestigeItems();
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prestige Boutique Seeded!")));
  //                 }
  //               } catch (e) {
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  //                 }
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
  //           ),
  //           const SizedBox(height: 8),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.card_giftcard, color: Colors.black),
  //             label: const Text("Seed Sample Gifts"),
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               try {
  //                 await ref.read(giftServiceProvider).feedSampleGifts();
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sample Gifts Seeded!")));
  //                 }
  //               } catch (e) {
  //                 if (context.mounted) {
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  //                 }
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
  //           ),
  //           const SizedBox(height: 16),
  //           const Divider(color: Colors.white24),
  //           const SizedBox(height: 8),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.done_all, color: Colors.white),
  //             label: const Text("SEED ALL SYSTEM DATA"),
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               showDialog(
  //                 context: context,
  //                 barrierDismissible: false,
  //                 builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
  //               );
  //               try {
  //                 await ref.read(vipServiceProvider).feedSampleTiers();
  //                 await ref.read(vipServiceProvider).feedNobleTiers();
  //                 await ref.read(profileServiceProvider).feedPrestigeItems();
  //                 await ref.read(giftServiceProvider).feedSampleGifts();
  //                 if (context.mounted) {
  //                   Navigator.pop(context); // close loader
  //                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully seeded all system data!")));
  //                 }
  //               } catch (e) {
  //                 if (context.mounted) {
  //                   Navigator.pop(context); // close loader
  //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed seeding: $e")));
  //                 }
  //               }
  //             },
  //             style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text("CLOSE", style: TextStyle(color: Colors.white38)),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

// ── Ambient Background ───────────────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Deep base
          Container(color: _bg),
          // Top-right glow
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withOpacity(0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-left glow
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _goldDim.withOpacity(0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Noise-like scanline overlay
          Positioned.fill(
            child: CustomPaint(painter: _ScanlinePainter()),
          ),
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── App Bar ───────────────────────────────────────────────────────────────────
class _VipAppBar extends StatelessWidget {
  final int balance;
  const _VipAppBar({required this.balance});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(color: _gold.withOpacity(0.08), width: 0.5),
            ),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
          ),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      color: Colors.white.withOpacity(0.04),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white60, size: 14),
                  ),
                ),

                // Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _gold),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'V  I  P',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _gold),
                    ),
                  ],
                ),

                // Diamond balance
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: _gold.withOpacity(0.25)),
                    borderRadius: BorderRadius.circular(20),
                    color: _gold.withOpacity(0.06),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.diamond_rounded,
                          color: _gold, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        balance.toString(),
                        style: const TextStyle(
                          color: _white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
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
}

// ── Hero Section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final AnimationController shimmer;
  const _HeroSection({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 70),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: double.infinity,
                height: 220,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                    bottom: Radius.circular(16),
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.black87,
                        Colors.black38,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.35, 0.65, 0.88, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/images/vip_shop_hero.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.3),
                            radius: 0.95,
                            colors: [
                              Color(0xFF4A3710),
                              Color(0xFF1F1608),
                              _bg,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.workspace_premium_rounded, color: _goldLight, size: 80),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                decoration: BoxDecoration(
                  gradient: _metallicBadgeGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFF9E6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 6)),
                    BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 18, spreadRadius: 2),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Prestige VIP Store",
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFF2A1D04),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        shadows: [
                          const Shadow(color: Colors.white70, blurRadius: 1, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFFFFE58F), blurRadius: 8, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () {
              context.push('/vip-rewards');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE2A200), Color(0xFF9E6B00)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderGold, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DAILY VIP REWARDS",
                          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Claim daily diamonds & XP bonuses",
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "CLAIM",
                          style: GoogleFonts.cinzel(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldCrownIcon extends StatelessWidget {
  const _GoldCrownIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _gold.withOpacity(0.08),
        border: Border.all(color: _gold.withOpacity(0.2)),
      ),
      child: const Icon(Icons.workspace_premium_rounded, color: _gold, size: 24),
    );
  }
}

class _PerkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _gold.withOpacity(0.06),
        border: Border.all(color: _gold.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 11),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: _goldLight, fontSize: 10, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ── Category Tabs ────────────────────────────────────────────────────────────
class CategoryTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const CategoryTabs({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Starter', 'Pro', 'Elite'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selected == cat;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isSelected ? _gold.withOpacity(0.12) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _gold.withOpacity(0.35) : Colors.white.withOpacity(0.07),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? _goldLight : Colors.white30,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Animated VIP Card wrapper ────────────────────────────────────────────────
class _AnimatedVipCard extends StatefulWidget {
  final VIPTierModel tier;
  final int index;
  final bool isActive;
  final int remainingDays;
  final VoidCallback onTap;
  const _AnimatedVipCard({
    required this.tier,
    required this.index,
    required this.isActive,
    required this.remainingDays,
    required this.onTap,
  });

  @override
  State<_AnimatedVipCard> createState() => _AnimatedVipCardState();
}

class _AnimatedVipCardState extends State<_AnimatedVipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: VipCard(tier: widget.tier, onTap: widget.onTap, isActive: widget.isActive, remainingDays: widget.remainingDays),
      ),
    );
  }
}

// ── VIP Card ─────────────────────────────────────────────────────────────────
class VipCard extends StatefulWidget {
  final VIPTierModel tier;
  final bool isActive;
  final int remainingDays;
  final VoidCallback onTap;
  const VipCard({super.key, required this.tier, required this.onTap, required this.isActive, required this.remainingDays});

  @override
  State<VipCard> createState() => _VipCardState();
}

class _VipCardState extends State<VipCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isActive) {
      _shimmerCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(VipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_shimmerCtrl.isAnimating) {
      _shimmerCtrl.repeat();
    } else if (!widget.isActive && _shimmerCtrl.isAnimating) {
      _shimmerCtrl.stop();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // Map level → accent tint so each card feels distinct
  Color get _tint {
    if (widget.tier.level <= 2) return const Color(0xFF7DB8F7); // blue-ish starter
    if (widget.tier.level <= 5) return const Color(0xFFFFD700); // gold pro
    return const Color(0xFFFFAB40);                             // ember elite
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _surface,
            border: Border.all(
              color: widget.isActive ? _gold.withOpacity(0.4) : Colors.white.withOpacity(0.05),
              width: widget.isActive ? 1.5 : 1,
            ),
            boxShadow: widget.isActive ? [
              BoxShadow(
                color: _gold.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: -2,
              )
            ] : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Left accent stripe
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _tint.withOpacity(0.8), 
                          _tint.withOpacity(0.1)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Sparkling / Shimmer light effect for active card
                if (widget.isActive)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          widthFactor: 2.0,
                          alignment: Alignment(
                            -1.5 + (_shimmerCtrl.value * 3.0),
                            0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _gold.withOpacity(0.08),
                                  _gold.withOpacity(0.15),
                                  _gold.withOpacity(0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.1, 0.45, 0.5, 0.55, 0.9],
                                transform: const GradientRotation(math.pi / 4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                  child: Row(
                    children: [
                      // Icon badge
                      _LevelBadge(level: widget.tier.level, tint: _tint, badgeIcon: widget.tier.badgeIcon),
                      const SizedBox(width: 16),

                      // Name + benefits
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.tier.name,
                              style: const TextStyle(
                                color: _white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.tier.benefits.take(2).join('  ·  '),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 10.5,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Price + button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond_rounded,
                                  color: _tint, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                widget.tier.monthlyPriceInDiamonds.toString(),
                                style: TextStyle(
                                  color: _tint,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (widget.isActive && widget.remainingDays > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.green.withOpacity(0.15),
                              ),
                              child: Text(
                                '${widget.remainingDays}d left',
                                style: TextStyle(
                                  color: Colors.green.shade400,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: [_gold, _goldDim],
                              ),
                            ),
                            child: Text(
                              widget.isActive ? 'CURRENT' : 'SELECT',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final Color tint;
  final String badgeIcon;
  const _LevelBadge({required this.level, required this.tint, required this.badgeIcon});

  @override
  Widget build(BuildContext context) {
    String resolvedBadge = badgeIcon;
    if (level >= 1 && level <= 8) {
      resolvedBadge = _getVipBadgePath(level);
    } else if (resolvedBadge.isNotEmpty) {
      final lowerBadge = resolvedBadge.toLowerCase();
      if (lowerBadge.startsWith('http') && lowerBadge.contains('vip/')) {
        for (int i = 1; i <= 8; i++) {
          if (lowerBadge.contains('vip%20$i/') || lowerBadge.contains('vip $i/')) {
            resolvedBadge = _getVipBadgePath(i);
            break;
          }
        }
      }
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withOpacity(0.08),
        border: Border.all(color: tint.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (resolvedBadge.isNotEmpty)
            ClipOval(
              child: resolvedBadge.startsWith('http')
                  ? Image.network(
                      resolvedBadge,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, color: tint, size: 26),
                    )
                  : Image.asset(
                      resolvedBadge,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, color: tint, size: 26),
                    ),
            )
          else
            Icon(Icons.workspace_premium_rounded, color: tint, size: 26),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'L$level',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gold Button ───────────────────────────────────────────────────────────────
class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GoldButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_gold, _goldDim]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ── Gold Spinner ──────────────────────────────────────────────────────────────
class _GoldSpinner extends StatelessWidget {
  const _GoldSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        color: _gold,
        strokeWidth: 2,
      ),
    );
  }
}

// ── Purchase Sheet ────────────────────────────────────────────────────────────
class _VipPurchaseSheet extends ConsumerStatefulWidget {
  final VIPTierModel tier;
  final bool isActive;
  final int remainingDays;
  const _VipPurchaseSheet({required this.tier, this.isActive = false, this.remainingDays = 0});

  @override
  ConsumerState<_VipPurchaseSheet> createState() => _VipPurchaseSheetState();
}

class _VipPurchaseSheetState extends ConsumerState<_VipPurchaseSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withOpacity(0.08),
                  border: Border.all(color: _gold.withOpacity(0.25)),
                ),
                child: () {
                  String resolvedBadge = widget.tier.badgeIcon;
                  final level = widget.tier.level;
                  if (level >= 1 && level <= 8) {
                    resolvedBadge = _getVipBadgePath(level);
                  } else if (resolvedBadge.isNotEmpty) {
                    final lowerBadge = resolvedBadge.toLowerCase();
                    if (lowerBadge.startsWith('http') && lowerBadge.contains('vip/')) {
                      for (int i = 1; i <= 8; i++) {
                        if (lowerBadge.contains('vip%20$i/') || lowerBadge.contains('vip $i/')) {
                          resolvedBadge = _getVipBadgePath(i);
                          break;
                        }
                      }
                    }
                  }

                  if (resolvedBadge.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: resolvedBadge.startsWith('http')
                          ? Image.network(resolvedBadge, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40))
                          : Image.asset(resolvedBadge, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40)),
                    );
                  }
                  return const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40);
                }(),
              ),

              const SizedBox(height: 16),

              // Tier name
              Text(
                widget.tier.name,
                style: const TextStyle(
                  color: _white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 4),
              Text(
                'Monthly Membership',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.isActive && widget.remainingDays > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.withOpacity(0.12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${widget.remainingDays} days remaining',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (widget.isActive && widget.remainingDays <= 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.red.withOpacity(0.12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'Expired - Renew Now',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Thin divider
              Container(height: 0.5, color: Colors.white.withOpacity(0.07)),
              const SizedBox(height: 24),

              // Benefits grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.8,
                ),
                itemCount: widget.tier.benefits.length,
                itemBuilder: (_, i) => Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _gold.withOpacity(0.05),
                    border:
                    Border.all(color: _gold.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          color: _gold, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.tier.benefits[i],
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Price display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _gold.withOpacity(0.06),
                  border: Border.all(color: _gold.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.diamond_rounded, color: _gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.tier.monthlyPriceInDiamonds.toString(),
                      style: const TextStyle(
                        color: _goldLight,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'diamonds / month',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Confirm button
              GestureDetector(
                onTap: _isLoading ? null : () => _handleConfirm(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: _isLoading 
                        ? [Colors.grey.shade800, Colors.grey.shade900]
                        : [_goldLight, _gold, _goldDim],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: _isLoading ? [] : [
                      BoxShadow(
                        color: _gold.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Unlock Membership  ◈ ${widget.tier.monthlyPriceInDiamonds}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                ),
              ),

              const SizedBox(height: 12),

              if (!_isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Not now',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(vipServiceProvider).purchaseVIP(widget.tier);
      if (mounted) {
        Navigator.pop(context); // Close sheet on success
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.tier.name} VIP Activated!'),
          backgroundColor: const Color(0xFF1A6B3A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Purchase Failed: $e'),
          backgroundColor: const Color(0xFF6B1A1A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

String _getVipBadgePath(int level) {
  if (level == 1) return 'assets/VIP/VIP 1/Badge.webp';
  if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Badge.png';
  if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Badge.webp';
  if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Badge.webp';
  if (level == 5) return 'assets/VIP/VIP 5/VIP 5/Badge.png';
  if (level == 6) return 'assets/VIP/VIP 6/VIP 6/Badge.webp';
  if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Badge.png';
  if (level == 8) return 'assets/VIP/VIP 8/VIP 8/Badge.webp';
  return '';
}