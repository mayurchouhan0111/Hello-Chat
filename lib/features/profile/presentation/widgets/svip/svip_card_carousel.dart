import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import 'package:hello_chat/core/models/svip_level_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/widgets/user_badge.dart';

class SvipCardCarousel extends StatefulWidget {
  final UserModel? user;
  final int selectedTier;
  final ValueChanged<int> onTierChanged;

  const SvipCardCarousel({
    super.key,
    required this.user,
    required this.selectedTier,
    required this.onTierChanged,
  });

  @override
  State<SvipCardCarousel> createState() => _SvipCardCarouselState();
}

class _SvipCardCarouselState extends State<SvipCardCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Default carousel page to user's current SVIP tier or 1
    final initialPage = (widget.selectedTier - 1).clamp(0, 5);
    _pageController = PageController(initialPage: initialPage, viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tiers = SVIPLevelModel.levels;
    final currentLevel = widget.user?.svipLevel ?? 0;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: tiers.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              widget.onTierChanged(index + 1);
            },
            itemBuilder: (context, index) {
              final tier = tiers[index];
              final isCurrent = currentLevel == tier.level;
              final isSelected = widget.selectedTier == tier.level;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: isSelected ? 4 : 10,
                ),
                child: _buildTierCard(tier, isCurrent, isSelected),
              );
            },
          ),
        ),
        const Gap(10),
        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tiers.length, (index) {
            final isSelected = widget.selectedTier == index + 1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: isSelected ? 22 : 6,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFD700) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTierCard(SVIPLevelModel tier, bool isCurrent, bool isSelected) {
    final svipPoints = widget.user?.svipPoints ?? 0;
    final progress = (svipPoints / tier.requiredPoints).clamp(0.0, 1.0);
    final cardDecor = _getTierCardDecoration(tier.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: cardDecor.gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFFD700)
              : cardDecor.borderColor.withValues(alpha: isSelected ? 0.9 : 0.4),
          width: isCurrent ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: cardDecor.glowColor.withValues(alpha: isSelected ? 0.35 : 0.15),
            blurRadius: isSelected ? 18 : 10,
            spreadRadius: isSelected ? 1 : 0,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Row 1: Badge & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvipTierBadge(level: tier.level),
                  const Gap(8),
                  Text(
                    tier.name,
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    "ACTIVE TIER",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                Text(
                  "\$${tier.requiredPoints ~/ 100} USD",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          // Row 2: Progress & Validity info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCurrent
                        ? "Current Cycle Points"
                        : "Target Requirement: ${tier.requiredPoints} Pts",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "$svipPoints / ${tier.requiredPoints} Pts",
                    style: GoogleFonts.plusJakartaSans(
                      color: cardDecor.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Gap(6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(cardDecor.accentColor),
                ),
              ),
            ],
          ),

          // Row 3: Validity or Daily Diamonds
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 14),
                  const Gap(4),
                  Text(
                    "${tier.dailyDiamondReward} Diamonds / Day",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00E5FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isCurrent && widget.user?.svipCycleEndDate != null)
                _buildValidityCountdown(widget.user!.svipCycleEndDate!)
              else
                Text(
                  "60 Days Validity",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidityCountdown(DateTime endDate) {
    final remaining = endDate.difference(DateTime.now());
    final days = remaining.inDays.clamp(0, 60);
    final hours = (remaining.inHours % 24).clamp(0, 23);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: Colors.amberAccent),
          const Gap(4),
          Text(
            "${days}d ${hours}h left",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.amberAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _TierCardDecoration _getTierCardDecoration(int level) {
    switch (level) {
      case 1: // Bronze
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1810), Color(0xFF4A2A1A), Color(0xFF1B0E09)],
          ),
          borderColor: const Color(0xFFCD853F),
          glowColor: const Color(0xFFCD853F),
          accentColor: const Color(0xFFDAA520),
        );
      case 2: // Silver
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E252B), Color(0xFF343F47), Color(0xFF12171A)],
          ),
          borderColor: const Color(0xFFB0BEC5),
          glowColor: const Color(0xFFCFD8DC),
          accentColor: const Color(0xFFECEFF1),
        );
      case 3: // Gold
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2000), Color(0xFF524000), Color(0xFF1A1400)],
          ),
          borderColor: const Color(0xFFFFD700),
          glowColor: const Color(0xFFFFD700),
          accentColor: const Color(0xFFFFE082),
        );
      case 4: // Amethyst
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF260D38), Color(0xFF48176B), Color(0xFF150621)],
          ),
          borderColor: const Color(0xFFBA68C8),
          glowColor: const Color(0xFFBA68C8),
          accentColor: const Color(0xFFE1BEE7),
        );
      case 5: // Ruby
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF38081E), Color(0xFF6B113B), Color(0xFF1E030F)],
          ),
          borderColor: const Color(0xFFFF4081),
          glowColor: const Color(0xFFFF4081),
          accentColor: const Color(0xFFFF80AB),
        );
      case 6: // Obsidian Gold
      default:
        return _TierCardDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0B18), Color(0xFF3D1F00), Color(0xFF1A0A00)],
          ),
          borderColor: const Color(0xFFFFD700),
          glowColor: const Color(0xFFFF6F00),
          accentColor: const Color(0xFFFFD54F),
        );
    }
  }
}

class _TierCardDecoration {
  final LinearGradient gradient;
  final Color borderColor;
  final Color glowColor;
  final Color accentColor;

  _TierCardDecoration({
    required this.gradient,
    required this.borderColor,
    required this.glowColor,
    required this.accentColor,
  });
}
