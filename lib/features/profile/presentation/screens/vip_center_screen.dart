import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/vip_provider.dart';
import '../../../../core/models/vip_tier_model.dart';

// ─────────────────────────────────────────────
//  Color Utility — parse hex from backend
// ─────────────────────────────────────────────
extension HexColor on Color {
  /// Parse "#RRGGBB" or "#AARRGGBB" sent from backend
  static Color fromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    } else if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return const Color(0xFF10B981); // fallback emerald
  }

  Color get lighter => Color.lerp(this, Colors.white, 0.3)!;
  Color get darker  => Color.lerp(this, Colors.black, 0.5)!;
  Color get dimmed  => withOpacity(0.15);
  Color get faint   => withOpacity(0.06);
  Color get border  => withOpacity(0.35);
}

// ─────────────────────────────────────────────
//  Global Design Tokens
// ─────────────────────────────────────────────
class VIPTheme {
  static const bg       = Color(0xFF080A0C);
  static const surface  = Color(0xFF0E1117);
  static const surface2 = Color(0xFF151A22);
  static const surface3 = Color(0xFF1C2330);
  static const text     = Color(0xFFF0F4F8);
  static const textSub  = Color(0xFF8A95A3);
  static const textHint = Color(0xFF3D4A58);
  static const divider  = Color(0xFF1A2030);
}

// ─────────────────────────────────────────────
//  VIP Carousel Screen
// ─────────────────────────────────────────────
class VIPCarouselScreen extends ConsumerStatefulWidget {
  const VIPCarouselScreen({super.key});

  @override
  ConsumerState<VIPCarouselScreen> createState() => _VIPCarouselScreenState();
}

class _VIPCarouselScreenState extends ConsumerState<VIPCarouselScreen>
    with TickerProviderStateMixin {

  final PageController _pageController = PageController(viewportFraction: 0.82);
  int _currentPage = 0;
  int? _expandedIndex; // which card has details slid open

  // per-card animation controllers
  final Map<int, AnimationController> _detailControllers = {};
  final Map<int, Animation<double>> _detailAnims = {};

  // background glow animation
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.07, end: 0.16)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  AnimationController _controllerFor(int index) {
    return _detailControllers.putIfAbsent(index, () {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );
      _detailAnims[index] = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
      return ctrl;
    });
  }

  void _toggleExpand(int index) {
    HapticFeedback.lightImpact();
    final ctrl = _controllerFor(index);

    if (_expandedIndex == index) {
      ctrl.reverse();
      setState(() => _expandedIndex = null);
    } else {
      // close previously open card
      if (_expandedIndex != null) {
        _detailControllers[_expandedIndex!]?.reverse();
      }
      ctrl.forward();
      setState(() => _expandedIndex = index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowCtrl.dispose();
    for (final c in _detailControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final vipTiersAsync = ref.watch(vipTiersProvider);

    return Scaffold(
      backgroundColor: VIPTheme.bg,
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => _buildBackground(_glowAnim.value),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                Expanded(
                  child: vipTiersAsync.when(
                    data: (tiers) => profileAsync.when(
                      data: (user) => _buildContent(tiers, user),
                      loading: _buildLoader,
                      error: (e, _) => _buildError(),
                    ),
                    loading: _buildLoader,
                    error: (e, _) => _buildError(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _VIPGuideSheet(),
    );
  }


  // ── Background ───────────────────────────────
  Widget _buildBackground(double opacity) {
    return Positioned.fill(
      child: Stack(children: [
        Positioned(
          top: -120, left: 0, right: 0,
          child: Container(
            height: 500,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.75,
                colors: [
                  const Color(0xFF10B981).withOpacity(opacity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60, right: -60,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withOpacity(opacity * 0.3),
            ),
          ),
        ),
      ]),
    );
  }

  // ── AppBar ───────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _CircleBtn(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: VIPTheme.textSub, size: 15),
          ),
          const Spacer(),
          Column(
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF10B981)],
                ).createShader(b),
                child: const Text(
                  'VIP CENTRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                  ),
                ),
              ),
              const Gap(3),
              Container(
                width: 32, height: 1.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF10B981)],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _CircleBtn(
            onTap: () => _showInfoBottomSheet(context),
            child: const Icon(Icons.info_outline_rounded,
                color: VIPTheme.textSub, size: 16),
          ),

        ],
      ),
    );
  }

  // ── Main Content ─────────────────────────────
  Widget _buildContent(List<VIPTierModel> tiers, dynamic user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(20),

          // ── Information Banner ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showInfoBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [const Color(0xFF10B981).withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withOpacity(0.1),
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                    const Gap(14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIP Membership Guide',
                            style: TextStyle(
                              color: VIPTheme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Learn about 80/20 credits & daily rewards',
                            style: TextStyle(color: VIPTheme.textSub, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: VIPTheme.textHint, size: 12),
                  ],
                ),
              ),
            ),
          ),

          // ── Special Events Carousel ──────────
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16),
                const Gap(8),
                const Text(
                  'SPECIAL EVENTS',
                  style: TextStyle(
                    color: VIPTheme.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${DateTime.now().day}/${DateTime.now().month} Update',
                  style: const TextStyle(color: VIPTheme.textHint, fontSize: 10),
                ),
              ],
            ),
          ),
          const Gap(16),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _EventCard(
                  title: 'First Time Purchase',
                  benefit: '20,000,000 ◆',
                  price: 'ONLY \$10',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.flash_on_rounded,
                  onTap: () {},
                ),
                const Gap(12),
                _EventCard(
                  title: '30-Day Bonus Event',
                  benefit: 'UP TO 100M ◆',
                  price: 'Tiered Reward',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.auto_graph_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const Gap(32),

          // Heading


          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Your\nMembership',
                  style: TextStyle(
                    color: VIPTheme.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const Gap(8),
                const Text(
                  'Swipe to explore all tiers — tap a card for details',
                  style: TextStyle(
                    color: VIPTheme.textSub,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          // ── Carousel ──────────────────────────
          SizedBox(
            height: 220,

            child: PageView.builder(
              controller: _pageController,
              itemCount: tiers.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final tier = tiers[index];
                final accent = HexColor.fromHex(tier.themeColor ?? '#10B981');
                final isCenter = index == _currentPage;
                final userTier = (user?.vipTier ?? '').toLowerCase();
                final isActive = userTier == (tier.name ?? '').toLowerCase() && userTier != 'none';

                return AnimatedScale(
                  scale: isCenter ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: isCenter ? 1.0 : 0.55,
                    duration: const Duration(milliseconds: 300),
                    child: _VIPCarouselCard(
                      tier: tier,
                      accent: accent,
                      isActive: isActive,
                      isExpanded: _expandedIndex == index,
                      onTap: () => _toggleExpand(index),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Dot indicators ────────────────────
          const Gap(20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tiers.length, (i) {
                final accent = HexColor.fromHex(
                  tiers[i].themeColor ?? '#10B981',
                );
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive ? accent : VIPTheme.surface3,
                  ),
                );
              }),
            ),
          ),
          const Gap(32),

          // ── Expanded detail panel ─────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(sizeFactor: anim, child: child),
            ),
            child: _expandedIndex != null && _expandedIndex! < tiers.length
                ? _buildDetailPanel(tiers[_expandedIndex!], key: ValueKey(_expandedIndex))
                : const SizedBox.shrink(),
          ),

          // ── Tier entry table ──────────────────
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTierEntryTable(tiers, user),
          ),
          const Gap(32),
        ],
      ),
    );
  }

  // ── Detail Panel (slides in below carousel) ──
  Widget _buildDetailPanel(VIPTierModel tier, {Key? key}) {
    final accent = HexColor.fromHex(tier.themeColor ?? '#10B981');
    final benefits = tier.benefits ?? [];

    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: VIPTheme.surface2,
        border: Border.all(color: accent.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header stripe
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [accent.darker.withOpacity(0.6), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: accent.withOpacity(0.12))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.dimmed,
                    border: Border.all(color: accent.border, width: 0.5),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: accent.lighter, size: 18),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (tier.name ?? 'VIP').toUpperCase(),
                        style: TextStyle(
                          color: accent.lighter,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Tier Level ${tier.level ?? 0} · ${tier.monthlyPriceInDiamonds ?? 0} diamonds/mo',
                        style: const TextStyle(
                          color: VIPTheme.textSub,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: accent.dimmed,
                    border: Border.all(color: accent.border, width: 0.5),
                  ),
                  child: Text(
                    '${benefits.length} perks',
                    style: TextStyle(
                      color: accent.lighter,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Benefits list — full detail
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALL BENEFITS',
                  style: TextStyle(
                    color: VIPTheme.textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Gap(14),
                ...benefits.asMap().entries.map((e) {
                  final label = e.value.toString().replaceAll('_', ' ');
                  final desc   = _benefitDescription(e.value.toString());
                  return _BenefitDetailRow(
                    index: e.key,
                    label: label,
                    description: desc,
                    accent: accent,
                  );
                }),
              ],
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _GradientButton(
              accent: accent,
              label: 'Purchase — ${tier.monthlyPriceInDiamonds ?? 0} Diamonds',
              onTap: () {
                HapticFeedback.heavyImpact();
                // ref.read(vipServiceProvider).purchaseVIP(tier);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tier Entry Table ─────────────────────────
  Widget _buildTierEntryTable(List<VIPTierModel> tiers, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'TIER ENTRY',
              style: TextStyle(
                color: VIPTheme.textSub,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const Gap(12),
            Expanded(child: Container(height: 0.5, color: VIPTheme.divider)),
          ],
        ),
        const Gap(14),
        ...tiers.asMap().entries.map((e) {
          final tier   = e.value;
          final accent = HexColor.fromHex(tier.themeColor ?? '#10B981');
          final userTier = (user?.vipTier ?? '').toLowerCase();
          final isActive = userTier == (tier.name ?? '').toLowerCase() && userTier != 'none';
          return _TierEntryRow(
            tier: tier,
            accent: accent,
            isActive: isActive,
            isLast: e.key == tiers.length - 1,
          );
        }),
      ],
    );
  }

  // ── Benefit description helper ───────────────
  String _benefitDescription(String key) {
    const map = {
      'room_upgrade':       'Complimentary upgrade from Deluxe to Presidential Suite based on availability.',
      'birthday_bonus':     'Exclusive surprise gift package delivered to you on your birthday.',
      'partner_discounts':  'Up to 60% off at 200+ partner brands including dining, travel & lifestyle.',
      'sunrise_feast':      'Complimentary gourmet breakfast for two every morning of your stay.',
      'special_packages':   'Curated spa, wellness & leisure retreat packages throughout the year.',
      'priority_checkin':   'Dedicated VIP check-in lane with zero wait time at all partner venues.',
      'lounge_access':      'Unlimited access to all VIP lounges across partner airports & clubs.',
      'concierge':          '24/7 personal concierge service for bookings, reservations & requests.',
      'cashback':           'Earn up to 10% cashback on all purchases made through the platform.',
      'early_access':       'First access to new features, events & limited-edition drops.',
    };
    return map[key] ?? 'Exclusive benefit included with your VIP membership tier.';
  }

  Widget _buildLoader() => const Center(
    child: CircularProgressIndicator(
      color: Color(0xFF10B981), strokeWidth: 1.5),
  );

  Widget _buildError() => const Center(
    child: Text('Something went wrong', style: TextStyle(color: Colors.redAccent)),
  );
}

// ─────────────────────────────────────────────
//  Carousel Card Widget
// ─────────────────────────────────────────────
class _VIPCarouselCard extends StatelessWidget {
  final VIPTierModel tier;
  final Color accent;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;

  const _VIPCarouselCard({
    required this.tier,
    required this.accent,
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final benefits = (tier.benefits ?? []).take(3).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isExpanded
                ? accent.withOpacity(0.7)
                : accent.withOpacity(0.2),
            width: isExpanded ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isExpanded ? 0.18 : 0.06),
              blurRadius: isExpanded ? 30 : 12,
              spreadRadius: isExpanded ? 2 : 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              // Background gradient from backend color
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.22),
                        accent.withOpacity(0.04),
                        VIPTheme.surface2,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Dot pattern overlay
              Positioned.fill(child: CustomPaint(painter: _DotPainter(accent))),

              // Decorative circle
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.07),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: accent.withOpacity(0.18),
                            border: Border.all(color: accent.withOpacity(0.35), width: 0.5),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: tier.badgeIcon ?? '',
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.workspace_premium_rounded,
                              color: accent.withOpacity(0.9),
                              size: 18,
                            ),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (tier.name ?? 'VIP').toUpperCase(),
                                style: const TextStyle(
                                  color: VIPTheme.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  height: 1,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'Level ${tier.level ?? 0}',
                                style: TextStyle(
                                  color: accent.withOpacity(0.85),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive) _ActivePill(accent: accent),
                      ],
                    ),

                    const Spacer(),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 18),
                        const Gap(5),
                        ShaderMask(
                          shaderCallback: (b) => LinearGradient(
                            colors: [accent.lighter, accent],
                          ).createShader(b),
                          child: Text(
                            '${tier.monthlyPriceInDiamonds ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const Gap(5),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'diamonds / mo',
                            style: TextStyle(
                              color: VIPTheme.textSub,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Gap(10),

                    // Benefits preview chips
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: benefits.map((b) {
                        final label = b.toString().replaceAll('_', ' ');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: accent.withOpacity(0.12),
                            border: Border.all(color: accent.withOpacity(0.22), width: 0.5),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: accent.withOpacity(0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Gap(10),

                    // Tap hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              color: accent.withOpacity(0.6), size: 16),
                        ),
                        const Gap(3),
                        Text(
                          isExpanded ? 'Collapse' : 'Tap for Details',
                          style: TextStyle(
                            color: accent.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
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
    );
  }
}

// ─────────────────────────────────────────────
//  Benefit Detail Row
// ─────────────────────────────────────────────
class _BenefitDetailRow extends StatelessWidget {
  final int index;
  final String label;
  final String description;
  final Color accent;

  const _BenefitDetailRow({
    required this.index,
    required this.label,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12),
              border: Border.all(color: accent.withOpacity(0.25), width: 0.5),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: accent.lighter,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: VIPTheme.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Gap(4),
                Text(
                  description,
                  style: const TextStyle(
                    color: VIPTheme.textSub,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tier Entry Row (below carousel)
// ─────────────────────────────────────────────
class _TierEntryRow extends StatelessWidget {
  final VIPTierModel tier;
  final Color accent;
  final bool isActive;
  final bool isLast;

  const _TierEntryRow({
    required this.tier,
    required this.accent,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? accent : VIPTheme.surface3,
                    border: Border.all(
                      color: isActive ? accent.lighter : VIPTheme.divider,
                      width: 0.5,
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 10)]
                        : [],
                  ),
                  child: Icon(
                    isActive ? Icons.check_rounded : Icons.circle_outlined,
                    color: isActive ? Colors.white : VIPTheme.textHint,
                    size: 14,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: VIPTheme.divider,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isActive ? accent.withOpacity(0.07) : VIPTheme.surface2,
                border: Border.all(
                  color: isActive ? accent.withOpacity(0.35) : VIPTheme.divider,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              (tier.name ?? 'VIP').toUpperCase(),
                              style: TextStyle(
                                color: isActive ? accent.lighter : VIPTheme.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (isActive) ...[
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: accent.withOpacity(0.15),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: accent.lighter,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Gap(3),
                        Text(
                          'Entry: ${tier.entryRequirement ?? 'No requirement'} · ${tier.benefits?.length ?? 0} benefits',
                          style: const TextStyle(
                            color: VIPTheme.textSub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 12),
                      const Gap(4),
                      Text(
                        '${tier.monthlyPriceInDiamonds ?? 0}',
                        style: TextStyle(
                          color: isActive ? accent.lighter : VIPTheme.textSub,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared Small Widgets
// ─────────────────────────────────────────────

class _ActivePill extends StatelessWidget {
  final Color accent;
  const _ActivePill({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.18),
        border: Border.all(color: accent.withOpacity(0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.lighter),
          ),
          const Gap(5),
          Text(
            'ACTIVE',
            style: TextStyle(
              color: accent.lighter,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final Color accent;
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.accent, required this.label, required this.onTap});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [widget.accent.lighter, widget.accent, widget.accent.darker],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _CircleBtn({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VIPTheme.surface2,
        border: Border.all(color: VIPTheme.divider, width: 0.5),
      ),
      child: Center(child: child),
    ),
  );
}

// ─────────────────────────────────────────────
//  Dot pattern painter (uses card accent color)
// ─────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.04);
    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
}

// ─────────────────────────────────────────────
//  Event Card Widget
// ─────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final String title;
  final String benefit;
  final String price;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _EventCard({
    required this.title,
    required this.benefit,
    required this.price,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10, top: -10,
              child: Icon(icon, color: color.withOpacity(0.08), size: 60),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VIPTheme.textSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Gap(4),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 14),
                      const Gap(5),
                      Text(
                        benefit.replaceAll(' ◆', ''),
                        style: const TextStyle(
                          color: VIPTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: color.withOpacity(0.2),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        color: color.lighter,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
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
}


// ─────────────────────────────────────────────
//  VIP Guide Sheet (Themed Info)
// ─────────────────────────────────────────────
class _VIPGuideSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF10B981); // Emerald base

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: VIPTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          const Gap(12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: VIPTheme.surface3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(24),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: accent, size: 24),
                ),
                const Gap(16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership Guide',
                      style: TextStyle(
                        color: VIPTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Everything about VIP Club',
                      style: TextStyle(color: VIPTheme.textSub, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(32),

          // Info Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _InfoCard(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Diamond Exchange Rates',
                      desc: '\$1 = 450,000 Diamonds\n\$5 = 2,250,000 Diamonds\n\$25 = 11,250,000 Diamonds\n\$100 = 45,000,000 Diamonds',
                      accent: accent),

                  const Gap(16),
                  _InfoCard(
                      icon: Icons.payments_rounded,
                      title: '80/20 Credit Policy',

                      desc: 'When you subscribe, 80% of the Diamonds are credited immediately. The remaining 20% will be automatically released to your wallet after 30 days.',
                      accent: accent),
                  const Gap(16),
                  _InfoCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Daily Rewards',
                      desc: 'Active VIP members can claim an exclusive Diamond bonus every single day from the VIP Center. Don\'t miss out!',
                      accent: accent),
                  const Gap(16),
                  _InfoCard(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Premium Branding',
                      desc: 'Every tier unlocks unique profile badges, entry animations, and chat colors that scale with your membership level.',
                      accent: accent),
                  const Gap(16),
                  _InfoCard(
                      icon: Icons.security_rounded,
                      title: 'Exclusive Perks',
                      desc: 'High-tier members receive kick protection, administrative immunity, and priority access to room microphones.',
                      accent: accent),
                  const Gap(32),
                ],
              ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: _GradientButton(
              accent: accent,
              label: 'Got it',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color accent;

  const _InfoCard({required this.icon, required this.title, required this.desc, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VIPTheme.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VIPTheme.divider, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent.withOpacity(0.8), size: 20),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VIPTheme.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Gap(6),
                Text(
                  desc,
                  style: const TextStyle(
                    color: VIPTheme.textSub,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}