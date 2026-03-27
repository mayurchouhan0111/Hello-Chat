import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/services/cloudinary_service.dart';

final giftServiceProvider = Provider<GiftService>((ref) {
  return GiftService(ref.read(cloudinaryServiceProvider));
});

final giftsStreamProvider = StreamProvider<List<GiftModel>>((ref) {
  return ref.watch(giftServiceProvider).getGiftsStream();
});

class GiftService {
  final CloudinaryService _cloudinary;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      {'id': 'rose', 'name': 'Rose', 'price': 50, 'cat': 'small', 'img': '🌹', 'file': 'Rose.json'},
      {'id': 'balloon', 'name': 'Balloon', 'price': 20, 'cat': 'small', 'img': '🎈', 'file': 'balloon.json'},
      {'id': 'cake', 'name': 'Pink Cake', 'price': 150, 'cat': 'small', 'img': '🎂', 'file': 'pink cake.json'},
      {'id': 'diamond', 'name': 'Red Diamond', 'price': 500, 'cat': 'luxury', 'img': '💎', 'file': 'Red Diamond.json'},
      {'id': 'cat', 'name': 'Lucky Cat', 'price': 800, 'cat': 'luxury', 'img': '🐱', 'file': 'cat.json'},
      {'id': 'crown', 'name': 'Gold Crown', 'price': 1000, 'cat': 'luxury', 'img': '👑', 'file': 'Premium Gold.json'},
      {'id': 'celebration', 'name': 'Celebration', 'price': 100, 'cat': 'special', 'img': '🎉', 'file': 'Celebration.json'},
      {'id': 'rocket', 'name': 'Rocket', 'price': 5000, 'cat': 'special', 'img': '🚀', 'file': 'Rocket loader.json'},
      {'id': 'car', 'name': 'Red Sport Car', 'price': 20000, 'cat': 'special', 'img': '🏎️', 'file': 'Red Car.json'},
      {'id': 'airplane', 'name': 'Airplane', 'price': 30000, 'cat': 'special', 'img': '✈️', 'file': 'airplane.json'},
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
      final byteData = await rootBundle.load('assets/animations/lottie/${g['file']}');
      final file = File('${tempDir.path}/${g['file']}');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // 2. Upload to Cloudinary
      final url = await _cloudinary.uploadRaw(file.path, folder: "gifts/animations");

      // 3. Create Model
      final gift = GiftModel(
        giftId: g['id'],
        name: g['name'],
        priceInDiamonds: g['price'],
        category: g['cat'],
        imageUrl: g['img'],
        lottieAssetPath: url,
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

  Future<void> sendGift({
    required String roomId,
    required GiftModel gift,
    String? targetUid,
    int quantity = 1,
  }) async {
    final callable = _functions.httpsCallable('sendGiftWithCombo');
    await callable.call({
      'roomId': roomId,
      'giftId': gift.giftId,
      'targetUid': targetUid ?? roomId, // If no target, default to room
      'quantity': quantity,
    });
  }
}
