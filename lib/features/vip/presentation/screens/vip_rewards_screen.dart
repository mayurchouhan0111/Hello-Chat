import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/widgets/app_avatar.dart';

class VIPRewardsScreen extends ConsumerStatefulWidget {
  const VIPRewardsScreen({super.key});

  @override
  ConsumerState<VIPRewardsScreen> createState() => _VIPRewardsScreenState();
}

class _VIPRewardsScreenState extends ConsumerState<VIPRewardsScreen> {
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _calculateTimeUntilReset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateTimeUntilReset();
      }
    });
  }

  void _calculateTimeUntilReset() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    setState(() {
      _timeUntilReset = tomorrow.difference(now);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${hours}h ${minutes}m ${seconds}s";
  }

  bool _hasClaimedToday(UserModel user) {
    if (user.lastDailyClaim == null) return false;
    final now = DateTime.now().toUtc();
    final lastClaim = user.lastDailyClaim!.toUtc();
    return lastClaim.year == now.year &&
        lastClaim.month == now.month &&
        lastClaim.day == now.day;
  }

  Map<String, int> _getTierRewards(String vipTier) {
    final tier = vipTier.toLowerCase();
    if (tier.contains("vip 1") || tier.contains("vip1")) {
      return {'diamonds': 100, 'xp': 10};
    } else if (tier.contains("vip 2") || tier.contains("vip2")) {
      return {'diamonds': 300, 'xp': 25};
    } else if (tier.contains("vip 3") || tier.contains("vip3")) {
      return {'diamonds': 800, 'xp': 50};
    } else if (tier.contains("vip 4") || tier.contains("vip4")) {
      return {'diamonds': 2000, 'xp': 100};
    } else if (tier.contains("vip 5") || tier.contains("vip5")) {
      return {'diamonds': 5000, 'xp': 200};
    } else if (tier.contains("vip 6") || tier.contains("vip6")) {
      return {'diamonds': 10000, 'xp': 400};
    } else if (tier.contains("vip 7") || tier.contains("vip7")) {
      return {'diamonds': 25000, 'xp': 1000};
    }
    return {'diamonds': 50, 'xp': 10}; // Fallback
  }

  Future<void> _claimReward(UserModel user) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    final rewards = _getTierRewards(user.vipTier);
    final int diamonds = rewards['diamonds'] ?? 100;
    final int xp = rewards['xp'] ?? 10;

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('claimVipDailyReward');
      final response = await callable.call();
      final data = response.data as Map<dynamic, dynamic>;
      final int cloudDiamonds = data['diamonds'] ?? diamonds;
      final int cloudXp = data['xp'] ?? xp;
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        _showSuccessDialog(cloudDiamonds, cloudXp);
      }
    } catch (e) {
      print("--- [VIP REWARD] Cloud claim failed: $e ---");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not claim reward right now. Please try again."),
            backgroundColor: Colors.amber.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showSuccessDialog(int diamonds, int xp) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.2), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 44),
              ),
              const Gap(20),
              const Text(
                "REWARD CLAIMED!",
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const Gap(8),
              const Text(
                "Your daily VIP bonus has been added to your balance.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRewardDisplayItem("+$diamonds", "Diamonds", Icons.diamond_rounded, const Color(0xFF38BDF8)),
                  _buildRewardDisplayItem("+$xp", "XP Points", Icons.bolt_rounded, const Color(0xFFFFD700)),
                ],
              ),
              const Gap(28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("GREAT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardDisplayItem(String val, String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        const Gap(8),
        Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("VIP Daily Rewards", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text("User profile not found.", style: TextStyle(color: Colors.white30)));
          if (!user.isVipActive) return _buildLockedState();

          final rewards = _getTierRewards(user.vipTier);
          final claimed = _hasClaimedToday(user);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVipHeaderCard(user),
                const Gap(20),
                _buildRewardDetailsCard(user, rewards, claimed),
                const Gap(32),
                if (claimed) _buildCountdownWidget() else _buildClaimButton(user),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
        error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white30))),
      ),
    );
  }

  Widget _buildVipHeaderCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C0F5F), Color(0xFF1C0A3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 28,
            vipTier: user.vipTier,
            frameUrl: user.profileFrame,
            userLevel: user.level,
            tags: user.tags,
            frameMultiplier: 2.0,
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Gap(4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: Text(
                    user.vipTier.toUpperCase(),
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardDetailsCard(UserModel user, Map<String, int> rewards, bool claimed) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF130030),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Text(
            claimed ? "CLAIMED TODAY" : "YOUR DAILY REWARDS",
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const Gap(24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBigRewardBadge(rewards['diamonds'].toString(), "Diamonds", Icons.diamond_rounded, const Color(0xFF00FFD1)),
              Container(width: 1, height: 50, color: Colors.white10),
              _buildBigRewardBadge(rewards['xp'].toString(), "XP Points", Icons.bolt_rounded, const Color(0xFFFFD700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigRewardBadge(String amount, String name, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 32),
        const Gap(10),
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const Gap(4),
        Text(name, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildClaimButton(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(_isClaiming ? 0.0 : 0.3),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isClaiming ? null : () => _claimReward(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          disabledBackgroundColor: const Color(0xFFFFD700).withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: _isClaiming
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : const Text(
                "CLAIM DAILY BONUS",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
      ),
    );
  }

  Widget _buildCountdownWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white30, size: 16),
              const Gap(6),
              Text(
                "Next reward claim resets in:",
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Gap(8),
          Text(
            _formatDuration(_timeUntilReset),
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 40),
            ),
            const Gap(24),
            const Text(
              "DAILY REWARDS LOCKED",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            const Gap(10),
            const Text(
              "Vip Daily Rewards are exclusive to active VIP members. Unlock premium bonuses, frames, and custom badges today!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            ),
            const Gap(32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/vip-shop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC00FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  "VISIT VIP SHOP",
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
