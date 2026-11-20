import 'package:flutter/material.dart';

enum RoomThemeCategory { normal, luxury, official }

class RoomThemeCategoryInfo {
  final RoomThemeCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const RoomThemeCategoryInfo({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

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
  final Color accentColor;
  final Color seatRingColor;
  final Color stageAtmosphereColor;

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
    this.accentColor = const Color(0xFF6366F1),
    this.seatRingColor = const Color(0x99FFFFFF),
    this.stageAtmosphereColor = const Color(0x33000000),
  });
}

class RoomThemeCatalog {
  static const List<RoomThemeCategoryInfo> categories = [
    RoomThemeCategoryInfo(
      category: RoomThemeCategory.normal,
      title: "Normal",
      subtitle: "Standard room background themes",
      icon: Icons.brush_rounded,
      accentColor: Color(0xFF818CF8),
    ),
    RoomThemeCategoryInfo(
      category: RoomThemeCategory.luxury,
      title: "Luxury",
      subtitle: "Premium & elegant palace designs",
      icon: Icons.star_rounded,
      accentColor: Color(0xFFFFD700),
    ),
    RoomThemeCategoryInfo(
      category: RoomThemeCategory.official,
      title: "Official",
      subtitle: "Agency, Admin, Official, & Recharge themes",
      icon: Icons.shield_rounded,
      accentColor: Color(0xFF38BDF8),
    ),
  ];

  static const List<RoomTheme> normalThemes = [
    RoomTheme(
      id: 'classic_purple',
      name: 'Classic Purple',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF2E0854), Color(0xFF130325)],
      assetPath: 'assets/images/theme_classic_purple.jpg',
      previewImage: 'assets/images/theme_classic_purple.jpg',
      accentColor: Color(0xFFA855F7),
      seatRingColor: Color(0x99A855F7),
      stageAtmosphereColor: Color(0x22A855F7),
    ),
    RoomTheme(
      id: 'midnight_blue',
      name: 'Midnight Blue',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0F172A), Color(0xFF020617)],
      assetPath: 'assets/images/theme_midnight_blue.jpg',
      previewImage: 'assets/images/theme_midnight_blue.jpg',
      accentColor: Color(0xFF38BDF8),
      seatRingColor: Color(0x9938BDF8),
      stageAtmosphereColor: Color(0x2238BDF8),
    ),
    RoomTheme(
      id: 'neon_cyber',
      name: 'Cyber Neon',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF311042), Color(0xFF0B192C)],
      assetPath: 'assets/images/theme_cyber_neon.jpg',
      previewImage: 'assets/images/theme_cyber_neon.jpg',
      accentColor: Color(0xFF00F0FF),
      seatRingColor: Color(0x9900F0FF),
      stageAtmosphereColor: Color(0x2200F0FF),
    ),
    RoomTheme(
      id: 'sunset_glow',
      name: 'Sunset Glow',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF431407), Color(0xFF180A04)],
      assetPath: 'assets/images/theme_sunset_glow.jpg',
      previewImage: 'assets/images/theme_sunset_glow.jpg',
      accentColor: Color(0xFFFF7A00),
      seatRingColor: Color(0x99FF7A00),
      stageAtmosphereColor: Color(0x22FF7A00),
    ),
    RoomTheme(
      id: 'ocean_breeze',
      name: 'Ocean Breeze',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF0C4A6E), Color(0xFF032236)],
      assetPath: 'assets/images/theme_ocean_breeze.jpg',
      previewImage: 'assets/images/theme_ocean_breeze.jpg',
      accentColor: Color(0xFF06B6D4),
      seatRingColor: Color(0x9906B6D4),
      stageAtmosphereColor: Color(0x2206B6D4),
    ),
    RoomTheme(
      id: 'emerald_aurora',
      name: 'Emerald Aurora',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF064E3B), Color(0xFF022C22)],
      assetPath: 'assets/images/theme_emerald_aurora.jpg',
      previewImage: 'assets/images/theme_emerald_aurora.jpg',
      accentColor: Color(0xFF10B981),
      seatRingColor: Color(0x9910B981),
      stageAtmosphereColor: Color(0x2210B981),
    ),
    RoomTheme(
      id: 'sakura_dream',
      name: 'Sakura Dream',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF4C0519), Color(0xFF1E020A)],
      assetPath: 'assets/images/theme_sakura_dream.jpg',
      previewImage: 'assets/images/theme_sakura_dream.jpg',
      accentColor: Color(0xFFF472B6),
      seatRingColor: Color(0x99F472B6),
      stageAtmosphereColor: Color(0x22F472B6),
    ),
    RoomTheme(
      id: 'desert_dusk',
      name: 'Desert Dusk',
      category: RoomThemeCategory.normal,
      gradient: [Color(0xFF451A03), Color(0xFF1C0A00)],
      assetPath: 'assets/images/theme_desert_dusk.jpg',
      previewImage: 'assets/images/theme_desert_dusk.jpg',
      accentColor: Color(0xFFFB923C),
      seatRingColor: Color(0x99FB923C),
      stageAtmosphereColor: Color(0x22FB923C),
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
      badge: 'VIP GOLD 👑',
      accentColor: Color(0xFFFFD700),
      seatRingColor: Color(0xCCFFD700),
      stageAtmosphereColor: Color(0x2AFFD700),
    ),
    RoomTheme(
      id: 'royal_gold_palace',
      name: 'Royal Palace',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF422006), Color(0xFF1C0D02)],
      assetPath: 'assets/images/vip_bg.webp',
      previewImage: 'assets/images/vip_bg.webp',
      isLuxury: true,
      badge: 'ROYAL 🏰',
      accentColor: Color(0xFFFFB300),
      seatRingColor: Color(0xCCFFB300),
      stageAtmosphereColor: Color(0x2AFFB300),
    ),
    RoomTheme(
      id: 'svip_obsidian',
      name: 'SVIP Obsidian',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1A1A1A), Color(0xFF050505)],
      assetPath: 'assets/images/svip_hero.png',
      previewImage: 'assets/images/svip_hero.png',
      isLuxury: true,
      badge: 'SVIP 💎',
      accentColor: Color(0xFFC084FC),
      seatRingColor: Color(0xCCA855F7),
      stageAtmosphereColor: Color(0x2AC084FC),
    ),
    RoomTheme(
      id: 'diamond_luxury',
      name: 'Noble Crystal',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
      assetPath: 'assets/images/noble_hall_hero.png',
      previewImage: 'assets/images/noble_hall_hero.png',
      isLuxury: true,
      badge: 'NOBLE ⚔️',
      accentColor: Color(0xFF818CF8),
      seatRingColor: Color(0xCC818CF8),
      stageAtmosphereColor: Color(0x2A818CF8),
    ),
    RoomTheme(
      id: 'starry_romance',
      name: 'Starry Romance',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF2E1065), Color(0xFF110526)],
      assetPath: 'assets/images/friendship_mall_hero.png',
      previewImage: 'assets/images/friendship_mall_hero.png',
      isLuxury: true,
      badge: 'ROMANCE 💖',
      accentColor: Color(0xFFE879F9),
      seatRingColor: Color(0xCCE879F9),
      stageAtmosphereColor: Color(0x2AE879F9),
    ),
    RoomTheme(
      id: 'golden_velvet',
      name: 'Golden Velvet',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF3B1D11), Color(0xFF190903)],
      assetPath: 'assets/images/theme_golden_velvet.jpg',
      previewImage: 'assets/images/theme_golden_velvet.jpg',
      isLuxury: true,
      badge: 'PREMIUM ⚜️',
      accentColor: Color(0xFFFBBF24),
      seatRingColor: Color(0xCCFBBF24),
      stageAtmosphereColor: Color(0x2AFBBF24),
    ),
    RoomTheme(
      id: 'cyber_penthouse',
      name: 'Cyber Penthouse',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF17132B), Color(0xFF0A0717)],
      assetPath: 'assets/images/theme_cyber_penthouse.jpg',
      previewImage: 'assets/images/theme_cyber_penthouse.jpg',
      isLuxury: true,
      badge: 'ELITE 🚀',
      accentColor: Color(0xFF22D3EE),
      seatRingColor: Color(0xCC22D3EE),
      stageAtmosphereColor: Color(0x2A22D3EE),
    ),
    RoomTheme(
      id: 'clan_battle_arena',
      name: 'Battle Arena',
      category: RoomThemeCategory.luxury,
      gradient: [Color(0xFF450A0A), Color(0xFF1B0303)],
      assetPath: 'assets/images/clan_arena_bg.jpg',
      previewImage: 'assets/images/clan_arena_bg.jpg',
      isLuxury: true,
      badge: 'ARENA 🏆',
      accentColor: Color(0xFFF43F5E),
      seatRingColor: Color(0xCCF43F5E),
      stageAtmosphereColor: Color(0x2AF43F5E),
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
      accentColor: Color(0xFF38BDF8),
      seatRingColor: Color(0xCC38BDF8),
      stageAtmosphereColor: Color(0x2538BDF8),
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
      accentColor: Color(0xFFE2E8F0),
      seatRingColor: Color(0xCCE2E8F0),
      stageAtmosphereColor: Color(0x20E2E8F0),
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
      accentColor: Color(0xFF34D399),
      seatRingColor: Color(0xCC34D399),
      stageAtmosphereColor: Color(0x2534D399),
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
      accentColor: Color(0xFFFACC15),
      seatRingColor: Color(0xCCFACC15),
      stageAtmosphereColor: Color(0x25FACC15),
    ),
  ];

  static List<RoomTheme> get allThemes => [...normalThemes, ...luxuryThemes, ...officialThemes];

  static RoomTheme getTheme(String? themeId) {
    if (themeId == null || themeId.isEmpty) return normalThemes.first;
    final clean = themeId.trim().toLowerCase();

    // Direct match by ID or exact Name
    for (final t in allThemes) {
      if (t.id.toLowerCase() == clean || t.name.toLowerCase() == clean) {
        return t;
      }
    }

    // Flexible Smart Alias Mapping for legacy or partial strings
    if (clean.contains('agency')) return officialThemes[0];
    if (clean.contains('admin')) return officialThemes[1];
    if (clean.contains('official') || clean.contains('verified')) return officialThemes[2];
    if (clean.contains('recharge')) return officialThemes[3];

    if (clean.contains('dragon')) return luxuryThemes[0];
    if (clean.contains('royal') || clean.contains('vip_bg')) return luxuryThemes[1];
    if (clean.contains('svip') || clean.contains('obsidian')) return luxuryThemes[2];
    if (clean.contains('noble') || clean.contains('crystal')) return luxuryThemes[3];
    if (clean.contains('romance') || clean.contains('starry')) return luxuryThemes[4];
    if (clean.contains('velvet') || clean.contains('golden')) return luxuryThemes[5];
    if (clean.contains('penthouse')) return luxuryThemes[6];
    if (clean.contains('arena') || clean.contains('battle') || clean.contains('clan')) return luxuryThemes[7];

    if (clean.contains('classic') || clean.contains('purple')) return normalThemes[0];
    if (clean.contains('midnight') || clean.contains('blue')) return normalThemes[1];
    if (clean.contains('neon') || clean.contains('cyber')) return normalThemes[2];
    if (clean.contains('sunset') || clean.contains('dusk')) return normalThemes[3];
    if (clean.contains('ocean') || clean.contains('breeze')) return normalThemes[4];
    if (clean.contains('emerald') || clean.contains('aurora')) return normalThemes[5];
    if (clean.contains('sakura') || clean.contains('dream')) return normalThemes[6];
    if (clean.contains('desert')) return normalThemes[7];

    return normalThemes.first;
  }
}
