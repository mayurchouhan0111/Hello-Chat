import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyBattleContributorModel {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final int userLevel;
  final int battlePoints;
  final int diamondsGifted;
  final DateTime? updatedAt;

  const FamilyBattleContributorModel({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.userLevel = 1,
    this.battlePoints = 0,
    this.diamondsGifted = 0,
    this.updatedAt,
  });

  factory FamilyBattleContributorModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyBattleContributorModel(
      userId: id,
      displayName: map['displayName'] ?? 'Member',
      avatarUrl: map['avatarUrl'] ?? '',
      userLevel: map['userLevel'] ?? 1,
      battlePoints: map['battlePoints'] ?? 0,
      diamondsGifted: map['diamondsGifted'] ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'userLevel': userLevel,
      'battlePoints': battlePoints,
      'diamondsGifted': diamondsGifted,
      'updatedAt': updatedAt,
    };
  }
}
