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
  final String backgroundImage;
  final String themeColor; // Hex String (e.g., #10B981)
  final String entryRequirement; // Recharge condition
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
    required this.backgroundImage,
    required this.themeColor,
    required this.entryRequirement,
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
      'backgroundImage': backgroundImage,
      'themeColor': themeColor,
      'entryRequirement': entryRequirement,
      'priorityMicAccess': priorityMicAccess,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  factory VIPTierModel.fromMap(Map<String, dynamic> map) {
    return VIPTierModel(
      tierId: (map['tierId'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'VIP',
      level: (map['level'] as num?)?.toInt() ?? 0,
      monthlyPriceInDiamonds: (map['monthlyPriceInDiamonds'] as num?)?.toInt() ?? 0,
      monthlyPriceInUSD: (map['monthlyPriceInUSD'] as num?)?.toDouble() ?? 0.0,
      benefits: (map['benefits'] as Iterable?)?.whereType<String>().toList() ?? [],
      profileFrame: (map['profileFrame'] as String?) ?? '',
      entryAnimation: (map['entryAnimation'] as String?) ?? '',
      badgeIcon: (map['badgeIcon'] as String?) ?? '',
      backgroundImage: (map['backgroundImage'] as String?) ?? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      themeColor: (map['themeColor'] as String?) ?? '#10B981',
      entryRequirement: (map['entryRequirement'] as String?) ?? 'Recharge monthly price',
      priorityMicAccess: (map['priorityMicAccess'] as bool?) ?? false,
      isActive: (map['isActive'] as bool?) ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }



  factory VIPTierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VIPTierModel.fromMap({...data, 'tierId': doc.id});
  }
}
