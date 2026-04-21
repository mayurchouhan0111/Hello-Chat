import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Glowing Orbs
          Positioned(
            top: -50,
            right: -50,
            child: _GlowOrb(color: AppColors.primary.withOpacity(0.15), size: 300),
          ).animate().fadeIn(duration: 1200.ms).scale(begin: const Offset(0.8, 0.8)),
          
          Positioned(
            bottom: 100,
            left: -100,
            child: _GlowOrb(color: AppColors.secondary.withOpacity(0.1), size: 400),
          ).animate().fadeIn(delay: 400.ms, duration: 1500.ms),

          Positioned(
            top: 200,
            left: 50,
            child: _GlowOrb(color: AppColors.accent.withOpacity(0.05), size: 200),
          ).animate().fadeIn(delay: 800.ms, duration: 1000.ms),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glass Logo Container
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/logo.webp',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 1000.ms)
                .scale(delay: 200.ms, duration: 800.ms, curve: Curves.easeOutBack)
                .shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white24),
                
                const SizedBox(height: 48),
                
                // App Name
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.display1.copyWith(
                    letterSpacing: -1,
                    fontWeight: FontWeight.w900,
                  ),
                ).animate().fadeIn(delay: 600.ms).moveY(begin: 20, end: 0, duration: 800.ms),
                
                const SizedBox(height: 12),
                
                // Subtitle
                Text(
                  "Voice Rooms & Social Connections",
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 900.ms).moveY(begin: 10, end: 0, duration: 800.ms),
              ],
            ),
          ),
          
          // Bottom Actions
          Positioned(
            bottom: 50,
            left: 32,
            right: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Get Started Button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "GET STARTED",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1200.ms).scale(begin: const Offset(0.9, 0.9)),
                
                const SizedBox(height: 32),
                
                // Footer Links
                const Text(
                  "Privacy Policy | Terms of Service",
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 1500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.2),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
