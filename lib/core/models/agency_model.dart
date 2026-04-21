import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyModel {
  final String id;
  final String name;
  final String ownerUid;
  final String ownerName;
  final String logoUrl;
  final String description;
  final List<String> hostUids;
  final double commissionRate; // e.g. 0.1 for 10%
  final int totalBeansEarned;
  final int beansBalance;
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
    this.commissionRate = 0.1,
    this.totalBeansEarned = 0,
    this.beansBalance = 0,
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
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.1,
      totalBeansEarned: map['totalBeansEarned'] ?? 0,
      beansBalance: map['beansBalance'] ?? 0,
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
      'createdAt': Timestamp.fromDate(createdAt),

      'isActive': isActive,
    };
  }
}
