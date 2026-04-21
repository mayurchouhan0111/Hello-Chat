import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'base_firebase_service.dart';

class GiftService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of available gifts
  Stream<List<Map<String, dynamic>>> getGiftsStream() {
    return _db.collection('gifts')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // Send Gift via Cloud Function (Atomic & Secure)
  Future<Map<String, dynamic>> sendGift({
    required String roomId,
    required String giftId,
    required String targetUid,
    int quantity = 1,
  }) async {
    final result = await callFunction('sendGiftWithCombo', {
      'roomId': roomId,
      'giftId': giftId,
      'targetUid': targetUid,
      'quantity': quantity,
    });
    return Map<String, dynamic>.from(result);
  }

  // Recharge Diamonds (Sandbox)
  Future<void> rechargeDiamonds(int amount) async {
    await callFunction('rechargeDiamonds', {'amount': amount});
  }

  // Purchase VIP Tier
  Future<void> purchaseVIP(String tierId) async {
    await callFunction('purchaseVIP', {'tierId': tierId});
  }
}
