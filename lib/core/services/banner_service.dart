import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/banner_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

final bannerServiceProvider = Provider<BannerService>((ref) => BannerService());

final activeBannersStreamProvider = StreamProvider<List<BannerModel>>((ref) {
  return ref.watch(bannerServiceProvider).getActiveBanners();
});

class BannerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Stream for Home Screen Carousel
  Stream<List<BannerModel>> getActiveBanners() {
    return _db
        .collection('app_banners')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: false)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BannerModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Upload/Create Banner via Cloud Function
  Future<void> uploadBanner(Map<String, dynamic> bannerData) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('uploadBanner');
      await callable.call(bannerData);
    } catch (e) {
      throw Exception("Failed to upload banner: $e");
    }
  }

  // Fallback direct upload if not using Cloud Functions immediately
  Future<void> directUploadExample(File imageFile, BannerModel banner) async {
    final storageRef = FirebaseStorage.instance.ref().child('banners/${banner.bannerId}.jpg');
    await storageRef.putFile(imageFile);
    final downloadUrl = await storageRef.getDownloadURL();
    
    final finalBanner = BannerModel(
      bannerId: banner.bannerId,
      imageUrl: downloadUrl,
      title: banner.title,
      subtitle: banner.subtitle,
      buttonText: banner.buttonText,
      actionType: banner.actionType,
      actionValue: banner.actionValue,
      isActive: banner.isActive,
      priority: banner.priority,
      createdBy: banner.createdBy,
    );
    
    await _db.collection('app_banners').doc(finalBanner.bannerId).set(finalBanner.toMap());
  }

  // Temporary function to seed 4 beautiful test banners into Firestore
  Future<void> seedTestBanners() async {
    final batch = _db.batch();
    
    final bannersToSeed = [
      BannerModel(
        bannerId: _db.collection('app_banners').doc().id,
        imageUrl: "https://picsum.photos/seed/creative/800/400",
        title: "Welcome to Hello Chat! 🎉",
        subtitle: "Start exploring live rooms and meet new friends.",
        buttonText: "Join a Room >>>",
        actionType: "none",
        isActive: true,
        priority: 1,
      ),
      BannerModel(
        bannerId: _db.collection('app_banners').doc().id,
        imageUrl: "https://images.unsplash.com/photo-1543857778-c4a1a3e0b2eb?w=800&q=80",
        title: "Exclusive Party Invite 🎁",
        subtitle: "Join the VIP celebration tonight at 8 PM.",
        buttonText: "Get Ticket",
        actionType: "none",
        isActive: true,
        priority: 2,
      ),
      BannerModel(
        bannerId: _db.collection('app_banners').doc().id,
        imageUrl: "https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=800&q=80",
        title: "Creator Spotlight 🌟",
        subtitle: "Watch the top 10 broadcasters of the week.",
        buttonText: "Watch Now",
        actionType: "none",
        isActive: true,
        priority: 3,
      ),
      BannerModel(
        bannerId: _db.collection('app_banners').doc().id,
        imageUrl: "https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=800&q=80",
        title: "Big Recharge Bonus 💎",
        subtitle: "Get 20% extra diamonds on your first recharge.",
        buttonText: "Recharge Now >>>",
        actionType: "recharge",
        isActive: true,
        priority: 4,
      ),
    ];

    for (var banner in bannersToSeed) {
      final docRef = _db.collection('app_banners').doc(banner.bannerId);
      batch.set(docRef, banner.toMap());
    }

    try {
      await batch.commit();
      print("✅ Successfully seeded 4 banners into Firestore!");
    } catch (e) {
      print("❌ Error seeding banners: $e");
    }
  }
}
