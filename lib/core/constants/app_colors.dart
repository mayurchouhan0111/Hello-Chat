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
}
