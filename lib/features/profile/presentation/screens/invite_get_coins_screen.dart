import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/constants/app_colors.dart';

class InviteGetCoinsScreen extends ConsumerStatefulWidget {
  const InviteGetCoinsScreen({super.key});

  @override
  ConsumerState<InviteGetCoinsScreen> createState() => _InviteGetCoinsScreenState();
}

class _InviteGetCoinsScreenState extends ConsumerState<InviteGetCoinsScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _shareInvite(String code) {
    HapticFeedback.mediumImpact();
    Share.share(
      'Join me on Hello Chat! 🌹 Use my invite code: $code to get 50 Diamonds! 💎 Download: https://hellochat.app',
      subject: 'Invite Reward',
    );
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Code Copied! ✓"), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileServiceProvider).redeemReferralCode(code);
      if (mounted) {
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Bonus Credited!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("INVITE & EARN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // 🎁 Modern Compact Header
                      _buildCompactHero(),

                      const Gap(12),
                      
                      // 🪙 Visual Progress Steps
                      _buildVisualProgressBar(),

                      const Gap(12),

                      // 🆔 My Code - Small Card
                      _buildSmallCodeCard(user.referralCode),

                      const Gap(12),

                      // 🎟️ Redeem Box - Cute Gradient
                      if (user.referredBy == null || user.referredBy!.isEmpty)
                        _buildCompactRedeem()
                      else
                        _buildAlreadyDone(),

                      const Gap(20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => const SizedBox(),
      ),
    );
  }

  Widget _buildCompactHero() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: "https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=800&q=80",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("SHARE THE LOVE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
                Gap(2),
                Text("Invite & Earn Wealth", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text("Get 100 Beans per friend instantly.", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildVisualProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem(Icons.send_rounded, "Share Code", true),
          _stepConnector(),
          _stepItem(Icons.person_add_alt_1_rounded, "Friend Joins", false),
          _stepConnector(),
          _stepItem(Icons.diamond_rounded, "Claim Coins", false),
        ],
      ),
    );
  }

  Widget _stepItem(IconData icon, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: active ? Colors.orange : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: active ? Colors.white : Colors.grey[400], size: 16),
        ),
        const Gap(6),
        Text(label, style: TextStyle(color: active ? Colors.black87 : Colors.grey[400], fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _stepConnector() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Divider(color: Colors.grey[200], thickness: 1, indent: 8, endIndent: 8),
      ),
    );
  }

  Widget _buildSmallCodeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("MY PERSONAL CODE", style: TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const Gap(8),
          Text(code, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2)),
          const Gap(16),
          Row(
            children: [
              Expanded(child: _miniAction(Icons.copy, "Copy", Colors.black87, () => _copyToClipboard(code))),
              const Gap(10),
              Expanded(child: _miniAction(Icons.share, "Share", Colors.orange, () => _shareInvite(code))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const Gap(6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRedeem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: "Enter Code",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),
          const Gap(10),
          GestureDetector(
            onTap: _isSubmitting ? null : _redeemCode,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: _isSubmitting 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("REDEEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyDone() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Text("Bonus Claimed! ✓", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11))),
    );
  }
}
