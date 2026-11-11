import 'package:flutter/material.dart';

enum RoomThemeCategory { normal, luxury, official }

class RoomTheme {
  final String id;
  final String name;
  final RoomThemeCategory category;
  final List<Color> gradient;
  final String? assetPath;
  final String? imageUrl;
  final String previewImage;
  final bool isLuxury;
  final String? badge;

  const RoomTheme({
    required this.id,
    required this.name,
    required this.category,
    required this.gradient,
    this.assetPath,
    this.imageUrl,
    required this.previewImage,
    this.isLuxury = false,
    this.badge,
  });
}

class RoomThemeCatalog {
  static const List<RoomTheme> normalThemes = [
    RoomTheme(
      id: 'classic_purple',
      name: 'Classic Purple',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF2E0854), Color(0xFF130325)],
      assetPath: 'assets/images/theme_classic_purple.jpg',
      previewImage: 'assets/images/theme_classic_purple.jpg',
    ),
    RoomTheme(
      id: 'midnight_blue',
      name: 'Midnight Blue',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0F172A), Color(0xFF020617)],
      assetPath: 'assets/images/theme_midnight_blue.jpg',
      previewImage: 'assets/images/theme_midnight_blue.jpg',
    ),
    RoomTheme(
      id: 'neon_cyber',
      name: 'Cyber Neon',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF311042), Color(0xFF0B192C)],
      assetPath: 'assets/images/theme_cyber_neon.jpg',
      previewImage: 'assets/images/theme_cyber_neon.jpg',
    ),
    RoomTheme(
      id: 'sunset_glow',
      name: 'Sunset Glow',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF431407), Color(0xFF180A04)],
      assetPath: 'assets/images/theme_sunset_glow.jpg',
      previewImage: 'assets/images/theme_sunset_glow.jpg',
    ),
    RoomTheme(
      id: 'ocean_breeze',
      name: 'Ocean Breeze',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0C4A6E), Color(0xFF032236)],
      assetPath: 'assets/images/theme_ocean_breeze.jpg',
      previewImage: 'assets/images/theme_ocean_breeze.jpg',
    ),
    RoomTheme(
      id: 'emerald_aurora',
      name: 'Emerald Aurora',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF064E3B), Color(0xFF022C22)],
      assetPath: 'assets/images/theme_emerald_aurora.jpg',
      previewImage: 'assets/images/theme_emerald_aurora.jpg',
    ),
    RoomTheme(
      id: 'sakura_dream',
      name: 'Sakura Dream',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF4C0519), Color(0xFF1E020A)],
      assetPath: 'assets/images/theme_sakura_dream.jpg',
      previewImage: 'assets/images/theme_sakura_dream.jpg',
    ),
    RoomTheme(
      id: 'desert_dusk',
      name: 'Desert Dusk',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF451A03), Color(0xFF1C0A00)],
      assetPath: 'assets/images/theme_desert_dusk.jpg',
      previewImage: 'assets/images/theme_desert_dusk.jpg',
    ),
  ];

  static const List<RoomTheme> luxuryThemes = [
    RoomTheme(
      id: 'dragon_gold_palace',
      name: 'Dragon Gold',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF3A2500), Color(0xFF140D00)],
      assetPath: 'assets/images/dragon_gold_palace.png',
      previewImage: 'assets/images/dragon_gold_palace.png',
      isLuxury: true,
      badge: 'VIP GOLD',
    ),
    RoomTheme(
      id: 'royal_gold_palace',
      name: 'Royal Palace',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF422006), Color(0xFF1C0D02)],
      assetPath: 'assets/images/vip_bg.webp',
      previewImage: 'assets/images/vip_bg.webp',
      isLuxury: true,
      badge: 'ROYAL',
    ),
    RoomTheme(
      id: 'svip_obsidian',
      name: 'SVIP Obsidian',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1A1A1A), Color(0xFF050505)],
      assetPath: 'assets/images/svip_hero.png',
      previewImage: 'assets/images/svip_hero.png',
      isLuxury: true,
      badge: 'SVIP',
    ),
    RoomTheme(
      id: 'diamond_luxury',
      name: 'Noble Crystal',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
      assetPath: 'assets/images/noble_hall_hero.png',
      previewImage: 'assets/images/noble_hall_hero.png',
      isLuxury: true,
      badge: 'NOBLE',
    ),
    RoomTheme(
      id: 'starry_romance',
      name: 'Starry Romance',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF2E1065), Color(0xFF110526)],
      assetPath: 'assets/images/friendship_mall_hero.png',
      previewImage: 'assets/images/friendship_mall_hero.png',
      isLuxury: true,
      badge: 'ROMANCE',
    ),
    RoomTheme(
      id: 'golden_velvet',
      name: 'Golden Velvet',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF3B1D11), Color(0xFF190903)],
      assetPath: 'assets/images/theme_golden_velvet.jpg',
      previewImage: 'assets/images/theme_golden_velvet.jpg',
      isLuxury: true,
      badge: 'PREMIUM',
    ),
    RoomTheme(
      id: 'cyber_penthouse',
      name: 'Cyber Penthouse',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF17132B), Color(0xFF0A0717)],
      assetPath: 'assets/images/theme_cyber_penthouse.jpg',
      previewImage: 'assets/images/theme_cyber_penthouse.jpg',
      isLuxury: true,
      badge: 'ELITE',
    ),
    RoomTheme(
      id: 'clan_battle_arena',
      name: 'Battle Arena',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF450A0A), Color(0xFF1B0303)],
      assetPath: 'assets/images/clan_arena_bg.jpg',
      previewImage: 'assets/images/clan_arena_bg.jpg',
      isLuxury: true,
      badge: 'ARENA',
    ),
  ];

  static const List<RoomTheme> officialThemes = [
    RoomTheme(
      id: 'agency_theme',
      name: 'Agency Theme',
      category: RoomThemeCategory.official,
      gradient: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF020617)],
      assetPath: 'assets/images/theme_agency_official.jpg',
      previewImage: 'assets/images/theme_agency_official.jpg',
      isLuxury: true,
      badge: 'AGENCY 🏢',
    ),
    RoomTheme(
      id: 'admin_theme',
      name: 'Admin Theme',
      category: RoomThemeCategory.official,
      gradient: [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF09090B)],
      assetPath: 'assets/images/theme_admin_official.jpg',
      previewImage: 'assets/images/theme_admin_official.jpg',
      isLuxury: true,
      badge: 'ADMIN 🛡️',
    ),
    RoomTheme(
      id: 'official_theme',
      name: 'Official Theme',
      category: RoomThemeCategory.official,
      gradient: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF022C22)],
      assetPath: 'assets/images/theme_verified_official.jpg',
      previewImage: 'assets/images/theme_verified_official.jpg',
      isLuxury: true,
      badge: 'OFFICIAL 💎',
    ),
    RoomTheme(
      id: 'recharge_theme',
      name: 'Recharge Theme',
      category: RoomThemeCategory.official,
      gradient: [Color(0xFF3B0764), Color(0xFF581C87), Color(0xFF1E1B4B)],
      assetPath: 'assets/images/theme_recharge_official.jpg',
      previewImage: 'assets/images/theme_recharge_official.jpg',
      isLuxury: true,
      badge: 'RECHARGE ⚡',
    ),
  ];

  static List<RoomTheme> get allThemes => [...normalThemes, ...luxuryThemes, ...officialThemes];

  static RoomTheme getTheme(String? themeId) {
    if (themeId == null || themeId.isEmpty) return normalThemes.first;
    final clean = themeId.trim().toLowerCase();
    return allThemes.firstWhere(
      (t) => t.id.toLowerCase() == clean || t.name.toLowerCase() == clean,
      orElse: () => normalThemes.first,
    );
  }
}
