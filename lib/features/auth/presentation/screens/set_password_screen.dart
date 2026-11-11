import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../providers/user_provider.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  final String? phone;
  final bool isReset;
  final bool canSkip;

  const SetPasswordScreen({
    super.key,
    this.phone,
    this.isReset = false,
    this.canSkip = false,
  });

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSavePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      AppToast.showError(context, "Please fill in all fields");
      return;
    }

    if (password.length < 6) {
      AppToast.showError(context, "Password must be at least 6 characters long");
      return;
    }

    if (password != confirm) {
      AppToast.showError(context, "Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = widget.phone ?? FirebaseAuth.instance.currentUser?.phoneNumber;
      await ref.read(authServiceProvider).setupPasswordForUser(password, phone: phone);

      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showSuccess(
          context,
          widget.isReset
              ? "Password reset successfully! You can now log in with your phone and password."
              : "Password created successfully!",
        );
        ref.invalidate(currentUserStreamProvider);
        ref.invalidate(currentUserProfileProvider);

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
            context.go(AppRoutes.profileSetup);
          } else {
            context.go(AppRoutes.home);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, "Failed to save password: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isReset ? "Reset Password" : "Create Password"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.18),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 46,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                widget.isReset ? "Set New Password" : "Secure Your Account",
                style: AppTextStyles.display1,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isReset
                    ? "Choose a new strong password to log in without needing OTP every time."
                    : (widget.canSkip
                        ? "Welcome back! Create a password for your existing account so you can log in easily in the future without OTP."
                        : "Create a password for your account so you can log in easily in the future without OTP."),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),

              AppTextField(
                controller: _passwordController,
                label: "New Password",
                hintText: "Enter at least 6 characters",
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 18),

              AppTextField(
                controller: _confirmPasswordController,
                label: "Confirm Password",
                hintText: "Re-enter your password",
                obscureText: _obscureConfirm,
                prefixIcon: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 12),

              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppColors.textTertiary),
                  SizedBox(width: 6),
                  Text(
                    "Passwords are encrypted securely in Firebase Auth.",
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              AppButton(
                onPressed: _isLoading ? null : _handleSavePassword,
                text: _isLoading
                    ? "SAVING..."
                    : (widget.isReset ? "UPDATE & CONTINUE" : "CREATE PASSWORD & CONTINUE"),
              ),
              if (widget.canSkip) ...[
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
                        context.go(AppRoutes.profileSetup);
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                    child: const Text(
                      "Skip for Now (I'll set it later in Settings)",
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

