import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? email;
  final String username;
  final String displayName;
  final String bio;
  final String country;
  final String profilePhotoUrl;
  final String gender;
  final int diamondBalance;
  final int beansBalance;
  final int xp;
  final int benchXP;
  final int princeXP;
  final int level;
  final int followerCount;
  final int followingCount;
  final int friendsCount;
  final String status;
  final List<String> badges;
  final String profileFrame;
  final String entryAnimation;
  final String badgeIcon;
  final List<String> tags;
  final String vipTier;
  final DateTime? vipExpiry;
  final String? nobleTier;
  final DateTime? nobleExpiry;
  final bool isBanned;
  final DateTime lastActive;
  final String lastVipClaim;
  final String? agencyId;
  final bool isAgencyOwner;
  final String? familyId;
  final bool isFamilyOwner;
  final int combatPoints;
  final int? svipLevel;
  final int? svipPoints;
  final int? monthlyRecharge;
  final List<String> blockedUids;
  final String referralCode;
  final String? referredBy;
  final int totalReferralEarnings;
  final String? partnerUid;
  final String? partnerName;
  final String? partnerAvatar;
  final int cpLevel;
  final int cpPoints;
  final int? helloId;
  final int visitorCount;
  final List<String> recentVisitors; // Avatars of last 5 visitors
  final DateTime? birthday;
  final String? height;
  final String? weight;
  final String? hometown;
  final List<String> languages;
  final String? ethnicity;
  final String? personalLabel;
  final String? company;

  UserModel({
    required this.uid,
    required this.createdAt,
    this.phoneNumber,
    this.email,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.country,
    required this.profilePhotoUrl,
    required this.gender,
    required this.diamondBalance,
    required this.beansBalance,
    required this.xp,
    required this.benchXP,
    required this.princeXP,
    required this.level,
    required this.followerCount,
    required this.followingCount,
    required this.friendsCount,
    required this.status,
    required this.badges,
    required this.profileFrame,
    required this.entryAnimation,
    required this.badgeIcon,
    required this.tags,
    required this.vipTier,
    this.vipExpiry,
    this.nobleTier,
    this.nobleExpiry,
    required this.isBanned,
    required this.lastActive,
    this.lastVipClaim = '',
    this.agencyId,
    this.isAgencyOwner = false,
    this.familyId,
    this.isFamilyOwner = false,
    this.combatPoints = 0,
    this.svipLevel,
    this.svipPoints,
    this.monthlyRecharge,
    required this.blockedUids,
    required this.referralCode,
    this.referredBy,
    this.totalReferralEarnings = 0,
    this.partnerUid,
    this.partnerName,
    this.partnerAvatar,
    this.cpLevel = 0,
    this.cpPoints = 0,
    this.helloId,
    this.visitorCount = 0,
    this.recentVisitors = const [],
    this.birthday,
    this.height,
    this.weight,
    this.hometown,
    this.languages = const [],
    this.ethnicity,
    this.personalLabel,
    this.company,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: (data['uid'] as String?) ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      username: (data['username'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?) ?? '',
      gender: (data['gender'] as String?) ?? 'male',
      diamondBalance: (data['diamondBalance'] as num? ?? 0).toInt(),
      beansBalance: (data['beansBalance'] as num? ?? 0).toInt(),
      xp: (data['xp'] as num? ?? 0).toInt(),
      benchXP: (data['benchXP'] as num? ?? 0).toInt(),
      princeXP: (data['princeXP'] as num? ?? 0).toInt(),
      level: (data['level'] as num? ?? 1).toInt(),
      followerCount: (data['followerCount'] as num? ?? 0).toInt(),
      followingCount: (data['followingCount'] as num? ?? 0).toInt(),
      friendsCount: (data['friendsCount'] as num? ?? 0).toInt(),
      status: (data['status'] as String?) ?? 'offline',
      badges: (data['badges'] as Iterable?)?.whereType<String>().toList() ?? [],
      profileFrame: (data['profileFrame'] as String?) ?? '',
      entryAnimation: (data['entryAnimation'] as String?) ?? '',
      badgeIcon: (data['badgeIcon'] as String?) ?? '',
      tags: (data['tags'] as Iterable?)?.whereType<String>().toList() ?? [],
      vipTier: (data['vipTier'] as String?) ?? 'none',
      vipExpiry: data['vipExpiry'] != null 
          ? (data['vipExpiry'] as Timestamp).toDate() 
          : null,
      nobleTier: data['nobleTier'] as String?,
      nobleExpiry: data['nobleExpiry'] != null 
          ? (data['nobleExpiry'] as Timestamp).toDate() 
          : null,
      isBanned: (data['isBanned'] as bool?) ?? false,
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate() 
          : DateTime.now(),
      lastVipClaim: (data['lastVipClaim'] as String?) ?? '',
      agencyId: data['agencyId'] as String?,
      isAgencyOwner: (data['isAgencyOwner'] as bool?) ?? false,
      familyId: data['familyId'] as String?,
      isFamilyOwner: (data['isFamilyOwner'] as bool?) ?? false,
      svipLevel: (data['svipLevel'] as num?)?.toInt(),
      svipPoints: (data['svipPoints'] as num?)?.toInt(),
      monthlyRecharge: (data['monthlyRecharge'] as num?)?.toInt(),
      blockedUids: (data['blockedUids'] as Iterable?)?.whereType<String>().toList() ?? [],
      referralCode: (data['referralCode'] as String?) ?? (data['uid'] as String? ?? '').split('-').first.toUpperCase(),
      referredBy: data['referredBy'] as String?,
      totalReferralEarnings: (data['totalReferralEarnings'] as num? ?? 0).toInt(),
      partnerUid: data['partnerUid'] as String?,
      partnerName: data['partnerName'] as String?,
      partnerAvatar: data['partnerAvatar'] as String?,
      cpLevel: (data['cpLevel'] as num? ?? 0).toInt(),
      cpPoints: (data['cpPoints'] as num? ?? 0).toInt(),
      combatPoints: (data['combatPoints'] as num? ?? 0).toInt(),
      helloId: (data['helloId'] as num?)?.toInt(),
      visitorCount: (data['visitorCount'] as num? ?? 0).toInt(),
      recentVisitors: (data['recentVisitors'] as Iterable?)?.whereType<String>().toList() ?? [],
      birthday: data['birthday'] != null ? (data['birthday'] as Timestamp).toDate() : null,
      height: data['height'] as String?,
      weight: data['weight'] as String?,
      hometown: data['hometown'] as String?,
      languages: (data['languages'] as Iterable?)?.whereType<String>().toList() ?? [],
      ethnicity: data['ethnicity'] as String?,
      personalLabel: data['personalLabel'] as String?,
      company: data['company'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'createdAt': createdAt,
      'phoneNumber': phoneNumber,
      'email': email,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'country': country,
      'profilePhotoUrl': profilePhotoUrl,
      'gender': gender,
      'diamondBalance': diamondBalance,
      'beansBalance': beansBalance,
      'xp': xp,
      'benchXP': benchXP,
      'princeXP': princeXP,
      'level': level,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'status': status,
      'badges': badges,
      'profileFrame': profileFrame,
      'entryAnimation': entryAnimation,
      'badgeIcon': badgeIcon,
      'tags': tags,
      'vipTier': vipTier,
      'vipExpiry': vipExpiry,
      'nobleTier': nobleTier,
      'nobleExpiry': nobleExpiry,
      'isBanned': isBanned,
      'lastActive': lastActive,
      'lastVipClaim': lastVipClaim,
      'agencyId': agencyId,
      'isAgencyOwner': isAgencyOwner,
      'familyId': familyId,
      'isFamilyOwner': isFamilyOwner,
      'svipLevel': svipLevel,
      'svipPoints': svipPoints,
      'monthlyRecharge': monthlyRecharge,
      'blockedUids': blockedUids,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'totalReferralEarnings': totalReferralEarnings,
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'partnerAvatar': partnerAvatar,
      'cpLevel': cpLevel,
      'cpPoints': cpPoints,
      'combatPoints': combatPoints,
      'helloId': helloId,
      'visitorCount': visitorCount,
      'recentVisitors': recentVisitors,
      'birthday': birthday,
      'height': height,
      'weight': weight,
      'hometown': hometown,
      'languages': languages,
      'ethnicity': ethnicity,
      'personalLabel': personalLabel,
      'company': company,
    };
  }

  UserModel copyWith({
    String? uid,
    DateTime? createdAt,
    String? phoneNumber,
    String? email,
    String? username,
    String? displayName,
    String? bio,
    String? country,
    String? profilePhotoUrl,
    String? gender,
    int? diamondBalance,
    int? beansBalance,
    int? xp,
    int? benchXP,
    int? princeXP,
    int? level,
    int? followerCount,
    int? followingCount,
    int? friendsCount,
    String? status,
    List<String>? badges,
    String? profileFrame,
    String? entryAnimation,
    String? badgeIcon,
    List<String>? tags,
    String? vipTier,
    DateTime? vipExpiry,
    String? nobleTier,
    DateTime? nobleExpiry,
    bool? isBanned,
    DateTime? lastActive,
    String? lastVipClaim,
    String? agencyId,
    bool? isAgencyOwner,
    String? familyId,
    bool? isFamilyOwner,
    int? svipLevel,
    int? svipPoints,
    int? monthlyRecharge,
    List<String>? blockedUids,
    String? referralCode,
    String? referredBy,
    int? totalReferralEarnings,
    String? partnerUid,
    String? partnerName,
    String? partnerAvatar,
    int? cpLevel,
    int? cpPoints,
    int? combatPoints,
    int? helloId,
    int? visitorCount,
    List<String>? recentVisitors,
    DateTime? birthday,
    String? height,
    String? weight,
    String? hometown,
    List<String>? languages,
    String? ethnicity,
    String? personalLabel,
    String? company,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      country: country ?? this.country,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      gender: gender ?? this.gender,
      diamondBalance: diamondBalance ?? this.diamondBalance,
      beansBalance: beansBalance ?? this.beansBalance,
      xp: xp ?? this.xp,
      benchXP: benchXP ?? this.benchXP,
      princeXP: princeXP ?? this.princeXP,
      level: level ?? this.level,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      status: status ?? this.status,
      badges: badges ?? this.badges,
      profileFrame: profileFrame ?? this.profileFrame,
      entryAnimation: entryAnimation ?? this.entryAnimation,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      tags: tags ?? this.tags,
      vipTier: vipTier ?? this.vipTier,
      vipExpiry: vipExpiry ?? this.vipExpiry,
      nobleTier: nobleTier ?? this.nobleTier,
      nobleExpiry: nobleExpiry ?? this.nobleExpiry,
      isBanned: isBanned ?? this.isBanned,
      lastActive: lastActive ?? this.lastActive,
      lastVipClaim: lastVipClaim ?? this.lastVipClaim,
      agencyId: agencyId ?? this.agencyId,
      isAgencyOwner: isAgencyOwner ?? this.isAgencyOwner,
      familyId: familyId ?? this.familyId,
      isFamilyOwner: isFamilyOwner ?? this.isFamilyOwner,
      svipLevel: svipLevel ?? this.svipLevel,
      svipPoints: svipPoints ?? this.svipPoints,
      monthlyRecharge: monthlyRecharge ?? this.monthlyRecharge,
      blockedUids: blockedUids ?? this.blockedUids,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalReferralEarnings: totalReferralEarnings ?? this.totalReferralEarnings,
      partnerUid: partnerUid ?? this.partnerUid,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      cpLevel: cpLevel ?? this.cpLevel,
      cpPoints: cpPoints ?? this.cpPoints,
      combatPoints: combatPoints ?? this.combatPoints,
      helloId: helloId ?? this.helloId,
      visitorCount: visitorCount ?? this.visitorCount,
      recentVisitors: recentVisitors ?? this.recentVisitors,
      birthday: birthday ?? this.birthday,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      hometown: hometown ?? this.hometown,
      languages: languages ?? this.languages,
      ethnicity: ethnicity ?? this.ethnicity,
      personalLabel: personalLabel ?? this.personalLabel,
      company: company ?? this.company,
    );
  }

  bool get isAdmin => tags.contains('Admin') || tags.contains('SuperAdmin');

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }

  String get displayId => helloId != null 
    ? helloId.toString().padLeft(10, '0') 
    : "Pending...";
}
