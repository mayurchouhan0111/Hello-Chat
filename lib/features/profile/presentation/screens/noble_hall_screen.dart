import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/vip_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/vip_tier_model.dart';

// ─────────────────────────────────────────────
//  Color Utility — parse hex from backend
// ─────────────────────────────────────────────
extension HexColor on Color {
  static Color fromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    } else if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return const Color(0xFFD4AF37); // fallback gold
  }

  Color get lighter => Color.lerp(this, Colors.white, 0.3)!;
  Color get darker  => Color.lerp(this, Colors.black, 0.5)!;
  Color get dimmed  => withOpacity(0.15);
  Color get faint   => withOpacity(0.06);
  Color get border  => withOpacity(0.35);
}

// ─────────────────────────────────────────────
//  Noble Theme Tokens
// ─────────────────────────────────────────────
class NobleTheme {
  static const bg       = Color(0xFF080808);
  static const surface  = Color(0xFF0E0E0E);
  static const surface2 = Color(0xFF151515);
  static const surface3 = Color(0xFF1C1C1C);
  static const text     = Color(0xFFF0F4F8);
  static const textSub  = Color(0xFF8A95A3);
  static const textHint = Color(0xFF3D4A58);
  static const divider  = Color(0xFF1A1A1A);
  static const gold     = Color(0xFFD4AF37);
  static const silver   = Color(0xFFC0C0C0);
}

// ─────────────────────────────────────────────
//  Noble Hall Carousel Screen
// ─────────────────────────────────────────────
class NobleHallScreen extends ConsumerStatefulWidget {
  const NobleHallScreen({super.key});

  @override
  ConsumerState<NobleHallScreen> createState() => _NobleHallScreenState();
}

class _NobleHallScreenState extends ConsumerState<NobleHallScreen>
    with TickerProviderStateMixin {

  final PageController _pageController = PageController(viewportFraction: 0.82);
  int _currentPage = 0;
  int? _expandedIndex;
  bool _isPurchasing = false;

  final Map<int, AnimationController> _detailControllers = {};
  final Map<int, Animation<double>> _detailAnims = {};

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.08, end: 0.22)
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
    final userAsync = ref.watch(currentUserProfileProvider);
    final userTier = userAsync.value?.nobleTier ?? "Civilian";
    final remainingDays = userAsync.value is UserModel ? userAsync.value!.nobleRemainingDays : 0;
    final nobleTiersAsync = ref.watch(nobleTiersProvider);

    return Scaffold(
      backgroundColor: NobleTheme.bg,
      body: Stack(
        children: [
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
                  child: nobleTiersAsync.when(
                    data: (tiers) => _buildContent(tiers, userTier, remainingDays),
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
                  NobleTheme.gold.withOpacity(opacity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _CircleBtn(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: NobleTheme.textSub, size: 15),
          ),
          const Spacer(),
          Column(
            children: [
              const Text(
                'NOBLE HALL',
                style: TextStyle(
                  color: NobleTheme.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.5,
                ),
              ),
              const Gap(3),
              Container(
                width: 32, height: 1.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: NobleTheme.gold,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CircleBtn(
            onTap: () {},
            child: const Icon(Icons.info_outline_rounded,
                color: NobleTheme.textSub, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<VIPTierModel> tiers, String userTier, int remainingDays) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accept Your\nRoyal Title',
                  style: TextStyle(
                    color: NobleTheme.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const Gap(8),
                const Text(
                  'Explore the aristocratic hierarchy and its privileges',
                  style: TextStyle(color: NobleTheme.textSub, fontSize: 13),
                ),
              ],
            ),
          ),
          const Gap(24),
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              itemCount: tiers.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final tier = tiers[index];
                final accent = HexColor.fromHex(tier.themeColor ?? '#D4AF37');
                final isCenter = index == _currentPage;
                final isActive = userTier == tier.name;

                return AnimatedScale(
                  scale: isCenter ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: isCenter ? 1.0 : 0.55,
                    duration: const Duration(milliseconds: 300),
                    child: _NobleCarouselCard(
                      tier: tier,
                      accent: accent,
                      isActive: isActive,
                      remainingDays: remainingDays,
                      isExpanded: _expandedIndex == index,
                      onTap: () => _toggleExpand(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const Gap(20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tiers.length, (i) {
                final accent = HexColor.fromHex(tiers[i].themeColor ?? '#D4AF37');
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive ? accent : NobleTheme.surface3,
                  ),
                );
              }),
            ),
          ),
          const Gap(32),
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
        ],
      ),
    );
  }

  Widget _buildDetailPanel(VIPTierModel tier, {Key? key}) {
    final accent = HexColor.fromHex(tier.themeColor ?? '#D4AF37');
    final benefits = tier.benefits;

    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: NobleTheme.surface2,
        border: Border.all(color: accent.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: Icon(Icons.shield_rounded, color: accent.lighter, size: 18),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name.toUpperCase(),
                        style: TextStyle(
                          color: accent.lighter,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Noble Rank · ${tier.monthlyPriceInDiamonds} diamonds',
                        style: const TextStyle(color: NobleTheme.textSub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOBLE PRIVILEGES',
                  style: TextStyle(
                    color: NobleTheme.textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Gap(14),
                ...benefits.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: accent, size: 16),
                        const Gap(12),
                        Expanded(child: Text(e.value.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _NobleAcceptButton(
              accent: accent,
              label: 'ACCEPT TITLE — ${tier.monthlyPriceInDiamonds} Diamonds',
              isLoading: _isPurchasing,
              onTap: () async {
                HapticFeedback.heavyImpact();
                setState(() => _isPurchasing = true);
                try {
                  await ref.read(vipServiceProvider).purchaseNoble(tier);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Successfully subscribed to ${tier.name}!'),
                      backgroundColor: const Color(0xFF1A6B3A),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Purchase failed: $e'),
                      backgroundColor: const Color(0xFF6B1A1A),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isPurchasing = false);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() => const Center(child: CircularProgressIndicator(color: NobleTheme.gold, strokeWidth: 1.5));
  Widget _buildError() => const Center(child: Text('Something went wrong', style: TextStyle(color: Colors.redAccent)));
}

class _NobleCarouselCard extends StatelessWidget {
  final VIPTierModel tier;
  final Color accent;
  final bool isActive;
  final int remainingDays;
  final bool isExpanded;
  final VoidCallback onTap;

  const _NobleCarouselCard({
    required this.tier,
    required this.accent,
    required this.isActive,
    required this.remainingDays,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isExpanded ? accent.withOpacity(0.7) : accent.withOpacity(0.2),
            width: isExpanded ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isExpanded ? 0.18 : 0.06),
              blurRadius: isExpanded ? 30 : 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent.withOpacity(0.25), accent.withOpacity(0.04), NobleTheme.surface2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: tier.backgroundImage,
                  imageBuilder: (context, imageProvider) => Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.75), BlendMode.darken),
                      ),
                    ),
                  ),
                  placeholder: (context, url) => Container(color: Colors.black26),
                  errorWidget: (context, url, error) => Container(color: Colors.black26),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 130, height: 130, // Much larger icon focal point
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.5), width: 3),
                            boxShadow: [
                              BoxShadow(color: accent.withOpacity(0.4), blurRadius: 40, spreadRadius: 4),
                            ],
                            gradient: RadialGradient(
                              colors: [accent.withOpacity(0.2), Colors.transparent],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CachedNetworkImage(
                              imageUrl: tier.badgeIcon,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => Icon(Icons.shield_rounded, color: accent, size: 60),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Column(
                      children: [
                        Text(
                          tier.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond_rounded, color: accent, size: 16),
                              const Gap(8),
                              Text(
                                "${tier.monthlyPriceInDiamonds}",
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        if (isActive && remainingDays > 0) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$remainingDays days remaining',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

class _CircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _CircleBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: NobleTheme.surface3,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _NobleAcceptButton extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isLoading;
  final VoidCallback? onTap;
  const _NobleAcceptButton({
    required this.label,
    required this.accent,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade800, Colors.grey.shade900]
                : [accent, accent.darker],
          ),
          boxShadow: isLoading
              ? []
              : [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: accent.lighter,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}