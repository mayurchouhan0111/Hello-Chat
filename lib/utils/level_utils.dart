import 'package:flutter/material.dart';

class LevelUtils {
  /// Returns the color assigned to a specific level (1-100)
  static Color getLevelColor(int level) {
    if (level <= 9) return const Color(0xFFB0BEC5); // Silver
    if (level <= 19) return const Color(0xFF4DB6AC); // Teal/Green
    if (level <= 29) return const Color(0xFFFFD700); // Gold
    if (level <= 39) return const Color(0xFFFF4081); // Pink
    if (level <= 49) return const Color(0xFF00E5FF); // Cyan
    if (level <= 59) return const Color(0xFF4CAF50); // Green
    if (level <= 69) return const Color(0xFF2196F3); // Blue
    if (level <= 79) return const Color(0xFF9C27B0); // Purple
    if (level <= 89) return const Color(0xFFFF9800); // Orange
    if (level <= 99) return const Color(0xFFF44336); // Red
    if (level == 100) return const Color(0xFF212121); // Obsidian/Gold
    return const Color(0xFFF58A4C);
  }

  /// Returns total XP required to reach a specific level
  /// Level 1-50: Easy (Linear growth)
  /// Level 51-100: Hard (Exponential growth)
  static int getTotalXPForLevel(int level) {
    if (level <= 1) return 0;
    if (level > 100) level = 100;

    int total = 0;
    for (int i = 1; i < level; i++) {
      total += getXPRequiredForNextLevel(i);
    }
    return total;
  }

  /// Returns XP required to go from [currentLevel] to [currentLevel + 1]
  static int getXPRequiredForNextLevel(int currentLevel) {
    if (currentLevel < 10) return 10000;
    if (currentLevel < 20) return 25000;
    if (currentLevel < 30) return 50000;
    if (currentLevel < 40) return 100000;
    if (currentLevel < 50) return 200000;
    if (currentLevel < 60) return 300000;
    if (currentLevel < 70) return 400000;
    if (currentLevel < 80) return 500000;
    if (currentLevel < 90) return 600000;
    if (currentLevel < 100) return 1000000;
    return 1000000;
  }

  /// Calculates current level based on total XP
  static int calculateLevel(int totalXP) {
    int level = 1;
    int xpRemaining = totalXP;

    while (level < 100) {
      int needed = getXPRequiredForNextLevel(level);
      if (xpRemaining >= needed) {
        xpRemaining -= needed;
        level++;
      } else {
        break;
      }
    }
    return level;
  }

  /// Returns a value between 0.0 and 1.0 representing progress toward next level
  static double getLevelProgress(int totalXP) {
    int currentLevel = calculateLevel(totalXP);
    if (currentLevel >= 100) return 1.0;

    int xpAtStartOfLevel = getTotalXPForLevel(currentLevel);
    int xpInCurrentLevel = totalXP - xpAtStartOfLevel;
    int xpNeededForNext = getXPRequiredForNextLevel(currentLevel);

    return (xpInCurrentLevel / xpNeededForNext).clamp(0.0, 1.0);
  }

  /// Returns string like "1,200 / 5,000"
  static String getXPProgressText(int totalXP) {
    int currentLevel = calculateLevel(totalXP);
    if (currentLevel >= 100) return "MAX LEVEL";

    int xpAtStartOfLevel = getTotalXPForLevel(currentLevel);
    int xpInCurrentLevel = totalXP - xpAtStartOfLevel;
    int xpNeededForNext = getXPRequiredForNextLevel(currentLevel);

    return "${_format(xpInCurrentLevel)} / ${_format(xpNeededForNext)} XP";
  }

  static int getLevelBadgeIndex(int level) {
    if (level <= 9) return 0;
    if (level <= 19) return 1;
    if (level <= 29) return 2;
    if (level <= 39) return 3;
    if (level <= 49) return 4;
    if (level <= 59) return 5;
    if (level <= 69) return 6;
    if (level <= 79) return 7;
    if (level <= 89) return 8;
    if (level <= 99) return 9;
    if (level == 100) return 10;
    return 10;
  }

  /// Returns full asset path for the level frame/badge
  /// Use this method EVERYWHERE level frames are displayed - single source of truth
  static String getLevelFrameAsset(int level) {
    int index = getLevelBadgeIndex(level);
    return "assets/images/levels_new/level_badge_$index.webp";
  }

  /// Returns the frame color for a level (used for gradients/glows)
  static Color getLevelFrameColor(int level) {
    return getLevelColor(level);
  }

  /// Returns frame size multiplier for avatar framing
  static double getLevelFrameMultiplier(int level) {
    if (level <= 9) return 1.6;
    if (level <= 29) return 1.65;
    if (level <= 49) return 1.7;
    if (level <= 69) return 1.75;
    if (level <= 89) return 1.8;
    return 1.85;
  }

  static String _format(int val) {
    if (val >= 1000) {
      return "${(val / 1000).toStringAsFixed(1)}K";
    }
    return val.toString();
  }
}
