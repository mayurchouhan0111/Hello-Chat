import 'package:cloud_firestore/cloud_firestore.dart';

class VIPTierModel {
  final String tierId;
  final String name;
  final int level;
  final int monthlyPriceInDiamonds;
  final double monthlyPriceInUSD;
  final List<String> benefits;
  final String profileFrame;
  final String entryAnimation;
  final String badgeIcon;
  final bool priorityMicAccess;
  final bool isActive;
  final int sortOrder;

  VIPTierModel({
    required this.tierId,
    required this.name,
    required this.level,
    required this.monthlyPriceInDiamonds,
    required this.monthlyPriceInUSD,
    required this.benefits,
    required this.profileFrame,
    required this.entryAnimation,
    required this.badgeIcon,
    required this.priorityMicAccess,
    required this.isActive,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'tierId': tierId,
      'name': name,
      'level': level,
      'monthlyPriceInDiamonds': monthlyPriceInDiamonds,
      'monthlyPriceInUSD': monthlyPriceInUSD,
      'benefits': benefits,
      'profileFrame': profileFrame,
      'entryAnimation': entryAnimation,
      'badgeIcon': badgeIcon,
      'priorityMicAccess': priorityMicAccess,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  factory VIPTierModel.fromMap(Map<String, dynamic> map) {
    return VIPTierModel(
      tierId: map['tierId'] ?? '',
      name: map['name'] ?? '',
      level: map['level'] ?? 0,
      monthlyPriceInDiamonds: map['monthlyPriceInDiamonds'] ?? 0,
      monthlyPriceInUSD: (map['monthlyPriceInUSD'] ?? 0).toDouble(),
      benefits: List<String>.from(map['benefits'] ?? []),
      profileFrame: map['profileFrame'] ?? '',
      entryAnimation: map['entryAnimation'] ?? '',
      badgeIcon: map['badgeIcon'] ?? '',
      priorityMicAccess: map['priorityMicAccess'] ?? false,
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  factory VIPTierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VIPTierModel.fromMap(data);
  }
}
