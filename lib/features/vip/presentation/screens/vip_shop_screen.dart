import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/vip_tier_model.dart';
import 'package:hello_chat/core/providers/vip_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';

// ── Gold accent palette (VIP branding) ──────────────────────────────────────
const _gold       = Color(0xFFD4AF37);
const _goldLight  = Color(0xFFFFE58F);
const _goldDim    = Color(0xFFFBC02D);
const _goldSub    = Color(0xFF8A6D1C);

class VIPShopScreen extends ConsumerStatefulWidget {
  const VIPShopScreen({super.key});

  @override
  ConsumerState<VIPShopScreen> createState() => _VIPShopScreenState();
}

class _VIPShopScreenState extends ConsumerState<VIPShopScreen> {
  int _selectedTierLevel = 1;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final tiersAsync   = ref.watch(vipTiersProvider);

    final userData = profileAsync.value;
    final balance  = (userData is UserModel) ? userData.diamondBalance : 0;
    final currentVip = (userData is UserModel) ? userData.vipTier : 'none';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, color: _gold, size: 20),
            const Gap(8),
            Text(
              "VIP Store",
              style: GoogleFonts.cinzel(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 14),
                const Gap(6),
                Text(
                  "$balance",
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: tiersAsync.when(
        data: (tiers) {
          if (tiers.isEmpty) {
            return const Center(
              child: Text("No VIP tiers available", style: TextStyle(color: AppColors.textTertiary)),
            );
          }

          final selectedTier = tiers.firstWhere(
            (t) => t.level == _selectedTierLevel,
            orElse: () => tiers.first,
          );

          final bool isCurrentActive = currentVip.toLowerCase() == selectedTier.name.toLowerCase();

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVIPHeroCard(selectedTier, isCurrentActive),
                    const Gap(28),
                    _buildTierSelector(tiers),
                    const Gap(28),
                    _buildPrivilegeList(selectedTier),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPurchaseButton(selectedTier, isCurrentActive),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textTertiary))),
      ),
    );
  }

  Widget _buildVIPHeroCard(VIPTierModel tier, bool isActive) {
    final badgeAsset = _getCrownPngForTier(tier);
    final level = tier.level;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF9EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _gold.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: _gold.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          // Crown badge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _gold.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: _gold.withOpacity(0.2), blurRadius: 16)],
            ),
            child: Image.asset(
              badgeAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40),
            ),
          ),
          const Gap(20),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isActive ? "YOUR CURRENT TIER" : "TIER OVERVIEW",
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Gap(6),
                Text(
                  tier.name.toUpperCase(),
                  style: GoogleFonts.cinzel(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Gap(6),
                Text(
                  "Enjoy exclusive privileges and\nstand out in every room.",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 12),
                      const Gap(5),
                      Text(
                        "${tier.monthlyPriceInDiamonds} Diamonds / month",
                        style: const TextStyle(color: _goldSub, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (isActive) ...[
                  const Gap(8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                      Gap(5),
                      Text(
                        "Active",
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelector(List<VIPTierModel> tiers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose your tier",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const Gap(12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: tiers.map((tier) {
              final isSelected = tier.level == _selectedTierLevel;
              return GestureDetector(
                onTap: () => setState(() => _selectedTierLevel = tier.level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _gold.withOpacity(0.14) : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _gold : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: _gold.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: isSelected ? _gold : AppColors.textTertiary,
                        size: 16,
                      ),
                      const Gap(6),
                      Text(
                        "VIP ${tier.level}",
                        style: TextStyle(
                          color: isSelected ? _goldSub : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivilegeList(VIPTierModel tier) {
    final level = tier.level;

    final path = level == 1 ? 'assets/VIP/VIP 1' : 'assets/VIP/VIP $level/VIP $level';
    String entryPng = '$path/Entry.png';
    String framePng = '$path/Frame.png';
    String bubblePng = '$path/Chat Bubble.png';
    String badgePng = _getCrownPngForTier(tier);

    if (level == 2) framePng = '$path/Frame 2.png';
    if (level == 3) framePng = '$path/Frame 3.png';
    if (level == 4) framePng = '$path/Frame 4.png';
    if (level == 5) framePng = '$path/User Frame 5.png';
    if (level == 6) {
      entryPng = '$path/VIP 6 Entry.png';
      framePng = '$path/User Frame 6.png';
    }
    if (level == 7) framePng = '$path/Frame 7.png';
    if (level == 8) {
      entryPng = '$path/VIP 8 Entry Effect.png';
      framePng = '$path/User Frame 8.png';
    }

    final benefits = [
      {'title': 'Exclusive 1v1 Support', 'sub': 'Priority VIP room & help desk', 'asset': bubblePng, 'fallbackIcon': FontAwesomeIcons.headset},
      {'title': 'VIP Entrance Effect', 'sub': 'Grand 3D animated room arrival', 'asset': entryPng, 'fallbackIcon': FontAwesomeIcons.doorOpen},
      {'title': 'Premium Profile Frame', 'sub': 'Gold ornate avatar frame', 'asset': framePng, 'fallbackIcon': Icons.crop_portrait_rounded},
      {'title': 'Custom Mic Icon', 'sub': 'Crown badge on speaker seat', 'asset': badgePng, 'fallbackIcon': FontAwesomeIcons.microphone},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "VIP $level Exclusive Privileges",
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const Gap(12),
        ...benefits.map((b) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.6)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF6E0),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    b['asset'] as String,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(b['fallbackIcon'] as IconData, color: _gold, size: 20),
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['title'] as String,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const Gap(4),
                      Text(
                        b['sub'] as String,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: _gold, size: 18),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPurchaseButton(VIPTierModel tier, bool isCurrentActive) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.6))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: GestureDetector(
        onTap: () => _showPurchaseSheet(context, tier),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA67C1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _gold.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isCurrentActive ? "EXTEND VIP ${tier.level}" : "UNLOCK VIP ${tier.level}",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
              ),
              const Gap(2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFF0284C7), size: 12),
                  const Gap(4),
                  Text(
                    "${tier.monthlyPriceInDiamonds} Diamonds / month",
                    style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCrownPngForTier(VIPTierModel tier) {
    switch (tier.level) {
      case 1: return 'assets/VIP/VIP 1/Badge.webp';
      case 2: return 'assets/VIP/VIP 2/VIP 2/Badge.png';
      case 3: return 'assets/VIP/VIP 3/VIP 3/Badge.webp';
      case 4: return 'assets/VIP/VIP 4/VIP 4/Badge.webp';
      case 5: return 'assets/VIP/VIP 5/VIP 5/Badge.png';
      case 6: return 'assets/VIP/VIP 6/VIP 6/Badge.webp';
      case 7: return 'assets/VIP/VIP 7/VIP 7/Badge.png';
      case 8: return 'assets/VIP/VIP 8/VIP 8/Badge.webp';
      default: return 'assets/VIP/VIP 1/Badge.webp';
    }
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
            color: AppColors.surface.withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppColors.border.withOpacity(0.6)),
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withOpacity(0.1),
                  border: Border.all(color: _gold.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    _getVipBadgePath(widget.tier.level),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: _gold, size: 40),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tier name
              Text(
                widget.tier.name,
                style: GoogleFonts.cinzel(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 4),
              Text(
                'Monthly Membership',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
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
                    color: AppColors.success.withOpacity(0.1),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${widget.remainingDays} days remaining',
                    style: const TextStyle(
                      color: AppColors.success,
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
                    color: AppColors.error.withOpacity(0.1),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Expired - Renew Now',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Thin divider
              Container(height: 0.5, color: AppColors.divider),
              const SizedBox(height: 24),

              // Benefits grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.8,
                ),
                itemCount: widget.tier.benefits.length,
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _gold.withOpacity(0.07),
                    border: Border.all(color: _gold.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded, color: _gold, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.tier.benefits[i],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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
                  color: _gold.withOpacity(0.08),
                  border: Border.all(color: _gold.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.tier.monthlyPriceInDiamonds.toString(),
                      style: const TextStyle(
                        color: _goldSub,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'diamonds / month',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
                          ? [Colors.grey.shade300, Colors.grey.shade400]
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
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
        AppToast.showSuccess(context, '${widget.tier.name} VIP Activated!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, 'Purchase Failed: $e');
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