import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/wallet_service.dart';
import 'package:hello_chat/core/providers/agency_provider.dart';

class WithdrawBeansScreen extends ConsumerStatefulWidget {
  const WithdrawBeansScreen({super.key});

  @override
  ConsumerState<WithdrawBeansScreen> createState() => _WithdrawBeansScreenState();
}

class _WithdrawBeansScreenState extends ConsumerState<WithdrawBeansScreen> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _ifscController = TextEditingController();
  
  String _selectedMethod = 'Bank Transfer';
  bool _isLoading = false;
  bool _isAgencyWithdrawal = false;

  // Preset quick chips
  final List<int> _presetAmounts = [1000, 5000, 10000, 50000];

  final List<Map<String, dynamic>> _methodsData = [
    {
      'id': 'Bank Transfer',
      'name': 'Bank Wire',
      'sub': 'SWIFT / IFSC / Wire',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF2563EB),
      'badge': 'Verified Direct',
    },
    {
      'id': 'Bkash',
      'name': 'bKash',
      'sub': 'Mobile Wallet',
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFFE11D48),
      'badge': 'Instant Payout',
    },
    {
      'id': 'Nagad',
      'name': 'Nagad',
      'sub': 'Digital Wallet',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFFEA580C),
      'badge': 'Fast Transfer',
    },
    {
      'id': 'Payoneer',
      'name': 'Payoneer',
      'sub': 'Global USD Account',
      'icon': Icons.language_rounded,
      'color': const Color(0xFFE11D48),
      'badge': 'Global Wire',
    },
    {
      'id': 'Wise',
      'name': 'Wise',
      'sub': 'Multi-Currency',
      'icon': Icons.currency_exchange_rounded,
      'color': const Color(0xFF059669),
      'badge': 'Lowest Fee',
    },
    {
      'id': 'Crypto (USDT)',
      'name': 'USDT TRC20',
      'sub': 'Blockchain Payout',
      'icon': Icons.token_rounded,
      'color': const Color(0xFF0891B2),
      'badge': 'Decentralized',
    },
  ];

  // Conversion: 1000 Beans = $10 ($0.01 per Bean)
  static const double _conversionRate = 0.01;

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _accountHolderController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  int _getCurrentBalance() {
    if (_isAgencyWithdrawal) {
      return ref.read(myAgencyProvider).value?.beansBalance ?? 0;
    }
    return ref.read(currentUserProfileProvider).value?.beansBalance ?? 0;
  }

  void _onQuickSelect(int amount) {
    HapticFeedback.selectionClick();
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  void _onSelectMax() {
    HapticFeedback.mediumImpact();
    final bal = _getCurrentBalance();
    setState(() {
      _amountController.text = bal.toString();
    });
  }

  Future<void> _pasteToAccountField() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _accountController.text = data.text!.trim();
      });
      _showCuteNotification("Pasted from clipboard! 📋");
    }
  }

  void _submitRequest() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    
    if (amountText.isEmpty || accountText.isEmpty) {
      _showCuteNotification("Please fill in all settlement fields ✍️", isError: true);
      return;
    }

    final amount = int.tryParse(amountText) ?? 0;
    if (amount < 1000) {
      _showCuteNotification("Minimum settlement threshold is 1,000 Beans 🌱", isError: true);
      return;
    }

    final currentBal = _getCurrentBalance();
    if (amount > currentBal) {
      _showCuteNotification("Amount exceeds available balance ($currentBal Beans) ⚠️", isError: true);
      return;
    }

    if (_selectedMethod == 'Bank Transfer' && _ifscController.text.trim().isEmpty) {
      _showCuteNotification("Please provide Bank Routing / IFSC / SWIFT code 🏦", isError: true);
      return;
    }

    final user = ref.read(currentUserProfileProvider).value;

    if (user?.isBanned == true) {
      _showCuteNotification("Your account is currently restricted. Please contact support.", isError: true);
      return;
    }

    if (user?.isVerified != true) {
      _showVerificationPrompt();
      return;
    }

    _showOtpBottomSheet();
  }

  void _showCuteNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const Gap(10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showVerificationPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Gap(24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 36),
            ),
            const Gap(16),
            Text(
              "KYC Verification Required",
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            const Gap(8),
            Text(
              "To protect your earnings and comply with financial standards, please verify your identity before processing your first settlement.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.5),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text("Later", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.verification);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text("Verify Account ✨", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  void _showOtpBottomSheet() {
    final otpController = TextEditingController();
    final enteredBeans = int.tryParse(_amountController.text) ?? 0;
    final convertedUsd = enteredBeans * _conversionRate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Gap(20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF16A34A), size: 32),
              ),
              const Gap(14),
              Text(
                "Authorize Settlement",
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const Gap(6),
              Text(
                "Confirm payout of ${enteredBeans.toString()} Beans (\$$convertedUsd USD) to $_selectedMethod.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
              ),
              const Gap(20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  hintText: "••••••",
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFCBD5E1), letterSpacing: 10),
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                ),
              ),
              const Gap(20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (otpController.text.length == 6) {
                      Navigator.pop(ctx);
                      _processWithdrawal();
                    } else {
                      _showCuteNotification("Please enter 6-digit security code", isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text("Confirm & Transfer 🚀", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processWithdrawal() async {
    setState(() => _isLoading = true);
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    final amount = int.tryParse(amountText) ?? 0;
    final user = ref.read(currentUserProfileProvider).value;

    try {
      final accountDetails = {
        'account': accountText,
        'method': _selectedMethod,
      };
      
      if (_selectedMethod == 'Bank Transfer') {
        accountDetails['ifsc'] = _ifscController.text.trim();
        if (_accountHolderController.text.trim().isNotEmpty) {
          accountDetails['accountHolder'] = _accountHolderController.text.trim();
        }
      }

      await ref.read(walletServiceProvider).requestWithdrawal(
        amount: amount,
        method: _selectedMethod,
        accountDetails: accountDetails,
        isAgency: _isAgencyWithdrawal,
        agencyId: _isAgencyWithdrawal ? user?.agencyId : null,
      );
      
      if (mounted) {
        _showSuccessDialog(amount);
      }
    } catch (e) {
      if (mounted) {
        _showCuteNotification("Settlement failed: ${e.toString().split(']').last.trim()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const Gap(18),
            Text(
              "Settlement Initiated! 🎉",
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const Gap(8),
            Text(
              "Your request for $amount Beans (\$${(amount * _conversionRate).toStringAsFixed(2)} USD) has been submitted to automated clearance.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF0284C7)),
                  const Gap(6),
                  Text("Est. Delivery: 24 - 48 Hours", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text("Done", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final agencyAsync = ref.watch(myAgencyProvider);

    final enteredBeans = int.tryParse(_amountController.text) ?? 0;
    final convertedUsd = enteredBeans * _conversionRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "SECURE SETTLEMENT",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 16),
                  const Gap(4),
                  Text(
                    "History",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF0284C7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            tooltip: "Settlement History",
            onPressed: () => context.push(AppRoutes.withdrawalHistory),
          ),
          const Gap(8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. Host vs Agency Asset Toggle
            userAsync.when(
              data: (user) {
                if (user?.isAgencyOwner != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildAssetTabItem(
                          label: "👑 Host Earnings",
                          isSelected: !_isAgencyWithdrawal,
                          onTap: () => setState(() => _isAgencyWithdrawal = false),
                        ),
                        _buildAssetTabItem(
                          label: "🏢 Agency Vault",
                          isSelected: _isAgencyWithdrawal,
                          onTap: () => setState(() => _isAgencyWithdrawal = true),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // 1. Hero Balance Card (Luxurious Obsidian & Cyan Glow)
            RepaintBoundary(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0B132B),
                      Color(0xFF1C2541),
                      Color(0xFF0A0E1A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                              ),
                              const Gap(6),
                              Text(
                                _isAgencyWithdrawal ? "AGENCY REVENUE" : "HOST NET EARNINGS",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFE2E8F0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_rounded, color: Color(0xFF34D399), size: 12),
                              const Gap(4),
                              Text("256-Bit SSL", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),

                    // Balance Numbers
                    if (_isAgencyWithdrawal)
                      agencyAsync.when(
                        data: (agency) => _buildHeroBalance(agency?.beansBalance ?? 0),
                        loading: () => const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        error: (_, __) => _buildHeroBalance(0),
                      )
                    else
                      userAsync.when(
                        data: (user) => _buildHeroBalance(user?.beansBalance ?? 0),
                        loading: () => const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        error: (_, __) => _buildHeroBalance(0),
                      ),

                    const Gap(16),

                    // Conversion Rate Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 14),
                          const Gap(6),
                          Flexible(
                            child: Text(
                              "1,000 Beans = \$10.00 USD  •  Fee: 0% Free",
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),

            const Gap(20),

            // 2. Settlement Amount Input Card
            _buildSectionHeader("SETTLEMENT AMOUNT", Icons.payments_outlined),
            const Gap(8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Amount in Beans",
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      GestureDetector(
                        onTap: _onSelectMax,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "USE MAX",
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 22),
                    decoration: InputDecoration(
                      hintText: "Min. 1,000",
                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 16),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 10, left: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      suffixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_money_rounded, color: Color(0xFF16A34A), size: 15),
                            Text(
                              convertedUsd.toStringAsFixed(2),
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                    ),
                  ),

                  const Gap(12),

                  // Quick Preset Chips Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _presetAmounts.map((amt) {
                      final isSelected = enteredBeans == amt;
                      return GestureDetector(
                        onTap: () => _onQuickSelect(amt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            "+${amt >= 1000 ? '${(amt / 1000).toInt()}k' : amt} (\$${(amt * _conversionRate).toInt()})",
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const Gap(20),

            // 3. Payment Gateway Selection
            _buildSectionHeader("PAYOUT GATEWAY", Icons.account_balance_wallet_outlined),
            const Gap(8),

            _buildModernPaymentMethodGrid(),

            const Gap(20),

            // 4. Beneficiary Information Card
            _buildSectionHeader("BENEFICIARY ACCOUNT", Icons.person_outline_rounded),
            const Gap(8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedMethod == 'Bank Transfer') ...[
                    Text("Account Holder Name", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700)),
                    const Gap(6),
                    TextField(
                      controller: _accountHolderController,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 14),
                      decoration: _modernInputDecoration("Legal account name as in bank", Icons.person_rounded),
                    ),
                    const Gap(14),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_getAccountLabel(), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700)),
                      GestureDetector(
                        onTap: _pasteToAccountField,
                        child: Row(
                          children: [
                            const Icon(Icons.content_paste_rounded, size: 13, color: Color(0xFF0284C7)),
                            const Gap(3),
                            Text("Paste", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  TextField(
                    controller: _accountController,
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 14),
                    decoration: _modernInputDecoration(_getAccountHint(), _getMethodIcon()),
                  ),

                  if (_selectedMethod == 'Bank Transfer') ...[
                    const Gap(14),
                    Text("Bank Routing / SWIFT / IFSC Code", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700)),
                    const Gap(6),
                    TextField(
                      controller: _ifscController,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 14),
                      decoration: _modernInputDecoration("e.g. SBIN0001234 / SWIFT Code", Icons.pin_outlined),
                    ),
                  ],
                ],
              ),
            ),

            const Gap(20),

            // 5. Mini Settlement Summary Receipt Box
            if (enteredBeans >= 1000) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow("Settlement Request", "$enteredBeans Beans"),
                    const Gap(6),
                    _buildSummaryRow("Payout Gateway", _selectedMethod),
                    const Gap(6),
                    _buildSummaryRow("Processing Fee", "\$0.00 (100% Free)"),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Net Payout to Receive", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(
                          "\$${convertedUsd.toStringAsFixed(2)} USD",
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF16A34A), fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms),
              const Gap(20),
            ],

            // 6. Action Button
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 17),
                          const Gap(8),
                          Text(
                            "CONFIRM & SETTLE PAYOUT",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.6),
                          ),
                        ],
                      ),
              ),
            ),

            const Gap(16),

            // 7. Security Trust Assurance
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                    const Gap(6),
                    Text("Automated Bank-Grade Security • 24-48 Hours Clearance", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF0284C7)),
        const Gap(6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBalance(int balance) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  balance.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const Gap(8),
            Text(
              "BEANS",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF38BDF8),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          "≈ \$${(balance * _conversionRate).toStringAsFixed(2)} USD Available for Payout",
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAssetTabItem({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPaymentMethodGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _methodsData.map((m) {
          final isSelected = _selectedMethod == m['id'];
          final Color color = m['color'] as Color;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedMethod = m['id']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 10),
              width: 136,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(color: color.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3)),
                      ]
                    : [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(m['icon'] as IconData, color: color, size: 18),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 9),
                        ),
                    ],
                  ),
                  const Gap(10),
                  Text(
                    m['name'],
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(2),
                  Text(
                    m['sub'],
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getMethodIcon() {
    switch (_selectedMethod) {
      case 'Bkash':
      case 'Nagad':
        return Icons.phone_android_rounded;
      case 'Payoneer':
      case 'Wise':
        return Icons.alternate_email_rounded;
      case 'Crypto (USDT)':
        return Icons.qr_code_2_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  String _getAccountLabel() {
    switch (_selectedMethod) {
      case 'Bkash':
      case 'Nagad':
        return "bKash / Nagad Mobile Number";
      case 'Payoneer':
      case 'Wise':
        return "Registered Account Email Address";
      case 'Crypto (USDT)':
        return "USDT TRC20 Wallet Address";
      case 'Bank Transfer':
        return "Bank Account Number / IBAN";
      default:
        return "Payment Account Details";
    }
  }

  String _getAccountHint() {
    switch (_selectedMethod) {
      case 'Bkash':
      case 'Nagad':
        return "e.g. 017XXXXXXXX";
      case 'Payoneer':
      case 'Wise':
        return "e.g. yourname@domain.com";
      case 'Crypto (USDT)':
        return "Paste TRC20 address (starts with T...)";
      default:
        return "Enter full account number";
    }
  }

  InputDecoration _modernInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
    );
  }
}
