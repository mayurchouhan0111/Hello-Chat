import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'PlusJakartaSans';

  // Display
  static const TextStyle display1 = TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);
  static const TextStyle display2 = TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3);

  // Headlines
  static const TextStyle headline1 = TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2);
  static const TextStyle headline2 = TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle headline3 = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Body
  static const TextStyle bodyLarge   = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5);
  static const TextStyle bodyMedium  = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5);
  static const TextStyle bodySmall   = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4);

  // Labels
  static const TextStyle labelLarge  = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle labelMedium = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const TextStyle labelSmall  = TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary, letterSpacing: 0.3);

  // Button
  static const TextStyle buttonLarge  = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle buttonMedium = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white);
  static const TextStyle buttonSmall  = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white);
}
