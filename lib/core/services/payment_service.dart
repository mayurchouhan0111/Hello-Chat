import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';

class PaymentService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Initializes a Stripe payment session.
  /// Returns a 'paymentIntentClientSecret' and 'ephemeralKey'.
  // TODO: Add Client Production Credentials here
  static const String STRIPE_PUBLISHABLE_KEY = "pk_test_placeholder"; // Replace with client's Stripe Key
  static const String RAZORPAY_KEY_ID = "rzp_test_placeholder";      // Replace with client's Razorpay ID

  Future<Map<String, dynamic>> initializeStripePayment({
    required int diamondAmount,
    required double priceInUSD,
  }) async {
    final result = await callFunction('createStripePaymentIntent', {
      'amount': diamondAmount,
      'currency': 'usd',
      'price': priceInUSD,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Initializes a Razorpay order.
  /// Returns 'orderId' for the native Razorpay SDK.
  Future<Map<String, dynamic>> initializeRazorpayPayment({
    required int diamondAmount,
    required double priceInINR,
  }) async {
    final result = await callFunction('createRazorpayOrder', {
      'amount': diamondAmount,
      'currency': 'inr',
      'price': priceInINR,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Verifies the payment on the server and credits the wallet.
  Future<bool> verifyPayment({
    required String provider, // 'stripe' or 'razorpay'
    required String transactionId,
    String? signature, // Required for Razorpay
  }) async {
    final result = await callFunction('verifyPaymentAndCredit', {
      'provider': provider,
      'transactionId': transactionId,
      'signature': signature,
    });
    return result['success'] ?? false;
  }

  /// Listens to the user's transaction history.
  Stream<List<Map<String, dynamic>>> getTransactionHistory(String uid) {
    return _db.collection('transactions')
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

final transactionHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(paymentServiceProvider).getTransactionHistory(uid);
});
