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
  final String status;
  final List<String> badges;
  final String profileFrame;
  final String entryAnimation;
  final List<String> tags;
  final String vipTier;
  final DateTime? vipExpiry;
  final bool isBanned;
  final DateTime lastActive;

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
    required this.status,
    required this.badges,
    required this.profileFrame,
    required this.entryAnimation,
    required this.tags,
    required this.vipTier,
    this.vipExpiry,
    required this.isBanned,
    required this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      bio: data['bio'] ?? '',
      country: data['country'] ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] ?? '',
      gender: data['gender'] ?? 'male',
      diamondBalance: data['diamondBalance'] ?? 0,
      beansBalance: data['beansBalance'] ?? 0,
      xp: data['xp'] ?? 0,
      benchXP: data['benchXP'] ?? 0,
      princeXP: data['princeXP'] ?? 0,
      level: data['level'] ?? 1,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      status: data['status'] ?? 'offline',
      badges: List<String>.from(data['badges'] ?? []),
      profileFrame: data['profileFrame'] ?? '',
      entryAnimation: data['entryAnimation'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      vipTier: data['vipTier'] ?? 'none',
      vipExpiry: data['vipExpiry'] != null 
          ? (data['vipExpiry'] as Timestamp).toDate() 
          : null,
      isBanned: data['isBanned'] ?? false,
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate() 
          : DateTime.now(),
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
      'status': status,
      'badges': badges,
      'profileFrame': profileFrame,
      'entryAnimation': entryAnimation,
      'tags': tags,
      'vipTier': vipTier,
      'vipExpiry': vipExpiry,
      'isBanned': isBanned,
      'lastActive': lastActive,
    };
  }
}
