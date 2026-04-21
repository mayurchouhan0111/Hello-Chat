import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/widgets/premium_bean.dart';
import '../../../../core/widgets/premium_diamond.dart';
import '../../../../core/constants/app_colors.dart';

class BeanExchangeScreen extends ConsumerStatefulWidget {
  const BeanExchangeScreen({super.key});

  @override
  ConsumerState<BeanExchangeScreen> createState() => _BeanExchangeScreenState();
}

class _BeanExchangeScreenState extends ConsumerState<BeanExchangeScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _convert() async {
    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText) ?? 0;
    
    if (amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Exchange minimum: 10 Beans."),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) return;

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('convertBeansToDiamonds');
      final result = await callable.call({'amount': amount});

      if (result.data['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✨ Exchange successful!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
          _amountController.clear();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Exchange Error: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addAmount(int val) {
    final current = int.tryParse(_amountController.text) ?? 0;
    _amountController.text = (current + val).toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final beans = user?.beansBalance ?? 0;
    final String amountText = _amountController.text;
    final int inputAmount = int.tryParse(amountText) ?? 0;
    final int diamondResult = inputAmount ~/ 3;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "EXCHANGE CENTER",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 3,
            shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700).withOpacity(0.03),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 3.seconds).fadeIn(duration: 3.seconds),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  
                  // AVAILABLE BEANS BANNER (Kept same structure, refined styling)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE2B05E), Color(0xFFB38B47)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const PremiumBean(size: 20),
                            const SizedBox(width: 10),
                            Text(
                              "AVAILABLE BEANS",
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$beans",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 30),

                  // EXCHANGE UI CARD
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D23),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        // From Section
                        _buildExchangeInput(
                          label: "FROM",
                          title: "Beans",
                          icon: const PremiumBean(size: 24),
                          controller: _amountController,
                          onMax: () {
                            _amountController.text = beans.toString();
                            setState(() {});
                          },
                        ),

                        // To Section
                        _buildExchangeResult(
                          label: "TO (ESTIMATED)",
                          title: "Diamonds",
                          amount: diamondResult,
                          icon: const PremiumDiamond(size: 24),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // QUICK SELECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [100, 500, 1000, 5000].map((val) => _buildQuickChip(val)).toList(),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 30),

                  // INFO TIP
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 16),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "The current exchange rate is 3:1. Conversion is irreversible once confirmed.",
                            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120), // Bottom padding for fixed button
                ],
              ),
            ),
          ),

          // Action Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading || inputAmount > beans || inputAmount < 10
                    ? null
                    : _convert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFF23272E),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text(
                        "CONVERT NOW",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
              ),
            ).animate(target: inputAmount > 0 ? 1 : 0).scale(duration: 200.ms, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeInput({
    required String label,
    required String title,
    required Widget icon,
    required TextEditingController controller,
    required VoidCallback onMax,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              GestureDetector(
                onTap: onMax,
                child: Text("USE MAX", style: TextStyle(color: const Color(0xFFFFD700).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                  cursorColor: const Color(0xFFFFD700),
                  style: const TextStyle(
                    color: Color(0xFFFFD700), 
                    fontSize: 34, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: -1,
                  ),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeResult({
    required String label,
    required String title,
    required int amount,
    required Widget icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                amount.toString(),
                style: TextStyle(
                  color: amount > 0 ? Colors.white : Colors.white12,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(int val) {
    return InkWell(
      onTap: () => _addAmount(val),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          "+$val",
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
