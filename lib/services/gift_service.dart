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

  Stream<List<GiftModel>> getGiftsStream() {
    return _db.collection('gifts')
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => GiftModel.fromMap(doc.data(), doc.id)).toList());
  }

  /// Migrates local assets to Cloudinary and saves to Firestore
  Future<void> migrateLocalGiftsToCloudinary() async {
    final List<Map<String, dynamic>> localGifts = [
      {'id': 'rose', 'name': 'Rose', 'price': 50, 'cat': 'Relationship', 'img': '🌹', 'file': 'Rose.json'},
      {'id': 'balloon', 'name': 'Balloon', 'price': 0, 'cat': 'Gift', 'img': '🎈', 'file': 'balloon.json'},
      {'id': 'cake', 'name': 'Celebration Cake', 'price': 300, 'cat': 'Gift', 'img': '🎂', 'file': 'pink cake.json'},
      {'id': 'lucky_star', 'name': 'Lucky Star', 'price': 200, 'cat': 'Lucky', 'img': '⭐', 'file': 'Celebration.json'},
      {'id': 'lucky_bell', 'name': 'Lucky Dates', 'price': 1000, 'cat': 'Lucky', 'img': 'assets/lucky gift dates/icon.png', 'file': 'assets/lucky gift dates/video.mp4', 'format': 'mp4'},
      {'id': 'lucky_chest', 'name': 'Lucky Chest', 'price': 100000, 'cat': 'Lucky', 'img': '🧰', 'file': 'Celebration.json'},
      {'id': 'lucky_fruit', 'name': 'Lucky Fruit', 'price': 500, 'cat': 'Lucky fruit', 'img': '🍉', 'file': 'Celebration.json'},
      {'id': 'car_king', 'name': 'Car King', 'price': 400000, 'cat': 'Luxury', 'img': '🏎️', 'file': 'Red Car.json'},
      {'id': 'crown', 'name': 'Gold Crown', 'price': 1000, 'cat': 'VIP', 'img': '👑', 'file': 'Premium Gold.json'},
      {'id': 'rocket', 'name': 'Rocket', 'price': 5000, 'cat': 'Luxury', 'img': '🚀', 'file': 'Rocket loader.json'},
      // ── SVGA Premium Gifts ─────────────────────────────────
      {'id': 'mystic_rings', 'name': 'Mystic Rings', 'price': 1200, 'cat': 'Relationship', 'img': '💍', 'file': 'mystic_rings.svga'},
      {'id': 'royal_carriage', 'name': 'Royal Carriage', 'price': 8000, 'cat': 'SVIP', 'img': '🎠', 'file': '235.svga'},
      {'id': 'crystal_palace', 'name': 'Crystal Palace', 'price': 15000, 'cat': 'SVIP', 'img': '🏰', 'file': '100_optimized.svga'},
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
          : (isSvga ? 'assets/svga/$fileStr' : 'assets/animations/lottie/$fileStr');
      final byteData = await rootBundle.load(assetPath);
      final fileName = fileStr.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // 2. Upload to Cloudinary
      final animUrl = await _cloudinary.uploadRaw(file.path, folder: "gifts/animations");

      // Handle image upload if local asset
      String imageUrl = g['img'] as String;
      if (imageUrl.startsWith('assets/')) {
        try {
          final imgData = await rootBundle.load(imageUrl);
          final imgName = imageUrl.split('/').last;
          final imgFile = File('${tempDir.path}/$imgName');
          await imgFile.writeAsBytes(imgData.buffer.asUint8List(imgData.offsetInBytes, imgData.lengthInBytes));
          imageUrl = await _cloudinary.uploadImage(imgFile.path, folder: "gifts/icons");
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
        animationFormat: (g['format'] as String?) ?? (isMp4 ? 'mp4' : isSvga ? 'svga' : 'json'),
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


  Future<void> _updatePKScore(String roomId, String targetUid, int points) async {
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
    final snapshot = await _db.collection('gifts')
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder', descending: false)
      .get();
    return snapshot.docs.map((doc) => GiftModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<Map<String, dynamic>> sendLuckyBag({
    required String roomId,
    required int totalDiamonds,
    required int winnerCount,
    String? message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated.");
    await user.getIdToken(false);

    final result = await callFunction('sendLuckyBag', {
      'roomId': roomId,
      'totalDiamonds': totalDiamonds,
      'winnerCount': winnerCount,
      'message': message ?? "Join and claim your Lucky Bag!",
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
