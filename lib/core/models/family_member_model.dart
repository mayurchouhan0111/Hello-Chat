import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  final String id;
  final String familyId;
  final String userId;
  final String role; // "owner", "admin", "member"
  final int memberLevel;
  final int memberXP;
  final int combatPoints;
  final int contribution;
  final int totalDiamondsSent;
  final int totalBattlePoints;
  final List<Map<String, dynamic>> contributionHistory;
  final DateTime joinedAt;

  static const int xpPerLevel = 50000;

  static int levelForXP(int xp) {
    int level = 1;
    int required = xpPerLevel;
    while (xp >= required && level < 50) {
      level++;
      required += xpPerLevel;
    }
    return level;
  }

  int get xpToNextLevel {
    int required = 0;
    for (int i = 1; i <= memberLevel; i++) {
      required += xpPerLevel;
    }
    return required;
  }

  int get xpProgress => memberXP % xpPerLevel;

  const FamilyMemberModel({
    required this.id,
    required this.familyId,
    required this.userId,
    this.role = 'member',
    this.memberLevel = 1,
    this.memberXP = 0,
    this.combatPoints = 0,
    this.contribution = 0,
    this.totalDiamondsSent = 0,
    this.totalBattlePoints = 0,
    this.contributionHistory = const [],
    required this.joinedAt,
  });

  factory FamilyMemberModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMemberModel(
      id: id,
      familyId: map['familyId'] ?? '',
      userId: map['userId'] ?? '',
      role: map['role'] ?? 'member',
      memberLevel: map['memberLevel'] ?? 1,
      memberXP: map['memberXP'] ?? 0,
      combatPoints: map['combatPoints'] ?? 0,
      contribution: map['contribution'] ?? 0,
      totalDiamondsSent: map['totalDiamondsSent'] ?? 0,
      totalBattlePoints: map['totalBattlePoints'] ?? 0,
      contributionHistory: (map['contributionHistory'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'userId': userId,
      'role': role,
      'memberLevel': memberLevel,
      'memberXP': memberXP,
      'combatPoints': combatPoints,
      'contribution': contribution,
      'totalDiamondsSent': totalDiamondsSent,
      'totalBattlePoints': totalBattlePoints,
      'contributionHistory': contributionHistory,
      'joinedAt': joinedAt,
    };
  }

  FamilyMemberModel copyWith({
    String? role,
    int? memberLevel,
    int? memberXP,
    int? combatPoints,
    int? contribution,
    int? totalDiamondsSent,
    int? totalBattlePoints,
    List<Map<String, dynamic>>? contributionHistory,
  }) {
    return FamilyMemberModel(
      id: id,
      familyId: familyId,
      userId: userId,
      role: role ?? this.role,
      memberLevel: memberLevel ?? this.memberLevel,
      memberXP: memberXP ?? this.memberXP,
      combatPoints: combatPoints ?? this.combatPoints,
      contribution: contribution ?? this.contribution,
      totalDiamondsSent: totalDiamondsSent ?? this.totalDiamondsSent,
      totalBattlePoints: totalBattlePoints ?? this.totalBattlePoints,
      contributionHistory: contributionHistory ?? this.contributionHistory,
      joinedAt: joinedAt,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
}
