import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/router/app_router.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter identifier and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    String finalIdentifier = identifier;
    // Check if it's a phone number (start with + or is all digits)
    if (RegExp(r'^\+?[0-9]{7,15}$').hasMatch(identifier)) {
      // Normalize phone number to pseudo-email
      finalIdentifier = identifier.startsWith('+') 
          ? "$identifier@phone.hellochat.app" 
          : "+$identifier@phone.hellochat.app";
    }

    try {
      // Logic: Try to login first, if user not found, try to register
      try {
        await ref.read(authServiceProvider).loginWithEmail(finalIdentifier, password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
          // If login fails because user doesn't exist, try to register
          await ref.read(authServiceProvider).registerWithEmail(finalIdentifier, password);
        } else {
          rethrow;
        }
      }
      
      if (mounted) {
        ref.invalidate(currentUserStreamProvider);
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception:", ""))),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Login / Register'),
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
              const SizedBox(height: 24),
              const Text(
                "Login with Password",
                style: AppTextStyles.display1,
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your email or phone number and password to continue",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              AppTextField(
                controller: _emailController,
                label: "Email or Phone Number",
                hintText: 'example@gmail.com or +91...',
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                controller: _passwordController,
                label: "Password",
                hintText: 'Enter your password',
                obscureText: true,
              ),
              
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  child: const Text("Forgot Password?"),
                ),
              ),
              
              const SizedBox(height: 24),
              AppButton(
                onPressed: _isLoading ? null : _handleAuth,
                text: _isLoading ? "PLEASE WAIT..." : "CONTINUE",
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
