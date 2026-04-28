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
      { 'tierId': 'vip1', 'name': 'VIP 1', 'level': 1, 'monthlyPriceInDiamonds': 1000000, 'monthlyPriceInUSD': 10.0, 'benefits': ["badge", "entry_effect"], 'profileFrame': "", 'entryAnimation': "vip_entry_1", 'badgeIcon': "https://picsum.photos/101", 'backgroundImage': '', 'themeColor': '#10B981', 'entryRequirement': 'Purchase 1,000,000 Diamonds', 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 1 },
      { 'tierId': 'vip2', 'name': 'VIP 2', 'level': 2, 'monthlyPriceInDiamonds': 5000000, 'monthlyPriceInUSD': 50.0, 'benefits': ["badge", "entry_effect", "mic_ring"], 'profileFrame': "", 'entryAnimation': "vip_entry_2", 'badgeIcon': "https://picsum.photos/102", 'backgroundImage': '', 'themeColor': '#059669', 'entryRequirement': 'Purchase 5,000,000 Diamonds', 'priorityMicAccess': false, 'isActive': true, 'sortOrder': 2 },
      { 'tierId': 'vip3', 'name': 'VIP 3', 'level': 3, 'monthlyPriceInDiamonds': 20000000, 'monthlyPriceInUSD': 200.0, 'benefits': ["badge", "entry_effect", "mic_ring", "priority_mic"], 'profileFrame': "", 'entryAnimation': "vip_entry_3", 'badgeIcon': "https://picsum.photos/103", 'backgroundImage': '', 'themeColor': '#3B82F6', 'entryRequirement': 'Purchase 20,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 3 },
      { 'tierId': 'vip4', 'name': 'VIP 4', 'level': 4, 'monthlyPriceInDiamonds': 50000000, 'monthlyPriceInUSD': 500.0, 'benefits': ["badge", "entry_effect", "exclusive_gifts", "priority_mic"], 'profileFrame': "", 'entryAnimation': "vip_entry_4", 'badgeIcon': "https://picsum.photos/104", 'backgroundImage': '', 'themeColor': '#8B5CF6', 'entryRequirement': 'Purchase 50,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 4 },
      { 'tierId': 'vip5', 'name': 'VIP 5', 'level': 5, 'monthlyPriceInDiamonds': 100000000, 'monthlyPriceInUSD': 1000.0, 'benefits': ["royal_frame", "badge", "custom_id", "kick_protection"], 'profileFrame': "https://picsum.photos/204", 'entryAnimation': "vip_entry_5", 'badgeIcon': "https://picsum.photos/105", 'backgroundImage': '', 'themeColor': '#F59E0B', 'entryRequirement': 'Purchase 100,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 5 },
      { 'tierId': 'vip6', 'name': 'VIP 6', 'level': 6, 'monthlyPriceInDiamonds': 150000000, 'monthlyPriceInUSD': 1500.0, 'benefits': ["royal_frame", "badge", "custom_id", "kick_protection", "god_badge"], 'profileFrame': "https://picsum.photos/205", 'entryAnimation': "vip_entry_6", 'badgeIcon': "https://picsum.photos/106", 'backgroundImage': '', 'themeColor': '#EF4444', 'entryRequirement': 'Purchase 150,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 6 },
      { 'tierId': 'vip7', 'name': 'VIP 7', 'level': 7, 'monthlyPriceInDiamonds': 200000000, 'monthlyPriceInUSD': 2000.0, 'benefits': ["all_access", "master_badge", "world_announce"], 'profileFrame': "https://picsum.photos/206", 'entryAnimation': "svip_entry", 'badgeIcon': "https://picsum.photos/107", 'backgroundImage': '', 'themeColor': '#FFFFFF', 'entryRequirement': 'Purchase 200,000,000 Diamonds', 'priorityMicAccess': true, 'isActive': true, 'sortOrder': 7 },
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
  Future<void> purchaseVIP(VIPTierModel tier) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final userRef = _db.collection('users').doc(uid);
    
    return _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found.");

      final userData = userDoc.data()!;
      final balance = userData['diamondBalance'] ?? 0;
      final rechargeAmount = tier.monthlyPriceInDiamonds;

      if (balance < rechargeAmount) throw Exception("Insufficient diamonds for purchase.");

      // Calculate Split
      final immediateCredit = (rechargeAmount * 0.8).toInt();
      final delayedCredit = (rechargeAmount * 0.2).toInt();
      
      final expiry = DateTime.now().add(const Duration(days: 30));
      final releaseDate = DateTime.now().add(const Duration(days: 30));

      // 1. Deduct full & Add 80% back IMMEDIATELY
      transaction.update(userRef, {
        'diamondBalance': FieldValue.increment(-rechargeAmount + immediateCredit), // Net -20% now
        'vipTier': tier.name,
        'vipExpiry': Timestamp.fromDate(expiry),
        'profileFrame': tier.profileFrame,
        'entryAnimation': tier.entryAnimation,
        'badgeIcon': tier.badgeIcon,
      });

      // 2. Log Initial Transaction
      final txRef = userRef.collection('transactions').doc();
      transaction.set(txRef, {
        'type': 'vip_subscription',
        'amount': rechargeAmount,
        'immediateReturn': immediateCredit,
        'pendingReturn': delayedCredit,
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Subscribed to ${tier.name} (80% Immediate Credit Applied)",
      });

      // 3. Schedule 20% Release (for Background Job or Manual Claim later)
      final pendingRef = userRef.collection('pending_credits').doc();
      transaction.set(pendingRef, {
        'amount': delayedCredit,
        'status': 'pending', // 'released' once processed
        'releaseDate': Timestamp.fromDate(releaseDate),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'vip_cashback',
        'tier': tier.name,
      });
    });
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

  // 5. Claim Daily VIP/Noble Reward (Month 5 Final Feature)

  Future<void> claimDailyReward() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final userRef = _db.collection('users').doc(uid);
    
    await _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found.");

      final userData = userDoc.data()!;
      final String vip = userData['vipTier'] ?? 'none';
      final String lastClaimStr = userData['lastVipClaim'] ?? '';
      
      if (vip == 'none') throw Exception("Only VIP members can claim daily rewards!");

      // Date check
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      if (lastClaimStr == todayStr) throw Exception("Daily reward already claimed today!");

      // Calculation logic
      int beanReward = 0;
      if (vip.contains('1')) beanReward = 10;
      else if (vip.contains('2')) beanReward = 30;
      else if (vip.contains('3')) beanReward = 100;
      else if (vip.contains('4')) beanReward = 500;
      else if (vip.contains('5')) beanReward = 2000;
      else if (vip.contains('6')) beanReward = 10000;
      else if (vip.toLowerCase().contains('svip')) beanReward = 50000;

      transaction.update(userRef, {
        'beanBalance': FieldValue.increment(beanReward),
        'lastVipClaim': todayStr,
      });

      // Log Transaction
      final txRef = userRef.collection('transactions').doc();
      transaction.set(txRef, {
        'type': 'reward',
        'amount': beanReward,
        'currency': 'beans',
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Daily VIP Reward ($vip)",
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

