import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vip_tier_model.dart';

final vipTiersProvider = StreamProvider<List<VIPTierModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('vip_tiers')
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => VIPTierModel.fromFirestore(doc)).toList());
});

final vipServiceProvider = Provider<VIPService>((ref) {
  return VIPService();
});

class VIPService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 1. Seed Sample Tiers (Frontend Version)
  Future<void> feedSampleTiers() async {
    final tiers = [
      { 'tierId': 'vip1', 'name': 'VIP 1', 'level': 1, 'monthlyPriceInDiamonds': 500, 'monthlyPriceInUSD': 5.0, 'benefits': ["special_frame", "badge"], 'profileFrame': "https://i.ibb.co/vz6G3H1/vip1-frame.png", 'entryAnimation': "vip_entry_1", 'badgeIcon': "https://i.ibb.co/3W6pZ8P/vip1-badge.png", 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 1 },
      { 'tierId': 'vip2', 'name': 'VIP 2', 'level': 2, 'monthlyPriceInDiamonds': 1500, 'monthlyPriceInUSD': 15.0, 'benefits': ["special_frame", "badge", "entry_effect"], 'profileFrame': "https://i.ibb.co/tZ5Wj0K/vip2-frame.png", 'entryAnimation': "vip_entry_2", 'badgeIcon': "https://i.ibb.co/mS6Pz8P/vip2-badge.png", 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 2 },
      { 'tierId': 'vip3', 'name': 'VIP 3', 'level': 3, 'monthlyPriceInDiamonds': 5000, 'monthlyPriceInUSD': 50.0, 'benefits': ["special_frame", "badge", "entry_effect", "priority_mic"], 'profileFrame': "https://i.ibb.co/pP6Z8PQ/vip3-frame.png", 'entryAnimation': "vip_entry_3", 'badgeIcon': "https://i.ibb.co/xS6Z8PQ/vip3-badge.png", 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 3 },
      { 'tierId': 'vip4', 'name': 'VIP 4', 'level': 4, 'monthlyPriceInDiamonds': 15000, 'monthlyPriceInUSD': 150.0, 'benefits': ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts"], 'profileFrame': "https://i.ibb.co/yS6Z8PQ/vip4-frame.png", 'entryAnimation': "vip_entry_4", 'badgeIcon': "https://i.ibb.co/zS6Z8PQ/vip4-badge.png", 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 4 },
      { 'tierId': 'vip5', 'name': 'VIP 5', 'level': 5, 'monthlyPriceInDiamonds': 50000, 'monthlyPriceInUSD': 500.0, 'benefits': ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "custom_id"], 'profileFrame': "https://i.ibb.co/AS6Z8PQ/vip5-frame.png", 'entryAnimation': "vip_entry_5", 'badgeIcon': "https://i.ibb.co/BS6Z8PQ/vip5-badge.png", 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 5 },
      { 'tierId': 'vip6', 'name': 'VIP 6', 'level': 6, 'monthlyPriceInDiamonds': 150000, 'monthlyPriceInUSD': 1500.0, 'benefits': ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "manager"], 'profileFrame': "https://i.ibb.co/CS6Z8PQ/vip6-frame.png", 'entryAnimation': "vip_entry_6", 'badgeIcon': "https://i.ibb.co/DS6Z8PQ/vip6-badge.png", 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 6 },
      { 'tierId': 'svip', 'name': 'SVIP', 'level': 7, 'monthlyPriceInDiamonds': 500000, 'monthlyPriceInUSD': 5000.0, 'benefits': ["all_access", "god_badge", "world_frame"], 'profileFrame': "https://i.ibb.co/ES6Z8PQ/svip-frame.png", 'entryAnimation': "svip_entry", 'badgeIcon': "https://i.ibb.co/FS6Z8PQ/svip-badge.png", 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 7 },
    ];

    final batch = _db.batch();

    // Clear old data (Optional)
    final existing = await _db.collection('vip_tiers').get();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }

    // Add new tiers
    for (var tier in tiers) {
      final ref = _db.collection('vip_tiers').doc(tier['tierId'] as String);
      batch.set(ref, {
        ...tier,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // 2. Purchase VIP (Frontend Transaction)
  Future<void> purchaseVIP(VIPTierModel tier) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final userRef = _db.collection('users').doc(uid);
    
    return _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found.");

      final userData = userDoc.data()!;
      final balance = userData['diamondBalance'] ?? 0;
      final price = tier.monthlyPriceInDiamonds;

      if (balance < price) throw Exception("Insufficient diamonds.");

      final expiry = DateTime.now().add(const Duration(days: 30));

      transaction.update(userRef, {
        'diamondBalance': FieldValue.increment(-price),
        'vipTier': tier.name,
        'vipExpiry': Timestamp.fromDate(expiry),
        'profileFrame': tier.profileFrame,
        'entryAnimation': tier.entryAnimation,
        'badgeIcon': tier.badgeIcon,
      });

      // Log Transaction
      final txRef = userRef.collection('transactions').doc();
      transaction.set(txRef, {
        'type': 'purchase',
        'amount': price,
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Purchased ${tier.name} Subscription",
      });
    });
  }
}
