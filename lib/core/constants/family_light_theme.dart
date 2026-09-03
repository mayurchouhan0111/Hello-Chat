import 'package:flutter/material.dart';

/// Shared design tokens for the Family / Clan feature (Light + Royal Gold).
class FamilyLight {
  // Surfaces
  static const Color pageBg = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color fill = Color(0xFFF8FAFC);

  // Text
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);

  // Lines
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Royal gold accent
  static const Color gold = Color(0xFFD97706);
  static const Color goldDeep = Color(0xFFB45309);
  static const Color goldSoft = Color(0xFFFEF3C7);
  static const Color goldBorder = Color(0xFFFDE68A);
  static const Color premiumGold = Color(0xFFD4AF37);
  static const Color premiumDeep = Color(0xFF996515);

  // Status
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFFF1F2);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF9333EA);
  static const Color purpleSoft = Color(0xFFFAF5FF);
  static const Color cyan = Color(0xFF0284C7);
  static const Color cyanSoft = Color(0xFFF0F9FF);

  static BoxDecoration cardDeco({
    Color borderColor = border,
    double radius = 20,
  }) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
