import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import 'package:hello_chat/core/models/svip_level_model.dart';
import 'package:hello_chat/core/models/user_model.dart';

class SvipDailyClaimVault extends StatefulWidget {
  final UserModel? user;
  final int selectedTier;
  final bool isClaiming;
  final VoidCallback onClaim;

  const SvipDailyClaimVault({
    super.key,
    required this.user,
    required this.selectedTier,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  State<SvipDailyClaimVault> createState() => _SvipDailyClaimVaultState();
}

class _SvipDailyClaimVaultState extends State<SvipDailyClaimVault> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1-second ticker to keep the 24h UTC cooldown live
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = widget.user?.svipLevel ?? 0;
    final tier = SVIPLevelModel.getLevelByTier(currentLevel > 0 ? currentLevel : widget.selectedTier);
    final isEligible = currentLevel > 0;

    // 24-hour UTC cooldown calculation
    bool isCooldownActive = false;
    Duration remainingCooldown = Duration.zero;

    if (widget.user?.lastSvipRewardClaimAt != null) {
      final lastClaim = widget.user!.lastSvipRewardClaimAt!;
      final nextClaim = lastClaim.add(const Duration(hours: 24));
      final now = DateTime.now();
      if (now.isBefore(nextClaim)) {
        isCooldownActive = true;
        remainingCooldown = nextClaim.difference(now);
      }
    }

    final hours = remainingCooldown.inHours.toString().padLeft(2, '0');
    final minutes = (remainingCooldown.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remainingCooldown.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13100B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A3A16), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Vault 3D Coin Icon with Glow
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 30),
              ),
              const Gap(14),
              // Vault Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DAILY DIAMOND VAULT",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFFFE58F),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      "${_formatNumber(tier.dailyDiamondReward)} Diamonds",
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                    const Gap(2),
                    Text(
                      isEligible
                          ? (isCooldownActive ? "Next Claim in $hours:$minutes:$seconds" : "✨ Ready to claim now!")
                          : "Requires active SVIP membership",
                      style: GoogleFonts.plusJakartaSans(
                        color: isCooldownActive ? Colors.white60 : const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: (!isEligible || isCooldownActive || widget.isClaiming)
                  ? null
                  : widget.onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.white12,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: (!isEligible || isCooldownActive)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFF8F00)],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: (!isEligible || isCooldownActive)
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: widget.isClaiming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          !isEligible
                              ? "UPGRADE TO SVIP TO CLAIM"
                              : (isCooldownActive ? "CLAIMED TODAY ($hours:$minutes:$seconds)" : "CLAIM DAILY DIAMONDS"),
                          style: GoogleFonts.plusJakartaSans(
                            color: (!isEligible || isCooldownActive) ? Colors.white38 : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
