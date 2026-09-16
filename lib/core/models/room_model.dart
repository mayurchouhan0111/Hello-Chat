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
      roomId: map['roomId']?.toString() ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      theme: map['theme']?.toString() ?? 'classic',
      coverUrl: ((map['coverUrl'] as String?)?.trim().isNotEmpty == true
          ? map['coverUrl']
          : (map['roomCover'] as String?)?.trim().isNotEmpty == true
              ? map['roomCover']
              : (map['roomIcon'] as String?)?.trim().isNotEmpty == true
                  ? map['roomIcon']
                  : (map['ownerAvatar'] as String?)?.trim().isNotEmpty == true
                      ? map['ownerAvatar']
                      : (map['ownerProfilePic'] as String?)?.trim().isNotEmpty == true
                          ? map['ownerProfilePic']
                          : (map['userProfilePic'] as String?)?.trim().isNotEmpty == true
                              ? map['userProfilePic']
                              : (map['profilePhotoUrl'] as String?)?.trim().isNotEmpty == true
                                  ? map['profilePhotoUrl']
                                  : (map['photoUrl'] as String?)?.trim().isNotEmpty == true
                                      ? map['photoUrl']
                                      : '')?.toString() ?? '',
      isPrivate: map['isPrivate'] == true,
      passwordHash: map['passwordHash']?.toString(),
      capacity: (map['capacity'] as num?)?.toInt() ?? 10,
      currentUsersCount: (map['currentUsersCount'] as num?)?.toInt() ?? 0,
      backgroundMusic: map['backgroundMusic'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      status: map['status']?.toString() ?? 'active',
      admins: (map['admins'] as Iterable?)?.map((e) => e.toString()).toList() ?? [],
      moderators: (map['moderators'] as Iterable?)?.map((e) => e.toString()).toList() ?? [],
      bannedUids: (map['bannedUids'] as Iterable?)?.map((e) => e.toString()).toList() ?? [],
      banExpiries: map['banExpiries'] != null ? Map<String, dynamic>.from(map['banExpiries']) : null,
      pkActive: map['pkActive'] == true,
      pkStartTime: (map['pkStartTime'] as Timestamp?)?.toDate(),
      pkEndTime: (map['pkEndTime'] as Timestamp?)?.toDate(),
      pkScores: map['pkScores'] is Map
          ? (map['pkScores'] as Map).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : null,
      pkTeams: map['pkTeams'] is Map
          ? (map['pkTeams'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
      pkWinnerUid: map['pkWinnerUid']?.toString(),
      pkPhase: map['pkPhase']?.toString() ?? 'none',
      weeklyTarget: (map['weeklyTarget'] as num?)?.toInt() ?? 0,
      weeklyEarnings: (map['weeklyEarnings'] as num?)?.toInt() ?? 0,
      agencyId: map['agencyId']?.toString(),
      hourlyRank: (map['hourlyRank'] as num?)?.toInt() ?? 99,
      isTrending: map['isTrending'] == true,
      newsStatus: map['newsStatus']?.toString(),
      notice: map['notice']?.toString() ?? "Welcome to our room!",
      welcomeMessage: map['welcomeMessage']?.toString() ?? "Thanks for joining us!",
      publicScreenSetting: map['publicScreenSetting'] != false,
      roomType: map['roomType']?.toString() ?? "Chat",
      micMode: map['micMode']?.toString() ?? "open mode",
      superMic: map['superMic'] == true,
      effectSwitch: map['effectSwitch'] != false,
      youtubeVideoId: map['youtubeVideoId']?.toString(),
      isYoutubeActive: (map['isYoutubeActive'] == true) && (map['youtubeVideoId']?.toString().isNotEmpty == true),
      youtubeStatus: map['youtubeStatus']?.toString() ?? 'stopped',
      youtubeSeekTime: (map['youtubeSeekTime'] as num?)?.toInt() ?? 0,
      youtubeVolume: (map['youtubeVolume'] as num?)?.toInt() ?? 100,
      pkChallenge: map['pkChallenge'] != null ? Map<String, dynamic>.from(map['pkChallenge']) : null,
      pkContributions: map['pkContributions'] != null ? Map<String, dynamic>.from(map['pkContributions']) : null,
      pkWinnerData: map['pkWinnerData'] != null ? Map<String, dynamic>.from(map['pkWinnerData']) : null,
      lockedSeats: (map['lockedSeats'] as Iterable?)?.map((e) => (e as num?)?.toInt()).whereType<int>().toList() ?? [],
      rocketFuel: (map['rocketFuel'] as num?)?.toInt() ?? 0,
      rocketLevel: (map['rocketLevel'] as num?)?.toInt() ?? 0,
      rocketContributions: map['rocketContributions'] is Map
          ? (map['rocketContributions'] as Map).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : null,
      rocketStatus: map['rocketStatus']?.toString() ?? 'active',
      rocketCooldownUntil: (map['rocketCooldownUntil'] as Timestamp?)?.toDate(),
      lastRocketResults: map['lastRocketResults'] != null ? Map<String, dynamic>.from(map['lastRocketResults']) : null,
    );
  }

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) throw Exception("Room not found");
    return RoomModel.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }
}
