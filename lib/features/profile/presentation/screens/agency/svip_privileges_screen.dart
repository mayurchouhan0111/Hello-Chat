import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../../../../core/models/svip_level_model.dart';
import '../../../../../core/providers/profile_provider.dart';

class SVIPPrivilegesScreen extends ConsumerWidget {
  const SVIPPrivilegesScreen({super.key});

  // Ultra-Luxury Gold Palette (Room Support Design System)
  static const Color darkBg = Color(0xFF070604);
  static const Color cardBg = Color(0xFF13100B);
  static const Color tableRowBgEven = Color(0xFF1B1710);
  static const Color tableRowBgOdd = Color(0xFF13100B);
  static const Color borderGold = Color(0xFF4A3A16);
  static const Color borderGoldLight = Color(0xFF7E6327);
  static const Color textGoldHeader = Color(0xFFF7E7B4);
  static const Color textGoldSub = Color(0xFFD8B65C);
  static const Color textGoldBright = Color(0xFFFFE58F);

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav Bar
            _buildTopNavBar(context),

            Expanded(
              child: userAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: textGoldBright)),
                error: (err, stack) => Center(
                  child: Text("Error: $err", style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                ),
                data: (user) {
                  final currentRecharge = user?.monthlyRecharge ?? 0;
                  final currentLevel = user?.svipLevel ?? -1;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
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

                        // Monthly Recharge Status Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _buildStatusCard(currentRecharge, currentLevel),
                        ),

                        const Gap(20),

                        // SVIP Tier Matrix Table Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _buildMatrixTableCard(currentRecharge),
                        ),

                        const Gap(24),

                        // Footer Note
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "*SVIP status is calculated based on cumulative recharge within a single calendar month. Rank resets on the 1st of every month.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: textGoldSub.withOpacity(0.6),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP NAV BAR ──────────────────────────────────────────────────────────
  Widget _buildTopNavBar(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: darkBg,
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
                "SVIP PRIVILEGES",
                style: GoogleFonts.cinzel(
                  color: textGoldBright,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // Spacer to balance back button
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
        color: darkBg,
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
          'assets/images/svip_hero.png',
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
                    darkBg,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.stars_rounded, color: textGoldBright, size: 90),
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
        gradient: metallicBadgeGradient,
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
            "SVIP Privileges",
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

  // ─── MONTHLY RECHARGE STATUS CARD ──────────────────────────────────────────
  Widget _buildStatusCard(int currentRecharge, int currentLevel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: textGoldBright, size: 16),
                  const Gap(6),
                  Text(
                    "Monthly Recharge: ${_formatNumber(currentRecharge)} 💎",
                    style: GoogleFonts.plusJakartaSans(
                      color: textGoldSub,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: goldHeaderGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentLevel >= 0 ? "SVIP $currentLevel" : "NO SVIP",
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFF241804),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentRecharge / 500000000).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF221B0F),
              color: textGoldBright,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MATRIX TABLE CARD ─────────────────────────────────────────────────────
  Widget _buildMatrixTableCard(int currentRecharge) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Metallic Gold Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              gradient: goldHeaderGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                "Privilege Tiers",
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF241804),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Table Content
          Padding(
            padding: const EdgeInsets.all(10),
            child: Table(
              border: TableBorder.all(color: borderGold, width: 0.8),
              columnWidths: const {
                0: FlexColumnWidth(1.0),
                1: FlexColumnWidth(1.6),
                2: FlexColumnWidth(1.2),
              },
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFF221B0F)),
                  children: [
                    _buildCell("LEVEL", isHeader: true),
                    _buildCell("Monthly Recharge", isHeader: true),
                    _buildCell("SVIP Points", isHeader: true),
                  ],
                ),
                // Table Rows
                ...SVIPLevelModel.levels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final level = entry.value;
                  final isAchieved = currentRecharge >= level.monthlyRechargeRequirement;
                  final isEven = index % 2 == 0;

                  return TableRow(
                    decoration: BoxDecoration(
                      color: isAchieved 
                          ? const Color(0xFF4A3A16).withOpacity(0.4)
                          : (isEven ? tableRowBgEven : tableRowBgOdd),
                    ),
                    children: [
                      _buildCell(level.name, isGold: isAchieved),
                      _buildCell("${_formatNumber(level.monthlyRechargeRequirement)} 💎", isGold: isAchieved),
                      _buildCell("${level.svipPoints}", isGold: isAchieved),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isGold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: isHeader
            ? GoogleFonts.cinzel(color: textGoldHeader, fontSize: 11, fontWeight: FontWeight.bold)
            : GoogleFonts.plusJakartaSans(
                color: isGold ? textGoldBright : Colors.white70,
                fontSize: 12,
                fontWeight: isGold ? FontWeight.bold : FontWeight.normal,
              ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}M";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(0)}K";
    return number.toString();
  }
}

