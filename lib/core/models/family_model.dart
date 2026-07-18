import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum JoinMode { free, verification, password }

class FamilyModel {
  final String id;
  final String name;
  final String? tag;
  final String description;
  final String? notice;
  final String ownerId;
  final String? bannerUrl;
  final String? avatarUrl;
  final List<String> memberUids;
  final int level;
  final int totalBattlePoints;
  final int totalCombatPoints;
  final int totalDiamonds;
  final DateTime createdAt;
  final String category;
  final int rank;
  final JoinMode joinMode;
  final int levelRequirement;
  final String country;
  final int monthlyTarget;
  final int currentMonthPoints;
  final int memberLimit;
  final String rankName;

  static const List<String> rankNames = [
    'Bronze', 'Silver', 'Gold', 'Diamond', 'Master',
    'Challenger I', 'Challenger II', 'Challenger III',
    'Supreme', 'Immortal',
  ];

  static const List<int> familyLevelThresholds = [
    0, 5000000, 10000000, 25000000, 50000000,
    100000000, 200000000, 400000000, 600000000, 800000000,
  ];

  static int familyLevelForPoints(int points) {
    for (int i = familyLevelThresholds.length - 1; i >= 0; i--) {
      if (points >= familyLevelThresholds[i]) return i + 1;
    }
    return 1;
  }

  static int themeIndexForLevel(int level) {
    if (level >= 9) return 3;
    if (level >= 7) return 2;
    if (level >= 4) return 1;
    return 0;
  }

  static int pointsForLevel(int level) {
    if (level <= 1) return 0;
    if (level > familyLevelThresholds.length) return familyLevelThresholds.last;
    return familyLevelThresholds[level - 1];
  }

  static int pointsForNextLevel(int level) {
    if (level >= familyLevelThresholds.length) return familyLevelThresholds.last * 2;
    return familyLevelThresholds[level];
  }

  static double levelProgress(int currentPoints, int level) {
    final currentThreshold = pointsForLevel(level);
    final nextThreshold = pointsForNextLevel(level);
    final needed = nextThreshold - currentThreshold;
    if (needed <= 0) return 1.0;
    return ((currentPoints - currentThreshold) / needed).clamp(0.0, 1.0);
  }

  static Color badgeColorForLevel(int level) {
    if (level >= 9) return const Color(0xFFDC2626);
    if (level >= 7) return const Color(0xFFD4A843);
    if (level >= 4) return const Color(0xFF6B7280);
    return const Color(0xFFCD7F32);
  }

  static Color progressColorForLevel(int level) {
    if (level >= 9) return const Color(0xFFDC2626);
    if (level >= 7) return const Color(0xFFD4A843);
    if (level >= 4) return const Color(0xFF6B7280);
    return const Color(0xFFCD7F32);
  }

  static List<Color> themeGradientForLevel(int level) {
    if (level >= 9) return [const Color(0xFFDC2626), const Color(0xFFD4A843)];
    if (level >= 7) return [const Color(0xFFD4A843), const Color(0xFFF59E0B)];
    if (level >= 4) return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    return [const Color(0xFFCD7F32), const Color(0xFFB8860B)];
  }

  static int memberCapacityForLevel(int familyLevel) {
    if (familyLevel >= 20) return 1000;
    if (familyLevel >= 10) return 500;
    if (familyLevel >= 5) return 300;
    return 100;
  }

  static String rankNameForPoints(int points) {
    if (points >= 50000000) return 'Immortal';
    if (points >= 30000000) return 'Supreme';
    if (points >= 16000000) return 'Challenger III';
    if (points >= 10000000) return 'Challenger II';
    if (points >= 5000000) return 'Challenger I';
    if (points >= 2000000) return 'Master';
    if (points >= 500000) return 'Diamond';
    if (points >= 100000) return 'Gold';
    if (points >= 20000) return 'Silver';
    return 'Bronze';
  }

  static int rankThresholdForName(String name) {
    switch (name) {
      case 'Silver': return 20000;
      case 'Gold': return 100000;
      case 'Diamond': return 500000;
      case 'Master': return 2000000;
      case 'Challenger I': return 5000000;
      case 'Challenger II': return 10000000;
      case 'Challenger III': return 16000000;
      case 'Supreme': return 30000000;
      case 'Immortal': return 50000000;
      default: return 0;
    }
  }

  int get memberCount => memberUids.length;
  bool get isFull => memberUids.length >= memberLimit;
  bool get monthlyTargetCompleted => currentMonthPoints >= monthlyTarget;

  FamilyModel({
    required this.id,
    required this.name,
    this.tag,
    required this.description,
    this.notice,
    required this.ownerId,
    this.bannerUrl,
    this.avatarUrl,
    required this.memberUids,
    this.level = 1,
    this.totalBattlePoints = 0,
    this.totalCombatPoints = 0,
    this.totalDiamonds = 0,
    required this.createdAt,
    this.category = "Social",
    this.rank = 0,
    this.joinMode = JoinMode.free,
    this.levelRequirement = 0,
    this.country = '',
    this.monthlyTarget = 3000000,
    this.currentMonthPoints = 0,
    this.memberLimit = 100,
    this.rankName = 'Bronze',
  });

  factory FamilyModel.fromMap(Map<String, dynamic> map, String id) {
    final pts = (map['totalCombatPoints'] as num? ?? 0).toInt();
    return FamilyModel(
      id: id,
      name: map['name'] ?? '',
      tag: map['tag'],
      description: map['description'] ?? '',
      notice: map['notice'],
      ownerId: map['ownerId'] ?? '',
      bannerUrl: map['bannerUrl'],
      avatarUrl: map['avatarUrl'],
      memberUids: List<String>.from(map['memberUids'] ?? []),
      level: map['level'] ?? 1,
      totalBattlePoints: map['totalBattlePoints'] ?? 0,
      totalCombatPoints: pts,
      totalDiamonds: map['totalDiamonds'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] ?? 'Social',
      rank: map['rank'] ?? 0,
      joinMode: JoinMode.values.firstWhere(
        (e) => e.name == (map['joinMode'] ?? 'free'),
        orElse: () => JoinMode.free,
      ),
      levelRequirement: map['levelRequirement'] ?? 0,
      country: map['country'] ?? '',
      monthlyTarget: map['monthlyTarget'] ?? 3000000,
      currentMonthPoints: map['currentMonthPoints'] ?? 0,
      memberLimit: map['memberLimit'] ?? memberCapacityForLevel(map['level'] ?? 1),
      rankName: map['rankName'] ?? rankNameForPoints(pts),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tag': tag,
      'description': description,
      'notice': notice,
      'ownerId': ownerId,
      'bannerUrl': bannerUrl,
      'avatarUrl': avatarUrl,
      'memberUids': memberUids,
      'level': level,
      'totalBattlePoints': totalBattlePoints,
      'totalCombatPoints': totalCombatPoints,
      'totalDiamonds': totalDiamonds,
      'createdAt': createdAt,
      'category': category,
      'rank': rank,
      'joinMode': joinMode.name,
      'levelRequirement': levelRequirement,
      'country': country,
      'monthlyTarget': monthlyTarget,
      'currentMonthPoints': currentMonthPoints,
      'memberLimit': memberLimit,
      'rankName': rankName,
    };
  }

  FamilyModel copyWith({
    String? name,
    String? tag,
    String? description,
    String? notice,
    String? ownerId,
    String? bannerUrl,
    String? avatarUrl,
    List<String>? memberUids,
    int? level,
    int? totalBattlePoints,
    int? totalCombatPoints,
    int? totalDiamonds,
    DateTime? createdAt,
    String? category,
    int? rank,
    JoinMode? joinMode,
    int? levelRequirement,
    String? country,
    int? monthlyTarget,
    int? currentMonthPoints,
    int? memberLimit,
    String? rankName,
  }) {
    return FamilyModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      description: description ?? this.description,
      notice: notice ?? this.notice,
      ownerId: ownerId ?? this.ownerId,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberUids: memberUids ?? this.memberUids,
      level: level ?? this.level,
      totalBattlePoints: totalBattlePoints ?? this.totalBattlePoints,
      totalCombatPoints: totalCombatPoints ?? this.totalCombatPoints,
      totalDiamonds: totalDiamonds ?? this.totalDiamonds,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      rank: rank ?? this.rank,
      joinMode: joinMode ?? this.joinMode,
      levelRequirement: levelRequirement ?? this.levelRequirement,
      country: country ?? this.country,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      currentMonthPoints: currentMonthPoints ?? this.currentMonthPoints,
      memberLimit: memberLimit ?? this.memberLimit,
      rankName: rankName ?? this.rankName,
    );
  }
}
