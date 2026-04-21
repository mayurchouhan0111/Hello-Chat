import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    final identifier = _emailController.text.trim();

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email or phone number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Check if it's a phone number
    if (RegExp(r'^\+?[0-9]{7,15}$').hasMatch(identifier)) {
      final phone = identifier.startsWith('+') ? identifier : "+$identifier";
      _showPhoneResetOTP(phone);
    } else {
      // Standard Email Reset
      try {
        await ref.read(authServiceProvider).sendPasswordResetEmail(identifier);
        
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password reset email sent! Please check your inbox.")),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception:", ""))),
        );
      }
    }
  }

  void _showPhoneResetOTP(String phone) async {
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Failed")));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          _showOTPInputDialog(verificationId, phone);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showOTPInputDialog(String verificationId, String phone) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Verify Phone"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter the 6-digit code sent to $phone"),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Enter OTP"),
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final pin = otpController.text.trim();
              if (pin.length != 6) return;
              
              Navigator.pop(context); // Close OTP Dialog
              setState(() => _isLoading = true);
              
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: pin,
                );
                await ref.read(authServiceProvider).signInWithCredential(credential);
                _showNewPasswordDialog();
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid OTP")));
              }
            },
            child: const Text("VERIFY"),
          ),
        ],
      ),
    );
  }

  void _showNewPasswordDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Set New Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your new password below."),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "New Password"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final pass = passController.text.trim();
              if (pass.length < 6) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Too short")));
                 return;
              }
              
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                await ref.read(authServiceProvider).updatePassword(pass);
                // Also update the pseudo-email if we want to be thorough, but usually 
                // just updating current password works if the accounts are linked.
                // For unlinked accounts, we might need a custom backend.
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
                  context.go('/login');
                }
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text("SAVE PASSWORD"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forgot Password"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/images/logo.webp', width: 100, height: 100),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Reset Password",
                style: AppTextStyles.display1,
              ),
              const SizedBox(height: 12),
              const Text(
                "Enter your email or phone number and we will send you a link or OTP to reset your password.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _emailController,
                label: "Email or Phone Number",
                hintText: "example@email.com or +91...",
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 48),
              AppButton(
                onPressed: _isLoading ? null : _handleReset,
                text: _isLoading ? "SENDING..." : "RESET PASSWORD",
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
