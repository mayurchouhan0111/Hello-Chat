import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String uid;
  final String displayName;
  final String profilePhotoUrl;
  final DateTime joinedAt;
  final DateTime lastActive;
  final int? seatIndex;
  final bool isMuted;
  final String role;
  final String vipTier;
  final String nobleTier;
  final String entryAnimation;
  final String profileFrame;
  final bool priorityMicAccess;
  final bool isAdmin;
  final List<String> tags;
  final int level;
  final bool isSinger;
  final int diamondsSent;
  final int diamondsReceived;
  final int? helloId;

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
    this.tags = const [],
    this.level = 1,
    this.isSinger = false,
    this.diamondsSent = 0,
    this.diamondsReceived = 0,
    this.helloId,
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
      'tags': tags,
      'level': level,
      'isSinger': isSinger,
      'diamondsSent': diamondsSent,
      'diamondsReceived': diamondsReceived,
      'helloId': helloId,
    };
  }

  static DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now();
  }

  factory Participant.fromMap(Map<String, dynamic> map, String docId) {
    return Participant(
      uid: docId,
      displayName: map['displayName'] ?? "User",
      profilePhotoUrl: map['profilePhotoUrl'] ?? "",
      joinedAt: _parseDateTime(map['joinedAt']),
      lastActive: _parseDateTime(map['lastActive']),
      seatIndex: map['seatIndex'],
      isMuted: map['isMuted'] ?? false,
      role: map['role'] ?? 'audience',
      vipTier: map['vipTier'] ?? 'none',
      nobleTier: map['nobleTier'] ?? 'Civilian',
      entryAnimation: map['entryAnimation'] ?? '',
      profileFrame: map['profileFrame'] ?? '',
      priorityMicAccess: map['priorityMicAccess'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      tags: (map['tags'] as Iterable?)?.whereType<String>().toList() ?? [],
      level: map['level'] ?? 1,
      isSinger: map['isSinger'] ?? false,
      diamondsSent: map['diamondsSent'] ?? 0,
      diamondsReceived: map['diamondsReceived'] ?? 0,
      helloId: map['helloId'] as int?,
    );
  }
}



