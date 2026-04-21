import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String uid;
  final String displayName;
  final String profilePhotoUrl;
  final DateTime joinedAt;
  final DateTime lastActive;
  final int? seatIndex;
  final bool isMuted;
  final String role; // "host" | "admin" | "speaker" | "audience"
  final String vipTier;
  final String nobleTier;
  final String entryAnimation;
  final String profileFrame;
  final bool priorityMicAccess;
  final bool isAdmin;

  Participant({
    required this.uid,
    this.displayName = "User",
    this.profilePhotoUrl = "",
    required this.joinedAt,
    required this.lastActive,
    this.seatIndex,
    required this.isMuted,
    required this.role,
    this.vipTier = "none",
    this.nobleTier = "Civilian",
    this.entryAnimation = "",
    this.profileFrame = "",
    this.priorityMicAccess = false,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'profilePhotoUrl': profilePhotoUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'seatIndex': seatIndex,
      'isMuted': isMuted,
      'role': role,
      'vipTier': vipTier,
      'nobleTier': nobleTier,
      'entryAnimation': entryAnimation,
      'profileFrame': profileFrame,
      'priorityMicAccess': priorityMicAccess,
      'isAdmin': isAdmin,
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map, String docId) {
    return Participant(
      uid: docId,
      displayName: map['displayName'] ?? "User",
      profilePhotoUrl: map['profilePhotoUrl'] ?? "",
      joinedAt: map['joinedAt'] != null ? (map['joinedAt'] as Timestamp).toDate() : DateTime.now(),
      lastActive: map['lastActive'] != null ? (map['lastActive'] as Timestamp).toDate() : DateTime.now(),
      seatIndex: map['seatIndex'],
      isMuted: map['isMuted'] ?? false,
      role: map['role'] ?? 'audience',
      vipTier: map['vipTier'] ?? 'none',
      nobleTier: map['nobleTier'] ?? 'Civilian',
      entryAnimation: map['entryAnimation'] ?? '',
      profileFrame: map['profileFrame'] ?? '',
      priorityMicAccess: map['priorityMicAccess'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
    );
  }
}



