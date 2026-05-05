import 'package:flutter/material.dart';

class LevelUtils {
  /// Returns the color assigned to a specific level (1-100)
  static Color getLevelColor(int level) {
    if (level <= 10) return const Color(0xFFCD7F32); // Bronze
    if (level <= 20) return const Color(0xFFB0BEC5); // Silver
    if (level <= 30) return const Color(0xFFFFD700); // Gold
    if (level <= 40) return const Color(0xFF00E5FF); // Cyan/Platinum
    if (level <= 50) return const Color(0xFF4DB6AC); // Teal
    if (level <= 60) return const Color(0xFF9C27B0); // Purple
    if (level <= 70) return const Color(0xFFFF4081); // Pink
    if (level <= 80) return const Color(0xFFFF5252); // Red
    if (level <= 90) return const Color(0xFF263238); // Obsidian/Dark
    return const Color(0xFFF58A4C); // Hello Chat Signature Orange (Level 91-100)
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
    if (currentLevel <= 0) return 100;
    if (currentLevel < 10) return 10000;
    if (currentLevel < 20) return 25000;
    if (currentLevel < 30) return 50000;
    if (currentLevel < 40) return 100000;
    if (currentLevel < 50) return 200000;
    if (currentLevel < 60) return 300000;
    if (currentLevel < 70) return 400000;
    if (currentLevel < 80) return 500000;
    if (currentLevel < 90) return 600000;
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
    if (level >= 80) return 5;
    if (level >= 50) return 4;
    if (level >= 30) return 3;
    if (level >= 20) return 2;
    if (level >= 10) return 1;
    return 0;
  }

  static String _format(int val) {
    if (val >= 1000) {
      return "${(val / 1000).toStringAsFixed(1)}K";
    }
    return val.toString();
  }
}
