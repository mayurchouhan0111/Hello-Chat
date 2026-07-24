import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
//  Noble Theme Tokens (Room Support System)
// ─────────────────────────────────────────────
class NobleTheme {
  static const darkBg          = Color(0xFF070604);
  static const cardBg          = Color(0xFF13100B);
  static const tableRowBgEven  = Color(0xFF1B1710);
  static const tableRowBgOdd   = Color(0xFF13100B);
  static const borderGold      = Color(0xFF4A3A16);
  static const borderGoldLight = Color(0xFF7E6327);
  static const textGoldHeader  = Color(0xFFF7E7B4);
  static const textGoldSub     = Color(0xFFD8B65C);
  static const textGoldBright  = Color(0xFFFFE58F);

  // Legacy field aliases for helper widgets
  static const bg       = darkBg;
  static const surface  = cardBg;
  static const surface2 = tableRowBgEven;
  static const surface3 = tableRowBgOdd;
  static const text     = textGoldHeader;
  static const textSub  = textGoldSub;
  static const textHint = Color(0xFF66532B);
  static const divider  = borderGold;
  static const gold     = textGoldBright;
  static const silver   = Color(0xFFC0C0C0);

  static const LinearGradient goldHeaderGradient = LinearGradient(
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

  static const LinearGradient metallicBadgeGradient = LinearGradient(
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
      backgroundColor: NobleTheme.darkBg,
      body: SafeArea(
        child: Column(
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
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: NobleTheme.darkBg,
        border: Border(bottom: BorderSide(color: Color(0xFF221B0E), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                "NOBLE HALL",
                style: GoogleFonts.cinzel(
                  color: NobleTheme.textGoldBright,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(List<VIPTierModel> tiers, String userTier, int remainingDays) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ultra-Premium Hero Banner with Top-to-Bottom Opacity Fade & Outside Floating Title Badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildHeroBanner(),
              ),
              Positioned(
                bottom: -18,
                child: _buildTitleBadge(),
              ),
            ],
          ),

          const Gap(32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Accept Your Royal Title',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: NobleTheme.textGoldBright,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const Gap(6),
                Text(
                  'Explore the aristocratic hierarchy and its privileges',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: NobleTheme.textGoldSub, fontSize: 12),
                ),
              ],
            ),
          ),
          const Gap(20),
          SizedBox(
            height: 230,
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
          const Gap(16),
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
                    color: isActive ? accent : NobleTheme.borderGold,
                  ),
                );
              }),
            ),
          ),
          const Gap(24),
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

  // ─── HERO BANNER (TOP-TO-BOTTOM OPACITY FADE) ──────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: NobleTheme.darkBg,
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
          'assets/images/noble_hall_hero.png',
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
                    NobleTheme.darkBg,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.shield_rounded, color: NobleTheme.textGoldBright, size: 90),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 3D METALLIC GOLD TITLE BADGE ──────────────────────────────────────────
  Widget _buildTitleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        gradient: NobleTheme.metallicBadgeGradient,
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
            "Noble Hall",
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