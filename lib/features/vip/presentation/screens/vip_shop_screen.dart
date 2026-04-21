import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/vip_tier_model.dart';
import 'package:hello_chat/core/providers/vip_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';

// ── Color palette ──────────────────────────────────────────────────────────
const _bg        = Color(0xFF080808);
const _surface   = Color(0xFF111111);
const _surface2  = Color(0xFF161616);
const _gold      = Color(0xFFFFD700);
const _goldLight = Color(0xFFFFEB3B);
const _goldDim   = Color(0xFFFBC02D);
const _white     = Colors.white;

// ── Text styles ─────────────────────────────────────────────────────────────
const _serif = TextStyle(fontFamily: 'Georgia'); // serif fallback

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
                    const isAdmin = true;
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No VIP Tiers available.',
                                style: TextStyle(color: Colors.white38)),
                            if (isAdmin) ...[
                              const SizedBox(height: 16),
                              _GoldButton(
                                label: 'Seed VIP Tiers (Admin)',
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(vipServiceProvider)
                                        .feedSampleTiers();
                                  } catch (e) {
                                    debugPrint('Seed Error: $e');
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final tier = filtered[index];
                          return _AnimatedVipCard(
                            tier: tier,
                            index: index,
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
    );
  }

  void _showPurchaseSheet(BuildContext context, VIPTierModel tier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VipPurchaseSheet(tier: tier),
    );
  }
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 110, 16, 28),
      child: Stack(
        children: [
          // Card body
          Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Crown icon row
                Row(
                  children: [
                    const _GoldCrownIcon(),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXCLUSIVE',
                          style: TextStyle(
                            color: _gold.withOpacity(0.6),
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          'Membership',
                          style: TextStyle(
                            color: _white,
                            fontSize: 22,
                            fontWeight: FontWeight.w200,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Divider with gold dot
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: _gold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Join the elite circle and unlock exclusive prestige benefits tailored for kings.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
                // Perks row
                Row(
                  children: [
                    _PerkPill(icon: Icons.bolt_rounded, label: 'Priority'),
                    const SizedBox(width: 8),
                    _PerkPill(icon: Icons.shield_rounded, label: 'Exclusive'),
                    const SizedBox(width: 8),
                    _PerkPill(icon: Icons.star_rounded, label: 'Prestige'),
                  ],
                ),
              ],
            ),
          ),
          // Shimmer line at top
          Positioned(
            top: 0,
            left: 40,
            right: 40,
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                return Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _gold.withOpacity(0.6 * math.sin(shimmer.value * math.pi)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  final VoidCallback onTap;
  const _AnimatedVipCard({
    required this.tier,
    required this.index,
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
        child: VipCard(tier: widget.tier, onTap: widget.onTap),
      ),
    );
  }
}

// ── VIP Card ─────────────────────────────────────────────────────────────────
class VipCard extends StatefulWidget {
  final VIPTierModel tier;
  final VoidCallback onTap;
  const VipCard({super.key, required this.tier, required this.onTap});

  @override
  State<VipCard> createState() => _VipCardState();
}

class _VipCardState extends State<VipCard> {
  bool _pressed = false;

  // Map level → accent tint so each card feels distinct
  Color get _tint {
    if (widget.tier.level <= 2) return const Color(0xFF7DB8F7); // blue-ish starter
    if (widget.tier.level <= 5) return const Color(0xFFFFD700); // gold pro
    return const Color(0xFFFFAB40);                             // ember elite (adjusted to warmer yellow/orange)
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
            border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                        colors: [_tint.withOpacity(0.8), _tint.withOpacity(0.1)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Subtle tint glow top-left
                Positioned(
                  top: -20,
                  left: 0,
                  child: Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [_tint.withOpacity(0.06), Colors.transparent],
                      ),
                    ),
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
                            child: const Text(
                              'SELECT',
                              style: TextStyle(
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
          if (badgeIcon.isNotEmpty)
            ClipOval(
              child: Image.network(
                badgeIcon,
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
class _VipPurchaseSheet extends ConsumerWidget {
  final VIPTierModel tier;
  const _VipPurchaseSheet({required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: tier.badgeIcon.isNotEmpty 
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.network(tier.badgeIcon, fit: BoxFit.contain),
                      )
                    : const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40),
              ),

              const SizedBox(height: 16),

              // Tier name
              Text(
                tier.name,
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
                itemCount: tier.benefits.length,
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
                          tier.benefits[i],
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
                      tier.monthlyPriceInDiamonds.toString(),
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
                onTap: () => _handleConfirm(context, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [_goldLight, _gold, _goldDim],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Unlock Membership  ◈ ${tier.monthlyPriceInDiamonds}',
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

  void _handleConfirm(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      await ref.read(vipServiceProvider).purchaseVIP(tier);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${tier.name} VIP Activated!'),
          backgroundColor: const Color(0xFF1A6B3A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFF6B1A1A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}