import 'package:flutter/material.dart';

class AppColors {
  // Primary Light Theme
  static const Color background       = Color(0xFFF0F9FF); // Light Sky Blue
  static const Color surface          = Color(0xFFFFFFFF); // Pure White for Cards
  static const Color surfaceLight     = Color(0xFFF8FAFC); 
  
  // Brand Colors (Gradients)
  static const Color primary          = Color(0xFF8E54E9); // Vibrant Purple
  static const Color secondary        = Color(0xFF4776E6); // Deep Blue
  static const Color accent           = Color(0xFFFF4B91); // Hot Pink
  
  // Status Colors
  static const Color success          = Color(0xFF10B981);
  static const Color warning          = Color(0xFFF59E0B);
  static const Color error            = Color(0xFFEF4444);
  static const Color info             = Color(0xFF3B82F6);

  // Text Colors
  static const Color textPrimary      = Color(0xFF111827); // Deep Dark
  static const Color textSecondary    = Color(0xFF4B5563); // Cool Grey
  static const Color textTertiary     = Color(0xFF9CA3AF); // Light Grey
  
  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF8E54E9),
    Color(0xFF4776E6),
  ];
  
  static const List<Color> accentGradient = [
    Color(0xFFFF4B91),
    Color(0xFF7828C8),
  ];

  static const List<Color> surfaceGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF0F9FF),
  ];

  // Specific Card Gradients
  static const List<Color> livePurpleGradient = [
    Color(0xFF6B21A8), // Purple 700
    Color(0xFFD946EF), // Fuchsia 500
  ];

  static const List<Color> liveBlueGradient = [
    Color(0xFF0891B2), // Cyan 600
    Color(0xFF3B82F6), // Blue 500
  ];

  static const List<Color> liveOrangeGradient = [
    Color(0xFFD97706), // Amber 600
    Color(0xFFEA580C), // Orange 600
  ];

  // Diamond/Currency (Standardized to Yellow/Gold)
  static const Color diamond = Color(0xFFFFD700); // Bright Yellow/Gold
  static const Color beans   = Color(0xFFFFD700); // Gold
  static const Color cyanAccent = Color(0xFFFFD700); // Legacy map to Yellow

  // Explore Card Colors
  static const Color contributionCard = Color(0xFFFFF1E6);
  static const Color charmCard = Color(0xFFE0E7FF);
  static const Color roomCard = Color(0xFFE0F2FE);

  // Divider
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);

  // Family Dark Theme
  static const Color familyBg = Color(0xFF141414);
  static const Color familySurface = Color(0xFF1E1E1E);
  static const Color familyCard = Color(0xFF252525);
  static const Color familyGold = Color(0xFFD4A843);
  static const Color familyGoldLight = Color(0xFFFACC15);
  static const Color familyRed = Color(0xFFE53935);
  static const Color familyText = Color(0xFFFFFFFF);
  static const Color familyTextSecondary = Color(0xFFB0B0B0);

  // Family Level Themes
  static const List<Color> familyThemeAPrimary = [Color(0xFFCD7F32), Color(0xFFB8860B)]; // Bronze
  static const List<Color> familyThemeBPrimary = [Color(0xFF6B7280), Color(0xFF9CA3AF)]; // Silver
  static const List<Color> familyThemeCPrimary = [Color(0xFFD4A843), Color(0xFFF59E0B)]; // Gold
  static const List<Color> familyThemeDPrimary = [Color(0xFFDC2626), Color(0xFFD4A843)]; // Red-Gold

  static const List<Color> familyThemeAAccent = [Color(0xFF92400E), Color(0xFFB45309)];
  static const List<Color> familyThemeBAccent = [Color(0xFF374151), Color(0xFF4B5563)];
  static const List<Color> familyThemeCAccent = [Color(0xFFB8860B), Color(0xFFD97706)];
  static const List<Color> familyThemeDAccent = [Color(0xFF991B1B), Color(0xFF7C2D12)];

  static const Color familyThemeABadge = Color(0xFFCD7F32);
  static const Color familyThemeBBadge = Color(0xFF6B7280);
  static const Color familyThemeCBadge = Color(0xFFD4A843);
  static const Color familyThemeDBadge = Color(0xFFDC2626);
}
