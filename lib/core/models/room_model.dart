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
  final List<String> moderators;
  final List<String> bannedUids;
  final Map<String, dynamic>? banExpiries;
  final bool pkActive;
  final DateTime? pkStartTime;
  final DateTime? pkEndTime;
  final Map<String, int>? pkScores;
  final Map<String, String>? pkTeams;
  final String? pkWinnerUid;
  final String pkPhase;
  final int weeklyTarget;
  final int weeklyEarnings;
  final String? agencyId;
  final int hourlyRank;
  final bool isTrending;
  final String? newsStatus;
  final String notice;
  final String welcomeMessage;
  final bool publicScreenSetting;
  final String roomType;
  final String micMode;
  final bool superMic;
  final bool effectSwitch;
  final String? youtubeVideoId;
  final bool isYoutubeActive;
  final String youtubeStatus; // "playing" | "paused" | "stopped"
  final int youtubeSeekTime;
  final int youtubeVolume;
  final Map<String, dynamic>? pkChallenge;
  final Map<String, dynamic>? pkContributions;
  final Map<String, dynamic>? pkWinnerData;
  final List<int> lockedSeats;
  final int rocketFuel;
  final int rocketLevel;
  final Map<String, int>? rocketContributions;
  final String rocketStatus; // "active" | "cooldown"
  final DateTime? rocketCooldownUntil;
  final Map<String, dynamic>? lastRocketResults;

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
    required this.moderators,
    required this.bannedUids,
    this.banExpiries,
    this.pkActive = false,
    this.pkStartTime,
    this.pkEndTime,
    this.pkScores,
    this.pkTeams,
    this.pkWinnerUid,
    this.pkPhase = 'none',
    this.weeklyTarget = 0,
    this.weeklyEarnings = 0,
    this.agencyId,
    this.hourlyRank = 99,
    this.isTrending = false,
    this.newsStatus,
    this.notice = "Welcome to our room!",
    this.welcomeMessage = "Thanks for joining us!",
    this.publicScreenSetting = true,
    this.roomType = "Chat",
    this.micMode = "open mode",
    this.superMic = false,
    this.effectSwitch = true,
    this.youtubeVideoId,
    this.isYoutubeActive = false,
    this.youtubeStatus = 'stopped',
    this.youtubeSeekTime = 0,
    this.youtubeVolume = 100,
    this.pkChallenge,
    this.pkContributions,
    this.pkWinnerData,
    this.lockedSeats = const [],
    this.rocketFuel = 0,
    this.rocketLevel = 0,
    this.rocketContributions,
    this.rocketStatus = "active",
    this.rocketCooldownUntil,
    this.lastRocketResults,
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
      'moderators': moderators,
      'bannedUids': bannedUids,
      'banExpiries': banExpiries,
      'pkActive': pkActive,
      'pkStartTime': pkStartTime != null ? Timestamp.fromDate(pkStartTime!) : null,
      'pkEndTime': pkEndTime != null ? Timestamp.fromDate(pkEndTime!) : null,
      'pkScores': pkScores,
      'pkTeams': pkTeams,
      'pkWinnerUid': pkWinnerUid,
      'pkPhase': pkPhase,
      'weeklyTarget': weeklyTarget,
      'weeklyEarnings': weeklyEarnings,
      'agencyId': agencyId,
      'hourlyRank': hourlyRank,
      'isTrending': isTrending,
      'newsStatus': newsStatus,
      'notice': notice,
      'welcomeMessage': welcomeMessage,
      'publicScreenSetting': publicScreenSetting,
      'roomType': roomType,
      'micMode': micMode,
      'superMic': superMic,
      'effectSwitch': effectSwitch,
      'youtubeVideoId': youtubeVideoId,
      'isYoutubeActive': isYoutubeActive,
      'youtubeStatus': youtubeStatus,
      'youtubeSeekTime': youtubeSeekTime,
      'youtubeVolume': youtubeVolume,
      'pkChallenge': pkChallenge,
      'pkContributions': pkContributions,
      'pkWinnerData': pkWinnerData,
      'lockedSeats': lockedSeats,
      'rocketFuel': rocketFuel,
      'rocketLevel': rocketLevel,
      'rocketContributions': rocketContributions,
      'rocketStatus': rocketStatus,
      'rocketCooldownUntil': rocketCooldownUntil != null ? Timestamp.fromDate(rocketCooldownUntil!) : null,
      'lastRocketResults': lastRocketResults,
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
      capacity: (map['capacity'] ?? 10) as int,
      currentUsersCount: (map['currentUsersCount'] ?? 0) as int,
      backgroundMusic: map['backgroundMusic'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'active',
      admins: (map['admins'] as Iterable?)?.whereType<String>().toList() ?? [],
      moderators: (map['moderators'] as Iterable?)?.whereType<String>().toList() ?? [],
      bannedUids: (map['bannedUids'] as Iterable?)?.whereType<String>().toList() ?? [],
      banExpiries: map['banExpiries'] != null ? Map<String, dynamic>.from(map['banExpiries']) : null,
      pkActive: map['pkActive'] ?? false,
      pkStartTime: (map['pkStartTime'] as Timestamp?)?.toDate(),
      pkEndTime: (map['pkEndTime'] as Timestamp?)?.toDate(),
      pkScores: (map['pkScores'] as Map?)?.cast<String, int>(),
      pkTeams: (map['pkTeams'] as Map?)?.cast<String, String>(),
      pkWinnerUid: map['pkWinnerUid'],
      pkPhase: map['pkPhase'] ?? 'none',
      weeklyTarget: (map['weeklyTarget'] ?? 0) as int,
      weeklyEarnings: (map['weeklyEarnings'] ?? 0) as int,
      agencyId: map['agencyId'],
      hourlyRank: (map['hourlyRank'] ?? 99) as int,
      isTrending: map['isTrending'] ?? false,
      newsStatus: map['newsStatus'],
      notice: map['notice'] ?? "Welcome to our room!",
      welcomeMessage: map['welcomeMessage'] ?? "Thanks for joining us!",
      publicScreenSetting: map['publicScreenSetting'] ?? true,
      roomType: map['roomType'] ?? "Chat",
      micMode: map['micMode'] ?? "open mode",
      superMic: map['superMic'] ?? false,
      effectSwitch: map['effectSwitch'] ?? true,
      youtubeVideoId: map['youtubeVideoId'],
      isYoutubeActive: (map['isYoutubeActive'] ?? false) && (map['youtubeVideoId'] as String?)?.isNotEmpty == true,
      youtubeStatus: map['youtubeStatus'] ?? 'stopped',
      youtubeSeekTime: (map['youtubeSeekTime'] ?? 0) as int,
      youtubeVolume: (map['youtubeVolume'] ?? 100) as int,
      pkChallenge: map['pkChallenge'] != null ? Map<String, dynamic>.from(map['pkChallenge']) : null,
      pkContributions: map['pkContributions'] != null ? Map<String, dynamic>.from(map['pkContributions']) : null,
      pkWinnerData: map['pkWinnerData'] != null ? Map<String, dynamic>.from(map['pkWinnerData']) : null,
      lockedSeats: (map['lockedSeats'] as Iterable?)?.whereType<int>().toList() ?? [],
      rocketFuel: (map['rocketFuel'] ?? 0) as int,
      rocketLevel: (map['rocketLevel'] ?? 0) as int,
      rocketContributions: (map['rocketContributions'] as Map?)?.cast<String, int>(),
      rocketStatus: map['rocketStatus'] ?? 'active',
      rocketCooldownUntil: (map['rocketCooldownUntil'] as Timestamp?)?.toDate(),
      lastRocketResults: map['lastRocketResults'] != null ? Map<String, dynamic>.from(map['lastRocketResults']) : null,
    );
  }

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) throw Exception("Room not found");
    return RoomModel.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }
}
