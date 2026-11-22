import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/services/cloudinary_service.dart';
import 'package:hello_chat/core/services/base_firebase_service.dart';

final giftServiceProvider = Provider<GiftService>((ref) {
  return GiftService(ref.read(cloudinaryServiceProvider));
});

final giftsStreamProvider = StreamProvider<List<GiftModel>>((ref) {
  return ref.watch(giftServiceProvider).getGiftsStream();
});

class GiftService extends BaseFirebaseService {
  final CloudinaryService _cloudinary;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GiftService(this._cloudinary);

  static final List<GiftModel> defaultGiftCatalog = [
    // Page 1 (Image 5)
    GiftModel(
      giftId: 'special_offer',
      name: 'Special Offer',
      priceInDiamonds: 0,
      category: 'Normal',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/vap_gift_17.png',
      lottieAssetPath: 'assets/gifts-vap/gift_17.vap',
      animationFormat: 'vap',
      durationMs: 6833,
      sortOrder: 1,
      isActive: true,
    ),
    GiftModel(
      giftId: 'lucky_coin',
      name: 'Lucky Coin',
      priceInDiamonds: 800,
      category: 'Lucky',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/vap_gift_11.png',
      lottieAssetPath: 'assets/gifts-vap/gift_11.vap',
      animationFormat: 'vap',
      durationMs: 6000,
      sortOrder: 2,
      isActive: true,
    ),
    GiftModel(
      giftId: 'lucky_key',
      name: 'Lucky Key',
      priceInDiamonds: 2000,
      category: 'Lucky',
      tier: 'MEDIUM',
      imageUrl: 'assets/images/gifts/vap_gift_15.png',
      lottieAssetPath: 'assets/gifts-vap/gift_15.vap',
      animationFormat: 'vap',
      durationMs: 10000,
      sortOrder: 3,
      isActive: true,
    ),
    GiftModel(
      giftId: 'beast_showdown',
      name: 'Beast Showdown',
      priceInDiamonds: 750000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/vap_gift_14.png',
      lottieAssetPath: 'assets/gifts-vap/gift_14.vap',
      animationFormat: 'vap',
      durationMs: 13000,
      sortOrder: 4,
      isActive: true,
    ),
    GiftModel(
      giftId: 'star_sticks',
      name: 'Star Sticks',
      priceInDiamonds: 200,
      category: 'Normal',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/golden_bell.png',
      lottieAssetPath: 'assets/animations/lottie/Celebration.json',
      animationFormat: 'json',
      durationMs: 3000,
      sortOrder: 5,
      isActive: true,
    ),
    GiftModel(
      giftId: 'cake',
      name: 'Cake',
      priceInDiamonds: 200,
      category: 'Normal',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/gourmet_feast.png',
      lottieAssetPath: 'assets/animations/lottie/pink cake.json',
      animationFormat: 'json',
      durationMs: 4000,
      sortOrder: 6,
      isActive: true,
    ),
    GiftModel(
      giftId: 'fly_heart',
      name: 'Fly Heart',
      priceInDiamonds: 200,
      category: 'Normal',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/love_you.png',
      lottieAssetPath: 'assets/animations/gifts/Love You.svga',
      animationFormat: 'svga',
      durationMs: 5000,
      sortOrder: 7,
      isActive: true,
    ),
    GiftModel(
      giftId: 'kiss',
      name: 'Kiss',
      priceInDiamonds: 5000,
      category: 'Normal',
      tier: 'NORMAL',
      imageUrl: 'assets/images/gifts/vap_gift_4.png',
      lottieAssetPath: 'assets/gifts-vap/gift_4.vap',
      animationFormat: 'vap',
      durationMs: 5000,
      sortOrder: 8,
      isActive: true,
    ),
    // Page 2 (Image 4)
    GiftModel(
      giftId: 'neon_supercar',
      name: 'Neon Supercar',
      priceInDiamonds: 500000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/vap_gift_1.png',
      lottieAssetPath: 'assets/animations/lottie/Red Car.json',
      animationFormat: 'json',
      durationMs: 5000,
      sortOrder: 9,
      isActive: true,
    ),
    GiftModel(
      giftId: 'crystal_slipper',
      name: 'Crystal Slipper',
      priceInDiamonds: 125000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/crystal_princess.png',
      lottieAssetPath: 'assets/svga/100_optimized.svga',
      animationFormat: 'svga',
      durationMs: 6000,
      sortOrder: 10,
      isActive: true,
    ),
    GiftModel(
      giftId: 'precious_necklace',
      name: 'Precious Necklace',
      priceInDiamonds: 250000,
      category: 'Medium',
      tier: 'MEDIUM',
      imageUrl: 'assets/images/gifts/crystal_windchime.png',
      lottieAssetPath: 'assets/svga/mystic_rings.svga',
      animationFormat: 'svga',
      durationMs: 5000,
      sortOrder: 11,
      isActive: true,
    ),
    GiftModel(
      giftId: 'masquerade_queen',
      name: 'Masquerade Queen',
      priceInDiamonds: 750000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/vap_gift_8.png',
      lottieAssetPath: 'assets/svga/235.svga',
      animationFormat: 'svga',
      durationMs: 8000,
      sortOrder: 12,
      isActive: true,
    ),
    GiftModel(
      giftId: 'treasure_adventure',
      name: 'Treasure Adventure',
      priceInDiamonds: 750000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/vap_gift_7.png',
      lottieAssetPath: 'assets/gifts-vap/gift_7.vap',
      animationFormat: 'vap',
      durationMs: 10000,
      sortOrder: 13,
      isActive: true,
    ),
    GiftModel(
      giftId: 'diamond_balloon',
      name: 'Diamond Balloon',
      priceInDiamonds: 1000000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/sweet_romance.png',
      lottieAssetPath: 'assets/animations/lottie/balloon.json',
      animationFormat: 'json',
      durationMs: 4000,
      sortOrder: 14,
      isActive: true,
    ),
    GiftModel(
      giftId: 'eternal_love',
      name: 'Eternal Love',
      priceInDiamonds: 750000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/love_you.png',
      lottieAssetPath: 'assets/gifts-vap/gift_18.vap',
      animationFormat: 'vap',
      durationMs: 6875,
      sortOrder: 15,
      isActive: true,
    ),
    GiftModel(
      giftId: 'romantic_journey',
      name: 'Romantic Journey',
      priceInDiamonds: 2000000,
      category: 'Luxury',
      tier: 'LUXURY',
      imageUrl: 'assets/images/gifts/vap_gift_16.png',
      lottieAssetPath: 'assets/gifts-vap/gift_16.vap',
      animationFormat: 'vap',
      durationMs: 10000,
      sortOrder: 16,
      isActive: true,
    ),
  ];

  Stream<List<GiftModel>> getGiftsStream() {
    return _db
        .collection('gifts')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return defaultGiftCatalog;
      }
      final list = snapshot.docs
          .map((doc) => GiftModel.fromMap(doc.data(), doc.id))
          .toList();
      final existingIds = list.map((g) => g.giftId.toLowerCase()).toSet();
      for (final def in defaultGiftCatalog) {
        if (!existingIds.contains(def.giftId.toLowerCase())) {
          list.add(def);
        }
      }
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }

  /// Migrates local assets to Cloudinary and saves to Firestore
  Future<void> migrateLocalGiftsToCloudinary() async {
    final List<Map<String, dynamic>> localGifts = [
      {
        'id': 'rose',
        'name': 'Rose',
        'price': 50,
        'cat': 'Relationship',
        'img': '🌹',
        'file': 'Rose.json'
      },
      {
        'id': 'balloon',
        'name': 'Balloon',
        'price': 0,
        'cat': 'Gift',
        'img': '🎈',
        'file': 'balloon.json'
      },
      {
        'id': 'cake',
        'name': 'Celebration Cake',
        'price': 300,
        'cat': 'Gift',
        'img': '🎂',
        'file': 'pink cake.json'
      },
      {
        'id': 'lucky_star',
        'name': 'Lucky Star',
        'price': 200,
        'cat': 'Lucky',
        'img': '⭐',
        'file': 'Celebration.json'
      },
      {
        'id': 'lucky_bell',
        'name': 'Lucky Dates',
        'price': 1000,
        'cat': 'Lucky',
        'img': 'assets/lucky gift dates/icon.png',
        'file': 'assets/lucky gift dates/video.mp4',
        'format': 'mp4'
      },
      {
        'id': 'lucky_chest',
        'name': 'Lucky Chest',
        'price': 100000,
        'cat': 'Lucky',
        'img': '🧰',
        'file': 'Celebration.json'
      },
      {
        'id': 'lucky_fruit',
        'name': 'Lucky Fruit',
        'price': 500,
        'cat': 'Lucky fruit',
        'img': '🍉',
        'file': 'Celebration.json'
      },
      {
        'id': 'car_king',
        'name': 'Car King',
        'price': 400000,
        'cat': 'Luxury',
        'img': '🏎️',
        'file': 'Red Car.json'
      },
      {
        'id': 'crown',
        'name': 'Gold Crown',
        'price': 1000,
        'cat': 'VIP',
        'img': '👑',
        'file': 'Premium Gold.json'
      },
      {
        'id': 'rocket',
        'name': 'Rocket',
        'price': 5000,
        'cat': 'Luxury',
        'img': '🚀',
        'file': 'Rocket loader.json'
      },
      // ── SVGA Premium Gifts ─────────────────────────────────
      {
        'id': 'mystic_rings',
        'name': 'Mystic Rings',
        'price': 1200,
        'cat': 'Relationship',
        'img': '💍',
        'file': 'mystic_rings.svga'
      },
      {
        'id': 'royal_carriage',
        'name': 'Royal Carriage',
        'price': 8000,
        'cat': 'SVIP',
        'img': '🎠',
        'file': '235.svga'
      },
      {
        'id': 'crystal_palace',
        'name': 'Crystal Palace',
        'price': 15000,
        'cat': 'SVIP',
        'img': '🏰',
        'file': '100_optimized.svga'
      },
    ];

    final tempDir = await getTemporaryDirectory();
    final batch = _db.batch();

    // Clear old gifts
    final oldGifts = await _db.collection('gifts').get();
    for (var doc in oldGifts.docs) {
      batch.delete(doc.reference);
    }

    int order = 1;
    for (var g in localGifts) {
      // 1. Load from assets
      final fileStr = g['file'] as String;
      final isSvga = fileStr.endsWith('.svga');
      final isMp4 = fileStr.endsWith('.mp4');
      final assetPath = fileStr.contains('/')
          ? fileStr
          : (isSvga
              ? 'assets/svga/$fileStr'
              : 'assets/animations/lottie/$fileStr');
      final byteData = await rootBundle.load(assetPath);
      final fileName = fileStr.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // 2. Upload to Cloudinary
      final animUrl =
          await _cloudinary.uploadRaw(file.path, folder: "gifts/animations");

      // Handle image upload if local asset
      String imageUrl = g['img'] as String;
      if (imageUrl.startsWith('assets/')) {
        try {
          final imgData = await rootBundle.load(imageUrl);
          final imgName = imageUrl.split('/').last;
          final imgFile = File('${tempDir.path}/$imgName');
          await imgFile.writeAsBytes(imgData.buffer
              .asUint8List(imgData.offsetInBytes, imgData.lengthInBytes));
          imageUrl = await _cloudinary.uploadImage(imgFile.path,
              folder: "gifts/icons");
        } catch (_) {}
      }

      // 3. Create Model
      final gift = GiftModel(
        giftId: g['id'],
        name: g['name'],
        priceInDiamonds: g['price'],
        category: g['cat'],
        imageUrl: imageUrl,
        lottieAssetPath: animUrl,
        animationFormat: (g['format'] as String?) ??
            (isMp4
                ? 'mp4'
                : isSvga
                    ? 'svga'
                    : 'json'),
        sortOrder: order++,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Add to batch
      batch.set(_db.collection('gifts').doc(gift.giftId), gift.toMap());
    }

    await batch.commit();
  }

  Future<void> feedSampleGifts() async {
    // Deprecated in favor of migrateLocalGiftsToCloudinary for local assets
    await migrateLocalGiftsToCloudinary();
  }

  Future<List<Map<String, dynamic>>> sendGift({
    required String roomId,
    required GiftModel gift,
    required List<String> targetUids,
    int quantity = 1,
    bool isMoment = false,
    int comboCount = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated.");

    // Retrieve cached token instantly instead of forcing slow network refresh
    await user.getIdToken(false);

    // 🛑 ONE call for every receiver. Fanning out with a call per target made N
    // transactions contend on the sender's balance document, so the room stalled
    // and a timeout could charge some receivers but not others. The server now
    // bills and credits the whole set in a single atomic transaction.
    final raw = await callFunction('sendGiftWithCombo', {
      'roomId': roomId,
      'giftId': gift.giftId,
      'targetUids': targetUids,
      'quantity': quantity,
      'isMoment': isMoment,
      'comboCount': comboCount,
    });

    final envelope = Map<String, dynamic>.from(raw as Map? ?? {});
    final perTarget = (envelope['perTarget'] as List? ?? const [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    // Older deployed shapes have no perTarget array; treat the whole payload as
    // the single result so a stale client can't swallow a real send.
    final results = perTarget.isNotEmpty ? perTarget : [envelope];

    // PK Battle Integration: Update scores if target is on a PK team
    if (!isMoment) {
      for (var targetUid in targetUids) {
        _updatePKScore(roomId, targetUid, gift.priceInDiamonds * quantity);
      }
    }

    return results;
  }

  Future<void> _updatePKScore(
      String roomId, String targetUid, int points) async {
    try {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return;
      final roomData = roomDoc.data()!;
      if (roomData['pkActive'] != true) return;

      final pkTeams = Map<String, dynamic>.from(roomData['pkTeams'] ?? {});
      final side = pkTeams[targetUid];
      if (side == null) return;

      final pkScores = Map<String, dynamic>.from(roomData['pkScores'] ?? {});
      String? hostUid;

      // Find the score-key (host) associated with this side
      for (var uid in pkScores.keys) {
        if (pkTeams[uid] == side) {
          hostUid = uid;
          break;
        }
      }

      if (hostUid != null) {
        await _db.collection('rooms').doc(roomId).update({
          'pkScores.$hostUid': FieldValue.increment(points),
        });
      }
    } catch (e) {
      debugPrint("Error updating PK score: $e");
    }
  }

  Future<List<GiftModel>> getGiftsFuture() async {
    final snapshot = await _db
        .collection('gifts')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .get();
    if (snapshot.docs.isEmpty) {
      return defaultGiftCatalog;
    }
    final list = snapshot.docs
        .map((doc) => GiftModel.fromMap(doc.data(), doc.id))
        .toList();
    final existingIds = list.map((g) => g.giftId.toLowerCase()).toSet();
    for (final def in defaultGiftCatalog) {
      if (!existingIds.contains(def.giftId.toLowerCase())) {
        list.add(def);
      }
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<Map<String, dynamic>> sendLuckyBag({
    required String roomId,
    required int totalDiamonds,
    required int winnerCount,
    String? message,
    String mode = 'instant',
    int scheduleMinutes = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated.");
    await user.getIdToken(false);

    final result = await callFunction('sendLuckyBag', {
      'roomId': roomId,
      'totalDiamonds': totalDiamonds,
      'winnerCount': winnerCount,
      'message': message ?? "Join and claim your Lucky Bag!",
      'mode': mode,
      'scheduleMinutes': scheduleMinutes,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> claimLuckyBag({
    required String bagId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated.");
    await user.getIdToken(false);

    final result = await callFunction('claimLuckyBag', {
      'bagId': bagId,
    });
    return Map<String, dynamic>.from(result);
  }
}
