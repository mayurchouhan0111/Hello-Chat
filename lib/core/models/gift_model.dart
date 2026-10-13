import 'package:cloud_firestore/cloud_firestore.dart';

class GiftModel {
  final String giftId;
  final String name;
  final int priceInDiamonds;
  final String category; // shelf tab: "Normal", "Lucky", "Medium", "Luxury", "CP", "Custom", "Family Battle", "VIP", "SVIP"
  final String imageUrl; // Icon URL from Firebase/Storage
  final String lottieAssetPath; // Animation URL or path
  final String soundUrl; // Audio URL for gift sound effect
  final String animationFormat; // "json", "svga", "mp4", "vpa", "pag", "image", "sound"
  final String tier; // animation layer override: "" (derive from category) | "NORMAL" | "MEDIUM" | "LUXURY"
  final int durationMs; // 0 = derive from asset / format default
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
    this.tier = '',
    this.durationMs = 0,
    this.minSvipLevel = 0,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Which overlay layer this gift plays on: NORMAL (seat-anchored),
  /// MEDIUM (mid-ground) or LUXURY (full-screen cinematic).
  ///
  /// An explicit `tier` field wins; otherwise it is derived from `category`
  /// so existing gift docs need no migration.
  String get animationTier {
    final t = tier.trim().toUpperCase();
    if (t == 'NORMAL' || t == 'MEDIUM' || t == 'LUXURY') return t;
    final c = category.trim().toUpperCase();
    if (c == 'MEDIUM') return 'MEDIUM';
    if (c == 'LUXURY') return 'LUXURY';
    if (c == 'SVGA' || c == 'VAP') return 'MEDIUM';
    return 'NORMAL';
  }

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
      'tier': tier,
      'durationMs': durationMs,
      'minSvipLevel': minSvipLevel,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory GiftModel.fromMap(Map<String, dynamic> map, String docId) {
    final assetPath = (map['lottieAssetPath'] ?? map['animation_url'])?.toString() ?? '';
    final lowerAsset = assetPath.toLowerCase();
    String format = (map['animationFormat'] ?? map['animation_type'])?.toString() ?? '';

    // Auto-detect format from asset path or known gift IDs if missing or incorrectly defaulted to 'json'
    if (format.isEmpty || format == 'json') {
      if (lowerAsset.contains('.svga') ||
          docId == 'mystic_rings' ||
          docId == 'crystal_palace' ||
          docId == 'royal_carriage' ||
          docId == 'cat_gift') {
        format = 'svga';
      } else if (lowerAsset.contains('.mp4') ||
          lowerAsset.contains('.vap') ||
          lowerAsset.contains('.vpa') ||
          lowerAsset.contains('.pag')) {
        format = 'vap';
      } else if (lowerAsset.contains('.png') ||
          lowerAsset.contains('.jpg') ||
          lowerAsset.contains('.jpeg') ||
          lowerAsset.contains('.webp')) {
        format = 'image';
      } else if (format.isEmpty) {
        format = 'json';
      }
    }

    String tierVal = map['tier']?.toString() ?? '';
    if (tierVal.isEmpty) {
      if (docId == 'car_king' ||
          docId == 'crystal_palace' ||
          docId == 'royal_carriage' ||
          docId == 'rocket' ||
          docId == 'bDMkvLHqDMRVvoXonxLn' ||
          docId == 'PZjkxr8gMffDYFJ4qsAE' ||
          docId == 'klpyoRCQMkbibDPlRe5G' ||
          docId == 'vEgsWq5deTbzuyvSloCG') {
        tierVal = 'LUXURY';
      }
    }

    return GiftModel(
      giftId: docId,
      name: map['name']?.toString() ?? '',
      priceInDiamonds: (map['priceInDiamonds'] ?? map['price_diamonds'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? 'Normal',
      imageUrl: map['imageUrl']?.toString() ?? '',
      // `animation_url` / `animation_type` / `duration_ms` are spec aliases
      // accepted for docs hand-written to the documented schema.
      lottieAssetPath: assetPath,
      soundUrl: map['soundUrl']?.toString() ?? '',
      animationFormat: format,
      tier: tierVal,
      durationMs: (map['durationMs'] ?? map['duration_ms'] as num?)?.toInt() ?? 0,
      minSvipLevel: (map['minSvipLevel'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] == true,
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
