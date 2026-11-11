import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import '../../../../core/services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  String _selectedCountryCode = "91";
  String _selectedCountryFlag = "🇮🇳";

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final phoneNum = _phoneController.text.trim();
    return AuthService.normalizePhone(phoneNum, countryCode: _selectedCountryCode);
  }

  /// Primary login flow: Mobile Number + Password (NO OTP REQUIRED)
  Future<void> _handlePasswordLogin() async {
    final phoneNum = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phoneNum.isEmpty) {
      AppToast.showError(context, "Please enter your phone number");
      return;
    }
    if (password.isEmpty) {
      AppToast.showError(context, "Please enter your password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _fullPhoneNumber;
      await ref.read(authServiceProvider).loginWithPhonePassword(phone, password);

      if (mounted) {
        setState(() => _isLoading = false);
        ref.invalidate(currentUserStreamProvider);
        context.go(AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          _showPasswordFallbackDialog(
            "Login failed. If this is your first time using password login, or you forgot your password, you can verify via OTP to set a password.",
          );
        } else {
          AppToast.showError(context, e.message ?? "Authentication failed");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, "Login error: ${e.toString()}");
      }
    }
  }

  /// Registration flow: Send OTP -> Verify -> Set Password
  void _sendOtpForRegistration() {
    final phoneNum = _phoneController.text.trim();
    if (phoneNum.isEmpty) {
      AppToast.showError(context, "Please enter a valid phone number");
      return;
    }
    _triggerOtpVerification(isRegistration: true);
  }

  /// Fallback or quick OTP login for legacy accounts
  void _triggerOtpVerification({bool isRegistration = false, bool isPasswordReset = false}) async {
    final phoneNum = _phoneController.text.trim();
    final phone = _fullPhoneNumber;
    if (phoneNum.isEmpty) {
      AppToast.showError(context, "Please enter a valid phone number");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await ref.read(authServiceProvider).signInWithCredential(credential);
          if (mounted) {
            setState(() => _isLoading = false);
            ref.invalidate(currentUserStreamProvider);
            if (isRegistration || isPasswordReset) {
              context.go(AppRoutes.setPassword, extra: {'phone': phone, 'isReset': isPasswordReset, 'canSkip': false});
            } else {
              // Existing user OTP auto-verified -> directly enter Home without interruption
              context.go(AppRoutes.home);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            AppToast.showError(context, e.message ?? "Verification failed");
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _isLoading = false);
            context.push(
              AppRoutes.otpVerify,
              extra: {
                'verificationId': verificationId,
                'phone': phone,
                'isRegistration': isRegistration,
                'isPasswordReset': isPasswordReset,
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, e.toString());
      }
    }
  }

  void _showPasswordFallbackDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Need Help Logging In?", style: TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("TRY AGAIN", style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _triggerOtpVerification(isRegistration: false);
            },
            child: const Text("LOG IN WITH OTP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isRegisterMode ? 'Register Account' : 'Login'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  child: Image.asset('assets/images/logo.webp', width: 90, height: 90),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _isRegisterMode ? "Create New Account" : "Welcome Back",
                  style: AppTextStyles.display1,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _isRegisterMode
                      ? "Register with your phone number and create a password"
                      : "Log in with your phone number and password",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Tab Switcher between Login and Register
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isRegisterMode = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isRegisterMode ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Password Login",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: !_isRegisterMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isRegisterMode = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isRegisterMode ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "New Register",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _isRegisterMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Phone Number Field
              AppTextField(
                controller: _phoneController,
                label: "Phone Number",
                hintText: 'Enter phone number',
                keyboardType: TextInputType.phone,
                prefixIcon: InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: true,
                      countryListTheme: CountryListThemeData(
                        borderRadius: BorderRadius.circular(20),
                        inputDecoration: InputDecoration(
                          hintText: 'Search country',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      onSelect: (Country country) {
                        setState(() {
                          _selectedCountryCode = country.phoneCode;
                          _selectedCountryFlag = country.flagEmoji;
                        });
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$_selectedCountryFlag +$_selectedCountryCode",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),

              // Password Field (shown on Login mode)
              if (!_isRegisterMode) ...[
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: "Password",
                  hintText: 'Enter your password',
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _triggerOtpVerification(isRegistration: false),
                      child: const Text(
                        "Login with OTP",
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "We will send a 6-digit OTP code to verify your phone, then you will set a password.",
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              AppButton(
                onPressed: _isLoading
                    ? null
                    : (_isRegisterMode ? _sendOtpForRegistration : _handlePasswordLogin),
                text: _isLoading
                    ? "PLEASE WAIT..."
                    : (_isRegisterMode ? "SEND OTP TO REGISTER" : "LOG IN"),
              ),

              const SizedBox(height: 28),
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
              const SizedBox(height: 20),

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
                          Future.microtask(() => ref.invalidate(currentUserStreamProvider));
                          if (mounted) context.go(AppRoutes.home);
                        } catch (e) {
                          if (mounted) {
                            AppToast.showError(context, "Google Login Failed: $e");
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
                          Future.microtask(() => ref.invalidate(currentUserStreamProvider));
                          if (mounted) context.go(AppRoutes.home);
                        } catch (e) {
                          if (mounted) {
                            AppToast.showError(context, "Facebook Login Failed: $e");
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.emailAuth),
                  child: const Text(
                    "Login with Email / Username",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 30),
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
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(logoAsset, size: 28, color: logoColor),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
