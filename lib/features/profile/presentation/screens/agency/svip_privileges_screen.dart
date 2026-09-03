import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../../core/models/user_model.dart';
import '../../../../../core/providers/profile_provider.dart';
import '../../widgets/svip/svip_card_carousel.dart';
import '../../widgets/svip/svip_daily_claim_vault.dart';
import '../../widgets/svip/svip_badge_showcase.dart';
import '../../widgets/svip/svip_privileges_grid.dart';
import '../../widgets/svip/svip_tier_matrix_table.dart';
import '../../widgets/svip/svip_faq_rules.dart';

class SVIPPrivilegesScreen extends ConsumerStatefulWidget {
  const SVIPPrivilegesScreen({super.key});

  @override
  ConsumerState<SVIPPrivilegesScreen> createState() => _SVIPPrivilegesScreenState();
}

class _SVIPPrivilegesScreenState extends ConsumerState<SVIPPrivilegesScreen> {
  int _selectedTier = 1;
  bool _isClaimingReward = false;

  static const Color darkBg = Color(0xFF070604);
  static const Color textGoldHeader = Color(0xFFF7E7B4);
  static const Color textGoldSub = Color(0xFFD8B65C);
  static const Color textGoldBright = Color(0xFFFFE58F);

  Future<void> _claimDailyReward(UserModel? user) async {
    final svipLevel = user?.svipLevel ?? 0;
    if (svipLevel <= 0) {
      _showToast('Active SVIP membership required to claim daily diamond rewards.');
      return;
    }

    setState(() => _isClaimingReward = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('claimSvipDailyReward');
      final result = await callable.call();
      if (result.data != null && result.data['success'] == true) {
        final amount = result.data['rewardAmount'] ?? 0;
        if (mounted) {
          _showToast('🎉 Successfully claimed $amount Diamonds!', isSuccess: true);
          ref.invalidate(currentUserProfileProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(e.toString().replaceAll('Exception:', '').replaceAll('FirebaseFunctionsException:', '').trim());
      }
    } finally {
      if (mounted) setState(() => _isClaimingReward = false);
    }
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavBar(context),
            Expanded(
              child: userAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: textGoldBright)),
                error: (err, stack) => Center(
                  child: Text("Error: $err", style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                ),
                data: (user) {
                  final currentLevel = user?.svipLevel ?? 0;
                  final effectiveTier = _selectedTier > 0 ? _selectedTier : (currentLevel > 0 ? currentLevel : 1);

                  return RefreshIndicator(
                    color: const Color(0xFFFFD700),
                    backgroundColor: const Color(0xFF13100B),
                    onRefresh: () async {
                      ref.invalidate(currentUserProfileProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          const Gap(12),
                          // Hero Header Banner
                          _buildHeroHeader(user, currentLevel),

                          const Gap(20),

                          // Component 1: Swipeable 3D Card Carousel
                          SvipCardCarousel(
                            user: user,
                            selectedTier: effectiveTier,
                            onTierChanged: (tier) {
                              setState(() => _selectedTier = tier);
                            },
                          ),

                          const Gap(18),

                          // Component 2: Daily Diamond Claim Vault
                          SvipDailyClaimVault(
                            user: user,
                            selectedTier: effectiveTier,
                            isClaiming: _isClaimingReward,
                            onClaim: () => _claimDailyReward(user),
                          ),

                          const Gap(20),

                          // Component 3: Video-Exact Pill Badges Preview
                          const SvipBadgeShowcase(),

                          const Gap(20),

                          // Component 4: 11 Interactive Privileges Grid
                          SvipPrivilegesGrid(
                            user: user,
                            selectedTier: effectiveTier,
                            onShowToast: (msg) => _showToast(msg),
                          ),

                          const Gap(20),

                          // Component 5: Side-by-Side Comparison Matrix Table
                          const SvipTierMatrixTable(),

                          const Gap(20),

                          // Component 6: FAQ and Explanations
                          const SvipFaqRules(),

                          const Gap(24),

                          // Footer Disclaimer
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              "★ 1 USD Recharge = 100 SVIP Points. Each tier is valid for 60 days.\nImmediate upgrade starts a new 60-day cycle and resets SVIP Points to 0.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: textGoldSub.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTopNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0A05),
        border: Border(bottom: BorderSide(color: Color(0xFF261C0A), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textGoldHeader, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            "SVIP MEMBERSHIP CENTER",
            style: GoogleFonts.cinzel(
              color: textGoldHeader,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balances the back icon
        ],
      ),
    );
  }

  Widget _buildHeroHeader(UserModel? user, int currentLevel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0.0, -0.6),
          radius: 1.2,
          colors: [
            Color(0xFF382A0F),
            Color(0xFF1B1408),
            Color(0xFF0D0A05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A3A16), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
              const Gap(8),
              Text(
                "ELITE SVIP PRIVILEGES",
                style: GoogleFonts.cinzel(
                  color: textGoldHeader,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  shadows: const [
                    Shadow(color: Color(0xFFFFD700), blurRadius: 10),
                  ],
                ),
              ),
              const Gap(8),
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
            ],
          ),
          const Gap(6),
          Text(
            "Highest Platform Status • Room Immunity • Global Authority",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: textGoldSub,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
