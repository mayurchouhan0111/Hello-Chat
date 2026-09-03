// Hello Chat — Auth — Presentation Layer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phone;
  const OtpScreen({super.key, required this.verificationId, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;

  void _verifyOtp(String pin) async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: pin,
      );
      // 🚀 Step 1: Perform the sign-in with a 15-second timeout safety
      await ref.read(authServiceProvider).signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      
      // 🚀 Step 2: Clear loading immediately on success
      if (mounted) setState(() => _isLoading = false);
      
      // 🚀 Step 3: Background clean up
      Future.microtask(() => ref.invalidate(currentUserStreamProvider));
      
      // 🚀 Step 4: Safety Jump (If router is slow, we move manually)
      if (mounted) {
        debugPrint('--- [OTP SUCCESS: Moving to Home] ---');
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, "Verification Failed: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: AppTextStyles.headline1.copyWith(color: AppColors.textPrimary),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text(
                  AppStrings.otpVerifyTitle,
                  style: AppTextStyles.display1,
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent a 6-digit code to ${widget.phone}. Please enter it below to verify.",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),

                const SizedBox(height: 48),
                
                Center(
                  child: Pinput(
                    controller: _pinController,
                    length: 6, 
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    showCursor: true,
                    onCompleted: (pin) => _verifyOtp(pin),
                  ),
                ),
                
                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text("Resend Code", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 100),
                AppButton(
                  onPressed: _isLoading ? null : () => _verifyOtp(_pinController.text),
                  text: _isLoading ? "VERIFYING..." : AppStrings.verifyButton,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
