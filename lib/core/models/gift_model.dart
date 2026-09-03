import 'package:cloud_firestore/cloud_firestore.dart';

class GiftModel {
  final String giftId;
  final String name;
  final int priceInDiamonds;
  final String category; // "Normal", "Luxury", "Lucky", "VIP", "SVIP"
  final String imageUrl; // Icon URL from Firebase/Storage
  final String lottieAssetPath; // Animation URL or path
  final String soundUrl; // Audio URL for gift sound effect
  final String animationFormat; // "json", "svga", "mp4", "vpa", "image", "sound"
  final int minSvipLevel;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GiftModel({
    required this.giftId,
    required this.name,
    required this.priceInDiamonds,
    required this.category,
    required this.imageUrl,
    required this.lottieAssetPath,
    this.soundUrl = '',
    this.animationFormat = 'json',
    this.minSvipLevel = 0,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'giftId': giftId,
      'name': name,
      'priceInDiamonds': priceInDiamonds,
      'category': category,
      'imageUrl': imageUrl,
      'lottieAssetPath': lottieAssetPath,
      'soundUrl': soundUrl,
      'animationFormat': animationFormat,
      'minSvipLevel': minSvipLevel,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory GiftModel.fromMap(Map<String, dynamic> map, String docId) {
    return GiftModel(
      giftId: docId,
      name: map['name']?.toString() ?? '',
      priceInDiamonds: (map['priceInDiamonds'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? 'Normal',
      imageUrl: map['imageUrl']?.toString() ?? '',
      lottieAssetPath: map['lottieAssetPath']?.toString() ?? '',
      soundUrl: map['soundUrl']?.toString() ?? '',
      animationFormat: map['animationFormat']?.toString() ?? 'json',
      minSvipLevel: (map['minSvipLevel'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] == true,
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
