import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/payment_package_model.dart';
import '../models/payment_order_model.dart';
import 'base_firebase_service.dart';

class PaymentService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Placeholder credentials for client testing / sandbox mode
  static const String razorpayKeyId = "rzp_test_placeholder";
  static const String stripePublishableKey = "pk_test_placeholder";

  /// 1. Fetch available packages from server (prices in minor units: paise / cents)
  Future<List<PaymentPackageModel>> fetchPackages() async {
    try {
      final res = await callFunction('getRechargePackages', {});
      if (res != null && res['packages'] is List) {
        final list = res['packages'] as List;
        return list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final id = map['packageId']?.toString() ?? 'pack_unknown';
          return PaymentPackageModel.fromMap(id, map);
        }).toList();
      }
    } catch (e) {
      debugPrint('[PAYMENT_FETCH_WARN] Using fallback package catalog: $e');
    }

    // Direct Firestore fallback
    try {
      final snap = await _db
          .collection('recharge_packages')
          .where('active', isEqualTo: true)
          .orderBy('sortOrder', descending: false)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) => PaymentPackageModel.fromMap(doc.id, doc.data())).toList();
      }
    } catch (e) {
      debugPrint('[PAYMENT_FIRESTORE_WARN]: $e');
    }

    // Standard Default Package Catalog
    return const [
      PaymentPackageModel(packageId: "pack_70", diamonds: 70, priceINR: 9900, priceUSD: 120, sortOrder: 1),
      PaymentPackageModel(packageId: "pack_350", diamonds: 350, bonusDiamonds: 20, priceINR: 49900, priceUSD: 599, sortOrder: 2, tag: "HOT 🔥"),
      PaymentPackageModel(packageId: "pack_700", diamonds: 700, bonusDiamonds: 50, priceINR: 99900, priceUSD: 1199, sortOrder: 3, tag: "POPULAR ⭐"),
      PaymentPackageModel(packageId: "pack_1400", diamonds: 1400, bonusDiamonds: 150, priceINR: 199900, priceUSD: 2399, sortOrder: 4, tag: "BEST VALUE 💎"),
      PaymentPackageModel(packageId: "pack_3500", diamonds: 3500, bonusDiamonds: 500, priceINR: 499900, priceUSD: 5999, sortOrder: 5),
      PaymentPackageModel(packageId: "pack_7000", diamonds: 7000, bonusDiamonds: 1200, priceINR: 999900, priceUSD: 11999, sortOrder: 6, tag: "VIP ONLY 👑"),
    ];
  }

  /// 2. Create Payment Order on Server with Idempotency Key
  Future<Map<String, dynamic>> createOrder({
    required String packageId,
    required String gateway,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? "idemp_${DateTime.now().millisecondsSinceEpoch}_$packageId";
    final result = await callFunction('createPaymentOrder', {
      'packageId': packageId,
      'gateway': gateway,
      'idempotencyKey': key,
    });

    final orderData = Map<String, dynamic>.from(result);
    final orderId = orderData['orderId']?.toString();
    if (orderId != null && orderId.isNotEmpty) {
      await savePendingOrderLocally(orderId);
    }
    return orderData;
  }

  /// 3. Verify and Credit Payment (Fast-Path)
  /// Triggers server-side creditOrderIfPaid
  Future<Map<String, dynamic>> verifyAndCredit({
    required String orderId,
    String? gatewayPaymentId,
    String? gatewaySignature,
  }) async {
    final result = await callFunction('verifyAndCreditPayment', {
      'orderId': orderId,
      'gatewayPaymentId': gatewayPaymentId,
      'gatewaySignature': gatewaySignature,
    });

    await clearPendingOrderLocally();
    return Map<String, dynamic>.from(result);
  }

  /// 4. Listen to Order Status in Real Time
  Stream<PaymentOrderModel?> listenToOrder(String orderId) {
    return _db.collection('payment_orders').doc(orderId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return PaymentOrderModel.fromFirestore(snap);
    });
  }

  /// 5. Recovery for Interrupted Payments (Edge Cases B1, B4, B5)
  Future<File> _getPendingOrderFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pending_payment_order.json');
  }

  Future<void> savePendingOrderLocally(String orderId) async {
    try {
      final file = await _getPendingOrderFile();
      await file.writeAsString(jsonEncode({
        'orderId': orderId,
        'startedAt': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[PAYMENT_RECOVERY_SAVE_WARN]: $e');
    }
  }

  Future<String?> getPendingOrderLocally() async {
    try {
      final file = await _getPendingOrderFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        return map['orderId'] as String?;
      }
    } catch (e) {
      debugPrint('[PAYMENT_RECOVERY_GET_WARN]: $e');
    }
    return null;
  }

  Future<void> clearPendingOrderLocally() async {
    try {
      final file = await _getPendingOrderFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[PAYMENT_RECOVERY_CLEAR_WARN]: $e');
    }
  }

  /// 6. Check and Resolve Any Stuck Pending Order
  Future<PaymentOrderModel?> resolvePendingOrderOnLaunch() async {
    final orderId = await getPendingOrderLocally();
    if (orderId == null) return null;

    try {
      final doc = await _db.collection('payment_orders').doc(orderId).get();
      if (!doc.exists) {
        await clearPendingOrderLocally();
        return null;
      }

      final order = PaymentOrderModel.fromFirestore(doc);
      if (order.status == PaymentOrderStatus.completed ||
          order.status == PaymentOrderStatus.expired ||
          order.status == PaymentOrderStatus.failed) {
        await clearPendingOrderLocally();
      } else {
        // Still pending or created: ask server fast path
        await verifyAndCredit(orderId: orderId);
      }
      return order;
    } catch (e) {
      debugPrint('[PAYMENT_RECOVERY_RESOLVE_ERR]: $e');
      return null;
    }
  }

  /// 7. Listens to the user's transaction history (Passbook)
  Stream<List<Map<String, dynamic>>> getTransactionHistory(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

final rechargePackagesProvider = FutureProvider<List<PaymentPackageModel>>((ref) {
  return ref.watch(paymentServiceProvider).fetchPackages();
});

final activePaymentOrderProvider = StreamProvider.family<PaymentOrderModel?, String>((ref, orderId) {
  return ref.watch(paymentServiceProvider).listenToOrder(orderId);
});

final transactionHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(paymentServiceProvider).getTransactionHistory(uid);
});
