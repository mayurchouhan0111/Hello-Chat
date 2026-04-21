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
  final DateTime createdAt;
  final String category;
  final int rank;
  final JoinMode joinMode;
  final int levelRequirement;

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
    required this.createdAt,
    this.category = "Social",
    this.rank = 0,
    this.joinMode = JoinMode.free,
    this.levelRequirement = 0,
  });

  factory FamilyModel.fromMap(Map<String, dynamic> map, String id) {
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
      totalCombatPoints: map['totalCombatPoints'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] ?? 'Social',
      rank: map['rank'] ?? 0,
      joinMode: JoinMode.values.firstWhere(
        (e) => e.name == (map['joinMode'] ?? 'free'),
        orElse: () => JoinMode.free,
      ),
      levelRequirement: map['levelRequirement'] ?? 0,
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
      'createdAt': createdAt,
      'category': category,
      'rank': rank,
      'joinMode': joinMode.name,
      'levelRequirement': levelRequirement,
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
    DateTime? createdAt,
    String? category,
    int? rank,
    JoinMode? joinMode,
    int? levelRequirement,
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
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      rank: rank ?? this.rank,
      joinMode: joinMode ?? this.joinMode,
      levelRequirement: levelRequirement ?? this.levelRequirement,
    );
  }
}
