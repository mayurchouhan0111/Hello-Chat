import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/level_utils.dart';

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
  final int diamondStock;
  final int beansBalance;
  final int xp;
  final int dailyXP;
  final int weeklyXP;
  final int monthlyXP;
  final int benchXP;
  final int princeXP;
  final int dailyPrinceXP;
  final int weeklyPrinceXP;
  final int monthlyPrinceXP;
  final int level;
  final int followerCount;
  final int followingCount;
  final int friendsCount;
  final String status;
  final List<String> badges;
  final String profileFrame;
  final String chatBubble;
  final String entryAnimation;
  final String badgeIcon;
  final String equippedCrown;
  final String equippedMicWave;
  final String profileTheme;
  final String prettyId;
  final List<String> tags;
  final String vipTier;
  final DateTime? vipExpiry;
  final String? nobleTier;
  final DateTime? nobleExpiry;
  final bool isBanned;
  final DateTime lastActive;
  final String lastVipClaim;
  final DateTime? lastDailyClaim;
  final String? agencyId;
  final bool isAgencyOwner;
  final String? familyId;
  final bool isFamilyOwner;
  final int combatPoints;
  final int? svipLevel;
  final int? svipPoints;
  final DateTime? svipCycleEndDate;
  final DateTime? svipCycleStartDate;
  final DateTime? lastSvipRewardClaimAt;
  final DateTime? assignedProtectionExpiresAt;
  final int? monthlyRecharge;
  final List<dynamic>? claimedMilestones;
  final List<String> blockedUids;
  final String referralCode;
  final String? referredBy;
  final int totalReferralEarnings;
  final String? partnerUid;
  final String? partnerName;
  final String? partnerAvatar;
  final String? anniversaryDate;
  final int cpLevel;
  final int cpPoints;
  final String? bestFriendUid;
  final String? bestFriendName;
  final String? bestFriendAvatar;
  final int? helloId;
  final int? familyMemberLevel;
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
  final bool isReseller;
  final bool isVerified;
  final String verificationStatus; // 'unverified', 'pending', 'verified', 'rejected'
  final String? idPhotoUrl;
  final double walletBalance;
  final String? activeRoomId;
  final String role;
  final String? branchId;
  final String? superAdminId;
  final String? adminId;
  final double usdCommissionBalance;
  final double pendingWithdrawalBalance;
  final double totalCommissionEarned;
  final double totalRechargeGenerated;
  final double totalWithdrawnUSD;
  final int? monthlyTargetBeans;

UserModel({
    required this.uid,
    required this.createdAt,
    required this.phoneNumber,
    this.email,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.country = '',
    this.profilePhotoUrl = '',
    this.gender = 'female',
    this.diamondBalance = 0,
    this.diamondStock = 0,
    this.beansBalance = 0,
    this.xp = 0,
    this.dailyXP = 0,
    this.weeklyXP = 0,
    this.monthlyXP = 0,
    this.benchXP = 0,
    this.princeXP = 0,
    this.dailyPrinceXP = 0,
    this.weeklyPrinceXP = 0,
    this.monthlyPrinceXP = 0,
    this.level = 1,
    this.followerCount = 0,
    this.followingCount = 0,
    this.friendsCount = 0,
    this.status = 'offline',
    this.badges = const [],
    this.profileFrame = '',
    this.chatBubble = '',
    this.entryAnimation = '',
    this.badgeIcon = '',
    this.equippedCrown = '',
    this.equippedMicWave = '',
    this.profileTheme = '',
    this.prettyId = '',
    this.tags = const [],
    this.vipTier = 'none',
    this.vipExpiry,
    this.nobleTier,
    this.nobleExpiry,
    this.isBanned = false,
    required this.lastActive,
    this.lastVipClaim = '',
    this.lastDailyClaim,

    this.agencyId,
    this.isAgencyOwner = false,
    this.familyId,
    this.isFamilyOwner = false,
    this.svipLevel = 0,
    this.svipPoints = 0,
    this.svipCycleEndDate,
    this.svipCycleStartDate,
    this.lastSvipRewardClaimAt,
    this.assignedProtectionExpiresAt,
    this.monthlyRecharge = 0,
    this.claimedMilestones = const [],
    this.blockedUids = const [],
    this.referralCode = '',
    this.referredBy,
    this.totalReferralEarnings = 0,
    this.partnerUid,
    this.partnerName,
    this.partnerAvatar,
    this.anniversaryDate,
    this.cpLevel = 0,
    this.cpPoints = 0,
    this.combatPoints = 0,
    this.helloId,
    this.familyMemberLevel = 0,
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
    this.isReseller = false,
    this.isVerified = false,
this.verificationStatus = 'unverified',
    this.idPhotoUrl,
    this.walletBalance = 0.0,
    this.activeRoomId,
    this.bestFriendUid,
    this.bestFriendName,
    this.bestFriendAvatar,
    this.role = 'host',
    this.branchId,
    this.superAdminId,
    this.adminId,
    this.usdCommissionBalance = 0.0,
    this.pendingWithdrawalBalance = 0.0,
    this.totalCommissionEarned = 0.0,
    this.totalRechargeGenerated = 0.0,
    this.totalWithdrawnUSD = 0.0,
    this.monthlyTargetBeans,
  });

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

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: (data['uid'] as String?) ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      username: (data['username'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?) ?? '',
      gender: (data['gender'] as String?) ?? 'male',
      diamondBalance: (data['diamondBalance'] as num? ?? 0).toInt(),
      diamondStock: (data['diamondStock'] as num? ?? 0).toInt(),
      beansBalance: (data['beansBalance'] as num? ?? 0).toInt(),
      xp: (data['xp'] as num? ?? 0).toInt(),
      dailyXP: (data['dailyXP'] as num? ?? 0).toInt(),
      weeklyXP: (data['weeklyXP'] as num? ?? 0).toInt(),
      monthlyXP: (data['monthlyXP'] as num? ?? 0).toInt(),
      benchXP: (data['benchXP'] as num? ?? 0).toInt(),
      princeXP: (data['princeXP'] as num? ?? 0).toInt(),
      dailyPrinceXP: (data['dailyPrinceXP'] as num? ?? 0).toInt(),
      weeklyPrinceXP: (data['weeklyPrinceXP'] as num? ?? 0).toInt(),
      monthlyPrinceXP: (data['monthlyPrinceXP'] as num? ?? 0).toInt(),
      level: LevelUtils.calculateLevel((data['xp'] as num? ?? 0).toInt()),
      followerCount: (data['followerCount'] as num? ?? 0).toInt(),
      followingCount: (data['followingCount'] as num? ?? 0).toInt(),
      friendsCount: (data['friendsCount'] as num? ?? 0).toInt(),
      status: (data['status'] as String?) ?? 'offline',
      badges: (data['badges'] as Iterable?)?.whereType<String>().toList() ?? [],
      profileFrame: (data['profileFrame'] as String?) ?? '',
      chatBubble: (data['chatBubble'] as String?) ?? '',
      entryAnimation: (data['entryAnimation'] as String?) ?? '',
      badgeIcon: (data['badgeIcon'] as String?) ?? '',
      equippedCrown: (data['equippedCrown'] as String?) ?? (data['crown'] as String?) ?? (data['badgeIcon'] as String?) ?? '',
      equippedMicWave: (data['equippedMicWave'] as String?) ?? (data['aperture'] as String?) ?? '',
      profileTheme: (data['profileTheme'] as String?) ?? (data['personal_page'] as String?) ?? '',
      prettyId: (data['prettyId'] as String?) ?? (data['id'] as String?) ?? '',
      tags: (data['tags'] as Iterable?)?.whereType<String>().toList() ?? [],
      vipTier: (data['vipTier'] as String?) ?? 'none',
      vipExpiry: data['vipExpiry'] != null ? _parseDateTime(data['vipExpiry']) : null,
      nobleTier: data['nobleTier'] as String?,
      nobleExpiry: data['nobleExpiry'] != null ? _parseDateTime(data['nobleExpiry']) : null,
      isBanned: (data['isBanned'] as bool?) ?? false,
      lastActive: _parseDateTime(data['lastActive']),
      lastVipClaim: (data['lastVipClaim'] as String?) ?? '',
      lastDailyClaim: data['lastDailyClaim'] != null ? _parseDateTime(data['lastDailyClaim']) : null,
      agencyId: data['agencyId'] as String?,
      isAgencyOwner: (data['isAgencyOwner'] as bool?) ?? false,
      familyId: data['familyId'] as String?,
      isFamilyOwner: (data['isFamilyOwner'] as bool?) ?? false,
      svipLevel: (data['svipLevel'] as num?)?.toInt(),
      svipPoints: (data['svipPoints'] as num?)?.toInt(),
      svipCycleEndDate: data['svipCycleEndDate'] != null ? _parseDateTime(data['svipCycleEndDate']) : null,
      svipCycleStartDate: data['svipCycleStartDate'] != null ? _parseDateTime(data['svipCycleStartDate']) : null,
      lastSvipRewardClaimAt: data['lastSvipRewardClaimAt'] != null ? _parseDateTime(data['lastSvipRewardClaimAt']) : null,
      assignedProtectionExpiresAt: data['assignedProtectionExpiresAt'] != null ? _parseDateTime(data['assignedProtectionExpiresAt']) : null,
      monthlyRecharge: (data['monthlyRecharge'] as num?)?.toInt(),
      claimedMilestones: (data['claimedMilestones'] as List?) ?? [],
      blockedUids: (data['blockedUids'] as Iterable?)?.whereType<String>().toList() ?? [],
      referralCode: (data['referralCode'] as String?) ?? (data['uid'] as String? ?? '').split('-').first.toUpperCase(),
      referredBy: data['referredBy'] as String?,
      totalReferralEarnings: (data['totalReferralEarnings'] as num? ?? 0).toInt(),
      partnerUid: data['partnerUid'] as String?,
      partnerName: data['partnerName'] as String?,
      partnerAvatar: data['partnerAvatar'] as String?,
      anniversaryDate: data['anniversaryDate'] as String?,
      cpLevel: (data['cpLevel'] as num? ?? 0).toInt(),
      cpPoints: (data['cpPoints'] as num? ?? 0).toInt(),
      combatPoints: (data['combatPoints'] as num? ?? 0).toInt(),
      helloId: (data['helloId'] as num?)?.toInt(),
      familyMemberLevel: (data['familyMemberLevel'] as num?)?.toInt(),
      visitorCount: (data['visitorCount'] as num? ?? 0).toInt(),
      recentVisitors: (data['recentVisitors'] as Iterable?)?.whereType<String>().toList() ?? [],
      birthday: data['birthday'] != null ? _parseDateTime(data['birthday']) : null,
      height: data['height'] as String?,
      weight: data['weight'] as String?,
      hometown: data['hometown'] as String?,
      languages: (data['languages'] as Iterable?)?.whereType<String>().toList() ?? [],
      ethnicity: data['ethnicity'] as String?,
      personalLabel: data['personalLabel'] as String?,
      company: data['company'] as String?,
      isReseller: (data['isReseller'] as bool?) ?? false,
      isVerified: (data['isVerified'] as bool?) ?? false,
      verificationStatus: (data['verificationStatus'] as String?) ?? 'unverified',
      idPhotoUrl: data['idPhotoUrl'] as String?,
      walletBalance: (data['walletBalance'] as num? ?? 0.0).toDouble(),
      activeRoomId: data['activeRoomId'] as String?,
      bestFriendUid: data['bestFriendUid'] as String?,
      bestFriendName: data['bestFriendName'] as String?,
      bestFriendAvatar: data['bestFriendAvatar'] as String?,
      role: (data['role'] as String?) ?? 'host',
      branchId: data['branchId'] as String?,
      superAdminId: data['superAdminId'] as String?,
      adminId: data['adminId'] as String?,
      usdCommissionBalance: (data['usdCommissionBalance'] as num? ?? 0.0).toDouble(),
      pendingWithdrawalBalance: (data['pendingWithdrawalBalance'] as num? ?? 0.0).toDouble(),
      totalCommissionEarned: (data['totalCommissionEarned'] as num? ?? 0.0).toDouble(),
      totalRechargeGenerated: (data['totalRechargeGenerated'] as num? ?? 0.0).toDouble(),
      totalWithdrawnUSD: (data['totalWithdrawnUSD'] as num? ?? 0.0).toDouble(),
      monthlyTargetBeans: (data['monthlyTargetBeans'] as num?)?.toInt(),
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
      'diamondStock': diamondStock,
      'beansBalance': beansBalance,
      'xp': xp,
      'dailyXP': dailyXP,
      'weeklyXP': weeklyXP,
      'monthlyXP': monthlyXP,
      'benchXP': benchXP,
      'princeXP': princeXP,
      'dailyPrinceXP': dailyPrinceXP,
      'weeklyPrinceXP': weeklyPrinceXP,
      'monthlyPrinceXP': monthlyPrinceXP,
      'level': level,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'status': status,
      'badges': badges,
      'profileFrame': profileFrame,
      'chatBubble': chatBubble,
      'entryAnimation': entryAnimation,
      'badgeIcon': badgeIcon,
      'equippedCrown': equippedCrown,
      'equippedMicWave': equippedMicWave,
      'profileTheme': profileTheme,
      'prettyId': prettyId,
      'tags': tags,
      'vipTier': vipTier,
      'vipExpiry': vipExpiry,
      'nobleTier': nobleTier,
      'nobleExpiry': nobleExpiry,
      'isBanned': isBanned,
      'lastActive': lastActive,
      'lastVipClaim': lastVipClaim,
      'lastDailyClaim': lastDailyClaim,
      'agencyId': agencyId,
      'isAgencyOwner': isAgencyOwner,
      'familyId': familyId,
      'isFamilyOwner': isFamilyOwner,
      'svipLevel': svipLevel,
      'svipPoints': svipPoints,
      'svipCycleEndDate': svipCycleEndDate,
      'svipCycleStartDate': svipCycleStartDate,
      'lastSvipRewardClaimAt': lastSvipRewardClaimAt,
      'assignedProtectionExpiresAt': assignedProtectionExpiresAt,
      'monthlyRecharge': monthlyRecharge,
      'blockedUids': blockedUids,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'totalReferralEarnings': totalReferralEarnings,
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'partnerAvatar': partnerAvatar,
      'anniversaryDate': anniversaryDate,
      'bestFriendUid': bestFriendUid,
      'bestFriendName': bestFriendName,
      'bestFriendAvatar': bestFriendAvatar,
      'cpLevel': cpLevel,
      'cpPoints': cpPoints,
      'combatPoints': combatPoints,
      'helloId': helloId,
      'familyMemberLevel': familyMemberLevel,
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
      'isReseller': isReseller,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'idPhotoUrl': idPhotoUrl,
      'walletBalance': walletBalance,
      'activeRoomId': activeRoomId,
      'role': role,
      'branchId': branchId,
      'superAdminId': superAdminId,
      'adminId': adminId,
      'usdCommissionBalance': usdCommissionBalance,
      'pendingWithdrawalBalance': pendingWithdrawalBalance,
      'totalCommissionEarned': totalCommissionEarned,
      'totalRechargeGenerated': totalRechargeGenerated,
      'totalWithdrawnUSD': totalWithdrawnUSD,
      'monthlyTargetBeans': monthlyTargetBeans,
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
    int? diamondStock,
    int? beansBalance,
    int? xp,
    int? dailyXP,
    int? weeklyXP,
    int? monthlyXP,
    int? benchXP,
    int? princeXP,
    int? dailyPrinceXP,
    int? weeklyPrinceXP,
    int? monthlyPrinceXP,
    int? level,
    int? followerCount,
    int? followingCount,
    int? friendsCount,
    String? status,
    List<String>? badges,
    String? profileFrame,
    String? chatBubble,
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
    DateTime? lastDailyClaim,
    String? agencyId,
    bool? isAgencyOwner,
    String? familyId,
    bool? isFamilyOwner,
    int? svipLevel,
    int? svipPoints,
    DateTime? svipCycleEndDate,
    DateTime? svipCycleStartDate,
    DateTime? lastSvipRewardClaimAt,
    DateTime? assignedProtectionExpiresAt,
    int? monthlyRecharge,
    List<String>? blockedUids,
    String? referralCode,
    String? referredBy,
    int? totalReferralEarnings,
    String? partnerUid,
    String? partnerName,
    String? partnerAvatar,
    String? anniversaryDate,
    String? bestFriendUid,
    String? bestFriendName,
    String? bestFriendAvatar,
    int? cpLevel,
    int? cpPoints,
    int? combatPoints,
    int? helloId,
    int? familyMemberLevel,
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
    bool? isReseller,
    bool? isVerified,
    String? verificationStatus,
    String? idPhotoUrl,
    double? walletBalance,
    String? activeRoomId,
    String? role,
    String? branchId,
    String? superAdminId,
    String? adminId,
    double? usdCommissionBalance,
    double? pendingWithdrawalBalance,
    double? totalCommissionEarned,
    double? totalRechargeGenerated,
    double? totalWithdrawnUSD,
    int? monthlyTargetBeans,
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
      diamondStock: diamondStock ?? this.diamondStock,
      beansBalance: beansBalance ?? this.beansBalance,
      xp: xp ?? this.xp,
      dailyXP: dailyXP ?? this.dailyXP,
      weeklyXP: weeklyXP ?? this.weeklyXP,
      monthlyXP: monthlyXP ?? this.monthlyXP,
      benchXP: benchXP ?? this.benchXP,
      princeXP: princeXP ?? this.princeXP,
      dailyPrinceXP: dailyPrinceXP ?? this.dailyPrinceXP,
      weeklyPrinceXP: weeklyPrinceXP ?? this.weeklyPrinceXP,
      monthlyPrinceXP: monthlyPrinceXP ?? this.monthlyPrinceXP,
      level: level ?? this.level,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      status: status ?? this.status,
      badges: badges ?? this.badges,
      profileFrame: profileFrame ?? this.profileFrame,
      chatBubble: chatBubble ?? this.chatBubble,
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
      lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
      agencyId: agencyId ?? this.agencyId,
      isAgencyOwner: isAgencyOwner ?? this.isAgencyOwner,
      familyId: familyId ?? this.familyId,
      isFamilyOwner: isFamilyOwner ?? this.isFamilyOwner,
      svipLevel: svipLevel ?? this.svipLevel,
      svipPoints: svipPoints ?? this.svipPoints,
      svipCycleEndDate: svipCycleEndDate ?? this.svipCycleEndDate,
      svipCycleStartDate: svipCycleStartDate ?? this.svipCycleStartDate,
      lastSvipRewardClaimAt: lastSvipRewardClaimAt ?? this.lastSvipRewardClaimAt,
      assignedProtectionExpiresAt: assignedProtectionExpiresAt ?? this.assignedProtectionExpiresAt,
      monthlyRecharge: monthlyRecharge ?? this.monthlyRecharge,
      blockedUids: blockedUids ?? this.blockedUids,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalReferralEarnings: totalReferralEarnings ?? this.totalReferralEarnings,
      partnerUid: partnerUid ?? this.partnerUid,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      anniversaryDate: anniversaryDate ?? this.anniversaryDate,
      bestFriendUid: bestFriendUid ?? this.bestFriendUid,
       bestFriendName: bestFriendName ?? this.bestFriendName,
       bestFriendAvatar: bestFriendAvatar ?? this.bestFriendAvatar,
      cpLevel: cpLevel ?? this.cpLevel,
      cpPoints: cpPoints ?? this.cpPoints,
      combatPoints: combatPoints ?? this.combatPoints,
      helloId: helloId ?? this.helloId,
      familyMemberLevel: familyMemberLevel ?? this.familyMemberLevel,
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
      isReseller: isReseller ?? this.isReseller,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      idPhotoUrl: idPhotoUrl ?? this.idPhotoUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      superAdminId: superAdminId ?? this.superAdminId,
      adminId: adminId ?? this.adminId,
      usdCommissionBalance: usdCommissionBalance ?? this.usdCommissionBalance,
      pendingWithdrawalBalance: pendingWithdrawalBalance ?? this.pendingWithdrawalBalance,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
      totalRechargeGenerated: totalRechargeGenerated ?? this.totalRechargeGenerated,
      totalWithdrawnUSD: totalWithdrawnUSD ?? this.totalWithdrawnUSD,
      monthlyTargetBeans: monthlyTargetBeans ?? this.monthlyTargetBeans,
    );
  }

  bool get isAdmin => tags.contains('Admin') || tags.contains('SuperAdmin') || role == 'admin' || role == 'superadmin' || role == 'owner';
  bool get isSuperAdmin => role == 'superadmin' || tags.contains('SuperAdmin');
  bool get isOwner => role == 'owner' || tags.contains('Owner');
  bool get isAdminRole => role == 'admin' || tags.contains('Admin');
  bool get isAgencyRole => role == 'agency' || isAgencyOwner || tags.contains('Agency');

  bool get isVipActive {
    if (vipTier == 'none' || vipTier.isEmpty) return false;
    if (vipExpiry == null) return false;
    return vipExpiry!.isAfter(DateTime.now());
  }

  int get vipRemainingDays {
    if (!isVipActive || vipExpiry == null) return 0;
    return vipExpiry!.difference(DateTime.now()).inDays.clamp(0, 30);
  }

  String get vipRemainingDaysText {
    if (!isVipActive || vipExpiry == null) return 'Expired';
    final days = vipRemainingDays;
    if (days <= 0) return 'Expired';
    if (days == 1) return '1 Day';
    return '$days Days';
  }

  bool get isNobleActive {
    if (nobleTier == null || nobleTier!.isEmpty) return false;
    if (nobleExpiry == null) return false;
    return nobleExpiry!.isAfter(DateTime.now());
  }

  int get nobleRemainingDays {
    if (!isNobleActive || nobleExpiry == null) return 0;
    return nobleExpiry!.difference(DateTime.now()).inDays.clamp(0, 30);
  }

  bool get isSvipProtected {
    final now = DateTime.now();
    final isLevelProtected = (svipLevel ?? 0) >= 4 && (svipCycleEndDate == null || svipCycleEndDate!.isAfter(now));
    final isAssigned = assignedProtectionExpiresAt != null && assignedProtectionExpiresAt!.isAfter(now);
    return isLevelProtected || isAssigned;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }

  String get displayId => helloId != null 
    ? helloId.toString().padLeft(10, '0') 
    : "Pending...";
}
