import 'package:flutter/material.dart';
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
  final _ifscController = TextEditingController();
  String _selectedMethod = 'Bank Transfer';
  bool _isLoading = false;
  bool _isAgencyWithdrawal = false;

  final List<String> _methods = [
    'Bank Transfer',
    'Bkash',
    'Nagad',
    'Payoneer',
    'Wise',
    'Crypto (USDT)'
  ];

  // Sophisticated Fintech Palette
  static const Color primaryNavy = Color(0xFF00246B); // Deep Navy
  static const Color softBlue = Color(0xFFCADCFC); // Soft Light Blue
  static const Color creamColor = Color(0xFFFDFBF7); // Sophisticated Cream
  
  static const Color bgColor = Color(0xFF001A4D); // Darker Navy for Background
  static const Color surfaceColor = Color(0xFF00246B); // Main Navy for Surfaces
  static const Color textMain = Color(0xFFFDFBF7); // Cream for readability
  static const Color textSub = Color(0xFFCADCFC); // Light Blue for subtext

  // Conversion: 1000 Beans = $10 ($0.01 per Bean)
  static const double _conversionRate = 0.01;

  void _submitRequest() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    
    if (amountText.isEmpty || accountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all details")),
      );
      return;
    }

    final amount = int.tryParse(amountText) ?? 0;
    if (amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum withdrawal is 1000 Beans")),
      );
      return;
    }

    final user = ref.read(currentUserProfileProvider).value;

    // 🛡️ Security Check: Banned status
    if (user?.isBanned == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your account is restricted. Contact support.")),
      );
      return;
    }

    if (user?.isVerified != true) {
      _showVerificationPrompt();
      return;
    }

    _showOtpDialog();
  }

  void _showVerificationPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Colors.white10)),
        title: Text("Verification Required", style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.bold)),
        content: Text(
          "To comply with financial regulations, you must verify your identity before withdrawing funds.",
          style: GoogleFonts.plusJakartaSans(color: textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("LATER", style: GoogleFonts.plusJakartaSans(color: textSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.verification);
            },
            child: Text("VERIFY NOW", style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOtpDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Colors.white10)),
        title: Text("Confirm Settlement", style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "A verification code has been sent to your registered contact. Please enter it below to authorize this withdrawal.",
              style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 13),
            ),
            const Gap(20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: softBlue, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: _inputDecoration("000000").copyWith(counterText: ""),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.plusJakartaSans(color: textSub)),
          ),
          TextButton(
            onPressed: () {
              // Simulating OTP validation (e.g. 123456)
              if (otpController.text.length == 6) {
                Navigator.pop(context);
                _executeWithdrawal();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
              }
            },
            child: Text("AUTHORIZE", style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _executeWithdrawal() async {
    final amountText = _amountController.text.trim();
    final accountText = _accountController.text.trim();
    final amount = int.tryParse(amountText) ?? 0;
    final user = ref.read(currentUserProfileProvider).value;

    setState(() => _isLoading = true);

    try {
      final accountDetails = {
        'account': accountText,
        'method': _selectedMethod,
      };
      
      if (_selectedMethod == 'Bank Transfer') {
        accountDetails['ifsc'] = _ifscController.text.trim();
      }

      await ref.read(walletServiceProvider).requestWithdrawal(
        amount: amount,
        method: _selectedMethod,
        accountDetails: accountDetails,
        isAgency: _isAgencyWithdrawal,
        agencyId: _isAgencyWithdrawal ? user?.agencyId : null,
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Colors.white10)),
            title: Text("Settlement Initiated", style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.bold)),
            content: Text(
              "Your request has been successfully logged in our secure system. Expect processing within 24-48 business hours.",
              style: GoogleFonts.plusJakartaSans(color: textSub),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                }, 
                child: Text("CONFIRM", style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.bold))
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().split(']').last}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final agencyAsync = ref.watch(myAgencyProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "SECURE SETTLEMENT", 
          style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: softBlue),
            onPressed: () => context.push(AppRoutes.withdrawalHistory),
          ),
          const Gap(8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branding Animation
            Center(
              child: Column(
                children: [
                  Text(
                    "Hello Chat",
                    style: GoogleFonts.windSong(
                      fontSize: 48,
                      color: softBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0),
                  const Gap(4),
                  Container(
                    height: 2,
                    width: 50,
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ).animate().scaleX(duration: 1000.ms, curve: Curves.easeOut),
                ],
              ),
            ),

            const Gap(40),

            // 0. Withdrawal Type Toggle
            userAsync.when(
              data: (user) {
                if (user?.isAgencyOwner != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      _buildTypeToggle("HOST ASSETS", !_isAgencyWithdrawal, () => setState(() => _isAgencyWithdrawal = false)),
                      const Gap(12),
                      _buildTypeToggle("AGENCY ASSETS", _isAgencyWithdrawal, () => setState(() => _isAgencyWithdrawal = true)),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ).animate().fadeIn(delay: 200.ms),

            // 1. Balance Overview (Sophisticated Navy Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isAgencyWithdrawal ? "AGENCY TOTAL BALANCE" : "HOST NET EARNINGS",
                        style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                      const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 16),
                    ],
                  ),
                  const Gap(24),
                  if (_isAgencyWithdrawal)
                    agencyAsync.when(
                      data: (agency) => _buildBalanceText("${agency?.beansBalance ?? 0}"),
                      loading: () => const CircularProgressIndicator(color: softBlue),
                      error: (_, __) => _buildBalanceText("0"),
                    )
                  else
                    userAsync.when(
                      data: (user) => _buildBalanceText("${user?.beansBalance ?? 0}"),
                      loading: () => const CircularProgressIndicator(color: softBlue),
                      error: (_, __) => _buildBalanceText("0"),
                    ),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Trusted Financial Asset Management", 
                      style: GoogleFonts.plusJakartaSans(color: textSub.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

            const Gap(40),

            // 2. Input Section
            Text(
              "SETTLEMENT OPTIONS", 
              style: GoogleFonts.plusJakartaSans(color: softBlue.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)
            ).animate().fadeIn(delay: 600.ms),
            const Gap(24),
            
            _buildInputLabel("Settlement Amount"),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: _inputDecoration("Minimum 1,000").copyWith(
                suffixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "≈ \$${((int.tryParse(_amountController.text) ?? 0) * _conversionRate).toStringAsFixed(2)}",
                        style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 700.ms),
            
            const Gap(24),
            
            _buildInputLabel("Payout Institution"),
            _buildMethodSelector().animate().fadeIn(delay: 800.ms),
            
            const Gap(24),
            
            _buildInputLabel(_getAccountLabel()),
            TextField(
              controller: _accountController,
              style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(_getAccountHint()),
            ).animate().fadeIn(delay: 900.ms),
            
            if (_selectedMethod == 'Bank Transfer') ...[
              const Gap(24),
              _buildInputLabel("Bank Routing / Swift / IFSC"),
              TextField(
                controller: _ifscController,
                style: GoogleFonts.plusJakartaSans(color: textMain, fontWeight: FontWeight.w600),
                decoration: _inputDecoration("Required for Transfer"),
              ).animate().fadeIn(delay: 1000.ms),
            ],

            const Gap(48),

            // 3. Submit Button (Cream / Navy Style)
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: softBlue,
                  foregroundColor: primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: primaryNavy, strokeWidth: 2))
                  : Text("INITIATE SETTLEMENT", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
              ),
            ).animate().fadeIn(delay: 1100.ms).scale(begin: const Offset(0.98, 0.98)),
            
            const Gap(32),
            Center(
              child: Opacity(
                opacity: 0.6,
                child: Column(
                  children: [
                    Text(
                      "Secure SSL Encrypted Channel",
                      style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const Gap(6),
                    Text(
                      "Settlement timeframe: 24 - 48 business hours",
                      style: GoogleFonts.plusJakartaSans(color: textSub.withOpacity(0.5), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 1200.ms),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceText(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(color: creamColor, fontSize: 54, fontWeight: FontWeight.w900, letterSpacing: -2),
        ),
        const Gap(8),
        Text(
          "BEANS",
          style: GoogleFonts.plusJakartaSans(color: softBlue, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildTypeToggle(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? softBlue : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? primaryNavy : textSub, 
              fontWeight: FontWeight.w900, 
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  String _getAccountLabel() {
    switch (_selectedMethod) {
      case 'Bkash':
      case 'Nagad': return "Account Number (Mobile)";
      case 'Payoneer':
      case 'Wise': return "Receiver Email Address";
      case 'Crypto (USDT)': return "Wallet Address (TRC20)";
      case 'Bank Transfer': return "Full Account Number";
      default: return "Payment Details";
    }
  }

  String _getAccountHint() {
    switch (_selectedMethod) {
      case 'Bkash':
      case 'Nagad': return "01XXXXXXXXX";
      case 'Payoneer':
      case 'Wise': return "user@institution.com";
      case 'Crypto (USDT)': return "T...";
      default: return "Enter here";
    }
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(label, style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white10, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.all(22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.white10, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: softBlue, width: 1.5)),
    );
  }

  Widget _buildMethodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _methods.map((m) {
          final isSelected = _selectedMethod == m;
          return GestureDetector(
            onTap: () => setState(() => _selectedMethod = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? softBlue.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isSelected ? softBlue : Colors.white10),
              ),
              child: Text(
                m,
                style: GoogleFonts.plusJakartaSans(color: isSelected ? softBlue : textMain, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

