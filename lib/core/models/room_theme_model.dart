import 'package:flutter/material.dart';

enum RoomThemeCategory { normal, luxury }

class RoomTheme {
  final String id;
  final String name;
  final RoomThemeCategory category;
  final List<Color> gradient;
  final String? assetPath;
  final String? imageUrl;
  final String previewImage;
  final bool isLuxury;

  const RoomTheme({
    required this.id,
    required this.name,
    required this.category,
    required this.gradient,
    this.assetPath,
    this.imageUrl,
    required this.previewImage,
    this.isLuxury = false,
  });
}

class RoomThemeCatalog {
  static const List<RoomTheme> normalThemes = [
    RoomTheme(
      id: 'classic_purple',
      name: 'Classic Purple',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF2E0854), Color(0xFF130325)],
      previewImage: 'assets/images/levels_new/level_badge_1.webp',
    ),
    RoomTheme(
      id: 'midnight_blue',
      name: 'Midnight Blue',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0F172A), Color(0xFF020617)],
      previewImage: '',
    ),
    RoomTheme(
      id: 'neon_cyber',
      name: 'Cyber Neon',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF311042), Color(0xFF0B192C)],
      imageUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=800',
      previewImage: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=200',
    ),
    RoomTheme(
      id: 'sunset_glow',
      name: 'Sunset Glow',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF431407), Color(0xFF180A04)],
      imageUrl: 'https://images.unsplash.com/photo-1502481851512-e9e2529bfbf9?w=800',
      previewImage: 'https://images.unsplash.com/photo-1502481851512-e9e2529bfbf9?w=200',
    ),
    RoomTheme(
      id: 'ocean_breeze',
      name: 'Ocean Breeze',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0C4A6E), Color(0xFF032236)],
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
      previewImage: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200',
    ),
    RoomTheme(
      id: 'emerald_lounge',
      name: 'Emerald Lounge',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF064E3B), Color(0xFF022C22)],
      previewImage: '',
    ),
    RoomTheme(
      id: 'rose_velvet',
      name: 'Rose Velvet',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF4C0519), Color(0xFF1E020A)],
      previewImage: '',
    ),
  ];

  static const List<RoomTheme> luxuryThemes = [
    RoomTheme(
      id: 'dragon_gold_palace',
      name: 'Dragon Gold Empire',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF3A2500), Color(0xFF140D00)],
      assetPath: 'assets/images/dragon_gold_palace.png',
      previewImage: 'assets/images/dragon_gold_palace.png',
      isLuxury: true,
    ),
    RoomTheme(
      id: 'royal_gold_palace',
      name: 'Royal Gold Palace',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF422006), Color(0xFF1C0D02)],
      assetPath: 'assets/images/vip_bg.webp',
      previewImage: 'assets/images/vip_bg.webp',
      isLuxury: true,
    ),
    RoomTheme(
      id: 'svip_obsidian',
      name: 'SVIP Obsidian',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1A1A1A), Color(0xFF050505)],
      assetPath: 'assets/images/svip_hero.png',
      previewImage: 'assets/images/svip_hero.png',
      isLuxury: true,
    ),
    RoomTheme(
      id: 'diamond_luxury',
      name: 'Noble Crystal Palace',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
      assetPath: 'assets/images/noble_hall_hero.png',
      previewImage: 'assets/images/noble_hall_hero.png',
      isLuxury: true,
    ),
    RoomTheme(
      id: 'starry_romance',
      name: 'Starry Romance',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF2E1065), Color(0xFF110526)],
      assetPath: 'assets/images/friendship_mall_hero.png',
      previewImage: 'assets/images/friendship_mall_hero.png',
      isLuxury: true,
    ),
    RoomTheme(
      id: 'clan_battle_arena',
      name: 'Clan Battle Arena',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF450A0A), Color(0xFF1B0303)],
      assetPath: 'assets/images/clan_arena_bg.jpg',
      previewImage: 'assets/images/clan_arena_bg.jpg',
      isLuxury: true,
    ),
  ];

  static List<RoomTheme> get allThemes => [...normalThemes, ...luxuryThemes];

  static RoomTheme getTheme(String? themeId) {
    if (themeId == null || themeId.isEmpty) return normalThemes.first;
    final clean = themeId.trim().toLowerCase();
    return allThemes.firstWhere(
      (t) => t.id.toLowerCase() == clean || t.name.toLowerCase() == clean,
      orElse: () => normalThemes.first,
    );
  }
}
