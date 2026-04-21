import 'package:cloud_firestore/cloud_firestore.dart';

enum JoinRequestStatus { pending, accepted, rejected }

class FamilyJoinRequestModel {
  final String id;
  final String userId;
  final String familyId;
  final String userName;
  final String userAvatar;
  final JoinRequestStatus status;
  final DateTime createdAt;

  FamilyJoinRequestModel({
    required this.id,
    required this.userId,
    required this.familyId,
    required this.userName,
    required this.userAvatar,
    required this.status,
    required this.createdAt,
  });

  factory FamilyJoinRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyJoinRequestModel(
      id: id,
      userId: map['userId'] ?? '',
      familyId: map['familyId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'] ?? '',
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => JoinRequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'familyId': familyId,
      'userName': userName,
      'userAvatar': userAvatar,
      'status': status.name,
      'createdAt': createdAt,
    };
  }
}
