import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vip_tier_model.dart';

final vipTiersProvider = StreamProvider<List<VIPTierModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('vip_tiers')
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
        final List<VIPTierModel> tiers = [];
        for (var doc in snapshot.docs) {
          try {
            tiers.add(VIPTierModel.fromFirestore(doc));
          } catch (e) {
            print("--- [VIP ERROR] Skipping malformed VIP Tier (${doc.id}): $e ---");
          }
        }
        print("--- [VIP STREAM] Total Valid Tiers: ${tiers.length} ---");
        return tiers;
      });
});

final vipServiceProvider = Provider<VIPService>((ref) {
  return VIPService();
});

class VIPService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 1. Seed Sample Tiers with High Recharge Amounts (April 5 Update)
  Future<void> feedSampleTiers() async {
    final tiers = [
      { 'tierId': 'vip1', 'name': 'VIP 1', 'level': 1, 'monthlyPriceInDiamonds': 1000000, 'monthlyPriceInUSD': 10.0, 'benefits': ["VIP 1 Badge", "VIP 1 Profile Frame", "VIP 1 Entry Effect", "10% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 1/Frame.svga", 'entryAnimation': "assets/VIP/VIP 1/Entry.svga", 'badgeIcon': "assets/VIP/VIP 1/Badge.webp", 'backgroundImage': '', 'themeColor': '#10B981', 'entryRequirement': 'Purchase 1,000,000 Diamonds', 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 1 },
      { 'tierId': 'vip2', 'name': 'VIP 2', 'level': 2, 'monthlyPriceInDiamonds': 5000000, 'monthlyPriceInUSD': 50.0, 'benefits': ["VIP 2 Badge", "VIP 2 Profile Frame", "VIP 2 Entry Effect", "Special Chat Bubble", "30% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 2/VIP 2/Frame.svga", 'entryAnimation': "assets/VIP/VIP 2/VIP 2/Entry.svga", 'badgeIcon': "assets/VIP/VIP 2/VIP 2/Badge.png", 'backgroundImage': '', 'themeColor': '#059669', 'entryRequirement': 'Purchase 5,000,000 Diamonds', 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 2 },
      { 'tierId': 'vip3', 'name': 'VIP 3', 'level': 3, 'monthlyPriceInDiamonds': 20000000, 'monthlyPriceInUSD': 200.0, 'benefits': ["VIP 3 Badge", "VIP 3 Profile Frame", "VIP 3 Entry Effect", "Priority Mic Access", "Sound Wave Ring", "100% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 3/VIP 3/Frame.svga", 'entryAnimation': "assets/VIP/VIP 3/VIP 3/Entry.svga", 'badgeIcon': "assets/VIP/VIP 3/VIP 3/Badge.webp", 'backgroundImage': '', 'themeColor': '#3B82F6', 'entryRequirement': 'Purchase 20,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 3 },
      { 'tierId': 'vip4', 'name': 'VIP 4', 'level': 4, 'monthlyPriceInDiamonds': 50000000, 'monthlyPriceInUSD': 500.0, 'benefits': ["VIP 4 Badge", "VIP 4 Profile Frame", "VIP 4 Entry Effect", "Priority Mic Access", "Exclusive VIP Gifts", "500% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 4/VIP 4/Frame.svga", 'entryAnimation': "assets/VIP/VIP 4/VIP 4/Entry.svga", 'badgeIcon': "assets/VIP/VIP 4/VIP 4/Badge.webp", 'backgroundImage': '', 'themeColor': '#8B5CF6', 'entryRequirement': 'Purchase 50,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 4 },
      { 'tierId': 'vip5', 'name': 'VIP 5', 'level': 5, 'monthlyPriceInDiamonds': 100000000, 'monthlyPriceInUSD': 1000.0, 'benefits': ["VIP 5 Badge", "VIP 5 Profile Frame", "VIP 5 Entry Effect", "Priority Mic Access", "Custom 6-Digit ID", "Room Kick Protection", "2,000% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 5/VIP 5/User Frame.svga", 'entryAnimation': "assets/VIP/VIP 5/VIP 5/Entry.svga", 'badgeIcon': "assets/VIP/VIP 5/VIP 5/Badge.png", 'backgroundImage': '', 'themeColor': '#F59E0B', 'entryRequirement': 'Purchase 100,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 5 },
      { 'tierId': 'vip6', 'name': 'VIP 6', 'level': 6, 'monthlyPriceInDiamonds': 150000000, 'monthlyPriceInUSD': 1500.0, 'benefits': ["VIP 6 Badge", "VIP 6 Profile Frame", "VIP 6 Entry Effect", "Priority Mic Access", "Custom 5-Digit ID", "Room Kick Protection", "Dedicated Manager", "10,000% Daily Reward Bonus"], 'profileFrame': "assets/VIP/VIP 6/VIP 6/User Frame.svga", 'entryAnimation': "assets/VIP/VIP 6/VIP 6/VIP 6 Entry.svga", 'badgeIcon': "assets/VIP/VIP 6/VIP 6/Badge.webp", 'backgroundImage': '', 'themeColor': '#EF4444', 'entryRequirement': 'Purchase 150,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 6 },
      { 'tierId': 'vip7', 'name': 'VIP 7', 'level': 7, 'monthlyPriceInDiamonds': 200000000, 'monthlyPriceInUSD': 2000.0, 'benefits': ["VIP 7 Badge", "VIP 7 Profile Frame", "VIP 7 Entry Effect", "Priority Mic Access", "Custom 4-Digit ID", "Kick & Ban Protection", "Global Room Announcement", "Dedicated Manager"], 'profileFrame': "assets/VIP/VIP 7/VIP 7/Frame.svga", 'entryAnimation': "assets/VIP/VIP 7/VIP 7/Entry.svga", 'badgeIcon': "assets/VIP/VIP 7/VIP 7/Badge.png", 'backgroundImage': '', 'themeColor': '#EC4899', 'entryRequirement': 'Purchase 200,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 7 },
      { 'tierId': 'vip8', 'name': 'VIP 8', 'level': 8, 'monthlyPriceInDiamonds': 500000000, 'monthlyPriceInUSD': 5000.0, 'benefits': ["VIP 8 Badge", "VIP 8 Profile Frame", "VIP 8 Entry Effect", "Priority Mic Access", "Custom 3-Digit ID", "Full Server Admin Immunity", "Global Server Announcement", "Dedicated VIP Concierge"], 'profileFrame': "assets/VIP/VIP 8/VIP 8/User Frame.svga", 'entryAnimation': "assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.svga", 'badgeIcon': "assets/VIP/VIP 8/VIP 8/Badge.webp", 'backgroundImage': '', 'themeColor': '#F59E0B', 'entryRequirement': 'Purchase 500,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 8 },
    ];



    final batch = _db.batch();
    final existing = await _db.collection('vip_tiers').get();
    for (var doc in existing.docs) { batch.delete(doc.reference); }

    for (var tier in tiers) {
      final ref = _db.collection('vip_tiers').doc(tier['tierId'] as String);
      batch.set(ref, { ...tier, 'createdAt': FieldValue.serverTimestamp() });
    }
    await batch.commit();
  }

  // 2. Purchase VIP with 80/20 Split-Credit Policy (April 5 Update)
  // Calls server-side cloud function for authoritative processing.
  Future<void> purchaseVIP(VIPTierModel tier) async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('purchaseVIP');
    await callable.call({'tierId': tier.tierId});
  }

  // 3. Seed Noble Tiers (Aristocracy)
  Future<void> feedNobleTiers() async {
    final nobles = [
      { 'tierId': 'knight', 'name': 'Knight', 'level': 1, 'monthlyPriceInDiamonds': 2000, 'monthlyPriceInUSD': 20.0, 'benefits': ["noble_badge", "entry_sparkle"], 'badgeIcon': "https://picsum.photos/110", 'profileFrame': '', 'entryAnimation': 'noble_1', 'backgroundImage': '', 'themeColor': '#34D399', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': false, 'sortOrder': 1 },
      { 'tierId': 'viscount', 'name': 'Viscount', 'level': 2, 'monthlyPriceInDiamonds': 10000, 'monthlyPriceInUSD': 100.0, 'benefits': ["noble_badge", "entry_effect", "mic_ring"], 'badgeIcon': "https://picsum.photos/111", 'profileFrame': '', 'entryAnimation': 'noble_2', 'backgroundImage': '', 'themeColor': '#10B981', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': false, 'sortOrder': 2 },
      { 'tierId': 'earl', 'name': 'Earl', 'level': 3, 'monthlyPriceInDiamonds': 30000, 'monthlyPriceInUSD': 300.0, 'benefits': ["noble_badge", "entry_effect", "mic_ring", "world_shout"], 'badgeIcon': "https://picsum.photos/112", 'profileFrame': '', 'entryAnimation': 'noble_3', 'backgroundImage': '', 'themeColor': '#059669', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': false, 'sortOrder': 3 },
      { 'tierId': 'marquis', 'name': 'Marquis', 'level': 4, 'monthlyPriceInDiamonds': 100000, 'monthlyPriceInUSD': 1000.0, 'benefits': ["noble_frame", "exclusive_gifts", "kick_protection"], 'badgeIcon': "https://picsum.photos/113", 'profileFrame': '', 'entryAnimation': 'noble_4', 'backgroundImage': '', 'themeColor': '#3B82F6', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': false, 'sortOrder': 4 },
      { 'tierId': 'duke', 'name': 'Duke', 'level': 5, 'monthlyPriceInDiamonds': 300000, 'monthlyPriceInUSD': 3000.0, 'benefits': ["castle_entry", "exclusive_gifts", "admin_immunity"], 'badgeIcon': "https://picsum.photos/114", 'profileFrame': '', 'entryAnimation': 'noble_5', 'backgroundImage': '', 'themeColor': '#8B5CF6', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': true, 'sortOrder': 5 },
      { 'tierId': 'king', 'name': 'King', 'level': 6, 'monthlyPriceInDiamonds': 600000, 'monthlyPriceInUSD': 6000.0, 'benefits': ["golden_entry", "world_announce", "custom_id"], 'badgeIcon': "https://picsum.photos/115", 'profileFrame': '', 'entryAnimation': 'noble_6', 'backgroundImage': '', 'themeColor': '#F59E0B', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': true, 'sortOrder': 6 },
      { 'tierId': 'emperor', 'name': 'Emperor', 'level': 7, 'monthlyPriceInDiamonds': 1000000, 'monthlyPriceInUSD': 10000.0, 'benefits': ["dragon_entry", "god_badge", "full_room_ignore"], 'badgeIcon': "https://picsum.photos/116", 'profileFrame': '', 'entryAnimation': 'noble_7', 'backgroundImage': '', 'themeColor': '#FFFFFF', 'entryRequirement': 'Monthly Fee', 'priorityMicAccess': true, 'sortOrder': 7 },
    ];



    final batch = _db.batch();
    final existing = await _db.collection('noble_tiers').get();
    for (var doc in existing.docs) { batch.delete(doc.reference); }

    for (var n in nobles) {
      final ref = _db.collection('noble_tiers').doc(n['tierId'] as String);
      batch.set(ref, { ...n, 'isActive': true, 'createdAt': FieldValue.serverTimestamp() });
    }
    await batch.commit();
  }

  // 4. Purchase Noble (Aristocracy)
  Future<void> purchaseNoble(VIPTierModel noble) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final userRef = _db.collection('users').doc(uid);
    
    return _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found.");

      final userData = userDoc.data()!;
      final balance = userData['diamondBalance'] ?? 0;
      final price = noble.monthlyPriceInDiamonds;

      if (balance < price) throw Exception("Insufficient diamonds.");

      final expiry = DateTime.now().add(const Duration(days: 30));

      transaction.update(userRef, {
        'diamondBalance': FieldValue.increment(-price),
        'nobleTier': noble.name,
        'nobleExpiry': Timestamp.fromDate(expiry),
        'badgeIcon': noble.badgeIcon,
      });

      // Log Transaction
      final txRef = userRef.collection('transactions').doc();
      transaction.set(txRef, {
        'type': 'noble_purchase',
        'amount': price,
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Purchased ${noble.name} Noble Title",
      });
    });
  }

  // 5. Claim Daily VIP/Noble Reward
  // Server-side validation via cloud function ensures VIP active & not expired.
  Future<void> claimDailyReward() async {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('claimVIPDailyReward');
    await callable.call();
  }

  // 6. Purchase VIP Tier
  Future<void> purchaseVip(String tierId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userRef = _db.collection('users').doc(user.uid);
    final tierRef = _db.collection('vip_tiers').doc(tierId);

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final tierSnap = await transaction.get(tierRef);

      if (!userSnap.exists) throw Exception("User profile not found");
      if (!tierSnap.exists) throw Exception("VIP tier not found");

      final userData = userSnap.data()!;
      final tierData = tierSnap.data()!;

      final int price = tierData['monthlyPriceInDiamonds'] ?? (tierData['level'] * 5000);
      final int userDiamonds = userData['diamondBalance'] ?? 0;

      if (userDiamonds < price) {
        throw Exception("Insufficient diamonds. Required: $price");
      }

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));

      transaction.update(userRef, {
        'diamondBalance': FieldValue.increment(-price),
        'vipTier': tierData['name'] ?? 'VIP',
        'vipExpiry': Timestamp.fromDate(expiresAt),
      });

      final txRef = userRef.collection('transactions').doc();
      transaction.set(txRef, {
        'type': 'vip_purchase',
        'amount': price,
        'tierId': tierId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Subscribed to ${tierData['name']}",
      });
    });
  }
}

final nobleTiersProvider = StreamProvider<List<VIPTierModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('noble_tiers')
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
        final List<VIPTierModel> tiers = [];
        for (var doc in snapshot.docs) {
          try {
            tiers.add(VIPTierModel.fromFirestore(doc));
          } catch (e) {
            print("--- [NOBLE ERROR] Skipping malformed Noble Tier (${doc.id}): $e ---");
          }
        }
        print("--- [NOBLE STREAM] Total Valid Tiers: ${tiers.length} ---");
        return tiers;
      });
});

final pendingCreditsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('pending_credits')
      .where('status', isEqualTo: 'pending')
      .orderBy('releaseDate')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
});

