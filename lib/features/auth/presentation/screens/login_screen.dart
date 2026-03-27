import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _selectedCountryCode = "+91";

  final List<Map<String, String>> _countries = [
    {"code": "+91", "name": "India", "flag": "🇮🇳"},
    {"code": "+880", "name": "Bangladesh", "flag": "🇧🇩"},
  ];

  void _verifyPhone() async {
    final phoneNum = _phoneController.text.trim();
    final phone = "$_selectedCountryCode$phoneNum";
    if (phoneNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (limited support)
          await ref.read(authServiceProvider).signInWithCredential(credential);
          ref.invalidate(currentUserStreamProvider);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "Verification failed")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          context.push(
            AppRoutes.otpVerify,
            extra: {'verificationId': verificationId, 'phone': phone},
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
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
                  child: Image.asset('assets/images/logo.png', width: 100, height: 100),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Welcome to Hello Chat",
                style: AppTextStyles.display1,
              ),
              const SizedBox(height: 8),
              const Text(
                "Log in or sign up to continue your journey",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _phoneController,
                label: "Phone Number",
                hintText: 'Enter your phone number',
                keyboardType: TextInputType.phone,
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCountryCode = newValue;
                          });
                        }
                      },
                      items: _countries.map<DropdownMenuItem<String>>((Map<String, String> country) {
                        return DropdownMenuItem<String>(
                          value: country["code"],
                          child: Text(
                            "${country["flag"]} ${country["code"]}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.emailAuth),
                  child: const Text("Login with ID and Pass", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                onPressed: _isLoading ? null : _verifyPhone,
                text: _isLoading ? "SENDING..." : "CONTINUE",
              ),
              
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("OR", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 32),
              
              // Social Logins Side-by-Side
              Row(
                children: [
                  Expanded(
                    child: _SocialLoginButton(
                      logoAsset: Icons.g_mobiledata_rounded,
                      logoColor: Colors.black,
                      label: "Google",
                      onPressed: () async {
                        try {
                          await ref.read(authServiceProvider).signInWithGoogle();
                          ref.invalidate(currentUserStreamProvider);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Google Login Failed")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SocialLoginButton(
                      logoAsset: Icons.facebook_rounded,
                      logoColor: const Color(0xFF1877F2),
                      label: "Facebook",
                      onPressed: () async {
                        try {
                          await ref.read(authServiceProvider).signInWithFacebook();
                          ref.invalidate(currentUserStreamProvider);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Facebook Login Failed")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 100),
              const Center(
                child: Text(
                  "By continuing, you agree to our Terms & Conditions",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final IconData logoAsset;
  final Color logoColor;
  final String label;
  final VoidCallback onPressed;

  const _SocialLoginButton({
    required this.logoAsset,
    required this.logoColor,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: logoColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(logoAsset, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
