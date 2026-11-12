import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentOrderStatus {
  created,
  pending,
  completed,
  failed,
  expired,
  refunded,
  disputed,
  flagged,
  unknown;

  static PaymentOrderStatus fromString(String? val) {
    if (val == null) return PaymentOrderStatus.unknown;
    switch (val.toLowerCase().trim()) {
      case 'created':
        return PaymentOrderStatus.created;
      case 'pending':
        return PaymentOrderStatus.pending;
      case 'completed':
        return PaymentOrderStatus.completed;
      case 'failed':
        return PaymentOrderStatus.failed;
      case 'expired':
        return PaymentOrderStatus.expired;
      case 'refunded':
        return PaymentOrderStatus.refunded;
      case 'disputed':
        return PaymentOrderStatus.disputed;
      case 'flagged':
        return PaymentOrderStatus.flagged;
      default:
        return PaymentOrderStatus.unknown;
    }
  }
}

class PaymentOrderModel {
  final String orderId;
  final String uid;
  final String gateway;
  final int amount; // in minor units
  final String currency;
  final PaymentOrderStatus status;
  final String? gatewayPaymentId;
  final String? packageId;
  final int totalDiamonds;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const PaymentOrderModel({
    required this.orderId,
    required this.uid,
    required this.gateway,
    required this.amount,
    required this.currency,
    required this.status,
    this.gatewayPaymentId,
    this.packageId,
    this.totalDiamonds = 0,
    this.createdAt,
    this.expiresAt,
  });

  factory PaymentOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final snapshot = data['packageSnapshot'] as Map<String, dynamic>? ?? {};

    DateTime? parseTs(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PaymentOrderModel(
      orderId: doc.id,
      uid: data['uid'] as String? ?? '',
      gateway: data['gateway'] as String? ?? 'razorpay',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'inr',
      status: PaymentOrderStatus.fromString(data['status'] as String?),
      gatewayPaymentId: data['gatewayPaymentId'] as String?,
      packageId: snapshot['packageId'] as String?,
      totalDiamonds: (snapshot['totalDiamonds'] as num?)?.toInt() ?? 0,
      createdAt: parseTs(data['createdAt']),
      expiresAt: parseTs(data['expiresAt']),
    );
  }
}
