import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyModel {
  final String id;
  final String name;
  final String ownerUid;
  final String ownerName;
  final String logoUrl;
  final String description;
  final List<String> hostUids;
  final double commissionRate; // 0.30 = 30% recharge commission
  final int totalBeansEarned;
  final int beansBalance;
  final double usdCommissionBalance;
  final double totalCommissionEarned;
  final double totalRechargeGenerated;
  final DateTime createdAt;

  final bool isActive;

  AgencyModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.ownerName,
    this.logoUrl = '',
    this.description = '',
    this.hostUids = const [],
    this.commissionRate = 0.30,
    this.totalBeansEarned = 0,
    this.beansBalance = 0,
    this.usdCommissionBalance = 0,
    this.totalCommissionEarned = 0,
    this.totalRechargeGenerated = 0,
    required this.createdAt,
    this.isActive = true,
  });

  factory AgencyModel.fromMap(Map<String, dynamic> map, String id) {
    return AgencyModel(
      id: id,
      name: map['name'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      ownerName: map['ownerName'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      description: map['description'] ?? '',
      hostUids: List<String>.from(map['hostUids'] ?? []),
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.30,
      totalBeansEarned: map['totalBeansEarned'] ?? 0,
      beansBalance: map['beansBalance'] ?? 0,
      usdCommissionBalance:
          (map['usdCommissionBalance'] as num? ?? 0).toDouble(),
      totalCommissionEarned:
          (map['totalCommissionEarned'] as num? ?? 0).toDouble(),
      totalRechargeGenerated:
          (map['totalRechargeGenerated'] as num? ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'logoUrl': logoUrl,
      'description': description,
      'hostUids': hostUids,
      'commissionRate': commissionRate,
      'totalBeansEarned': totalBeansEarned,
      'beansBalance': beansBalance,
      'usdCommissionBalance': usdCommissionBalance,
      'totalCommissionEarned': totalCommissionEarned,
      'totalRechargeGenerated': totalRechargeGenerated,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
