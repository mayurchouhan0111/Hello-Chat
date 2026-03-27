import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String roomId;
  final String createdBy;
  final String ownerUid;
  final String name;
  final String theme;
  final String coverUrl;
  final bool isPrivate;
  final String? passwordHash;
  final int capacity;
  final int currentUsersCount;
  final bool backgroundMusic;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String status; // "active" | "ended"
  final List<String> admins;
  final List<String> bannedUids;
  final bool pkActive;
  final DateTime? pkStartTime;
  final DateTime? pkEndTime;
  final Map<String, int>? pkScores;
  final Map<String, String>? pkTeams;
  final String? pkWinnerUid;
  final int weeklyTarget;
  final int weeklyEarnings;
  final String? agencyId;

  RoomModel({
    required this.roomId,
    required this.createdBy,
    required this.ownerUid,
    required this.name,
    required this.theme,
    required this.coverUrl,
    required this.isPrivate,
    this.passwordHash,
    required this.capacity,
    required this.currentUsersCount,
    required this.backgroundMusic,
    required this.createdAt,
    this.endedAt,
    required this.status,
    required this.admins,
    required this.bannedUids,
    this.pkActive = false,
    this.pkStartTime,
    this.pkEndTime,
    this.pkScores,
    this.pkTeams,
    this.pkWinnerUid,
    this.weeklyTarget = 0,
    this.weeklyEarnings = 0,
    this.agencyId,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'createdBy': createdBy,
      'ownerUid': ownerUid,
      'name': name,
      'theme': theme,
      'coverUrl': coverUrl,
      'isPrivate': isPrivate,
      'passwordHash': passwordHash,
      'capacity': capacity,
      'currentUsersCount': currentUsersCount,
      'backgroundMusic': backgroundMusic,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'status': status,
      'admins': admins,
      'bannedUids': bannedUids,
      'pkActive': pkActive,
      'pkStartTime': pkStartTime != null ? Timestamp.fromDate(pkStartTime!) : null,
      'pkEndTime': pkEndTime != null ? Timestamp.fromDate(pkEndTime!) : null,
      'pkScores': pkScores,
      'pkTeams': pkTeams,
      'pkWinnerUid': pkWinnerUid,
      'weeklyTarget': weeklyTarget,
      'weeklyEarnings': weeklyEarnings,
      'agencyId': agencyId,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      roomId: map['roomId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      name: map['name'] ?? '',
      theme: map['theme'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      isPrivate: map['isPrivate'] ?? false,
      passwordHash: map['passwordHash'],
      capacity: map['capacity'] ?? 10,
      currentUsersCount: map['currentUsersCount'] ?? 0,
      backgroundMusic: map['backgroundMusic'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'active',
      admins: List<String>.from(map['admins'] ?? []),
      bannedUids: List<String>.from(map['bannedUids'] ?? []),
      pkActive: map['pkActive'] ?? false,
      pkStartTime: (map['pkStartTime'] as Timestamp?)?.toDate(),
      pkEndTime: (map['pkEndTime'] as Timestamp?)?.toDate(),
      pkScores: Map<String, int>.from(map['pkScores'] ?? {}),
      pkTeams: Map<String, String>.from(map['pkTeams'] ?? {}),
      pkWinnerUid: map['pkWinnerUid'],
      weeklyTarget: map['weeklyTarget'] ?? 0,
      weeklyEarnings: map['weeklyEarnings'] ?? 0,
      agencyId: map['agencyId'],
    );
  }
}
