import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Set or Reset Password"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Security First",
              style: AppTextStyles.headline1,
            ),
            const SizedBox(height: 8),
            const Text(
              "Your new password must be different from previous used passwords.",
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            
            AppTextField(
              controller: _oldPasswordController,
              label: "Current Password (Optional if first time)",
              hintText: "Enter current password if set",
              obscureText: _obscureOld,
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility, color: AppColors.textTertiary),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
            const SizedBox(height: 20),
            
            AppTextField(
              controller: _newPasswordController,
              label: "New Password",
              hintText: "Enter new password",
              obscureText: _obscureNew,
              prefixIcon: const Icon(Icons.lock_open_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: AppColors.textTertiary),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 20),
            
            AppTextField(
              controller: _confirmPasswordController,
              label: "Confirm New Password",
              hintText: "Re-enter new password",
              obscureText: _obscureConfirm,
              prefixIcon: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppColors.textTertiary),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            
            const SizedBox(height: 48),
            AppButton(
              onPressed: () async {
                final newPass = _newPasswordController.text.trim();
                final confirmPass = _confirmPasswordController.text.trim();
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Password must be at least 6 characters long!")),
                  );
                  return;
                }
                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Passwords do not match!")),
                  );
                  return;
                }
                try {
                  await ref.read(authServiceProvider).updatePassword(newPass);
                  ref.invalidate(currentUserProfileProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
                        content: Text("Password updated successfully!"),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Failed to update password: $e")),
                    );
                  }
                }
              },
              text: "UPDATE PASSWORD",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
