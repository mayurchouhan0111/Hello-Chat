import 'package:cloud_firestore/cloud_firestore.dart';

class GiftModel {
  final String giftId;
  final String name;
  final int priceInDiamonds;
  final String category; // "small", "luxury", "special"
  final String imageUrl; // Icon URL from Firebase/Cloudinary
  final String lottieAssetPath; // Animation URL or path
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
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory GiftModel.fromMap(Map<String, dynamic> map, String docId) {
    return GiftModel(
      giftId: docId,
      name: map['name'] ?? '',
      priceInDiamonds: map['priceInDiamonds'] ?? 0,
      category: map['category'] ?? 'small',
      imageUrl: map['imageUrl'] ?? '',
      lottieAssetPath: map['lottieAssetPath'] ?? '',
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
