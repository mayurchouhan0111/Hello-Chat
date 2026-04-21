import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { recharge, gift_sent, gift_received, exchange, noble_purchase, vip_purchase, purchase }

class WalletTransaction {
  final String id;
  final TransactionType type;
  final int amount;
  final int? receivedAmount;
  final String? giftId;
  final String? fromUid;
  final String? toUid;
  final DateTime timestamp;
  final String description;

  // New: Proper accounting helpers
  int get displayAmount => (isBeanTransaction && !isDiamondTransaction) 
    ? amount 
    : (receivedAmount ?? amount);

  bool get isIncoming => displayAmount > 0;

  // New: Categorization helper for UI Tabs
  bool get isDiamondTransaction => 
    type == TransactionType.recharge || 
    type == TransactionType.purchase || 
    type == TransactionType.gift_sent ||
    type == TransactionType.vip_purchase ||
    type == TransactionType.noble_purchase ||
    receivedAmount != null; // Diamonds received in exchange

  bool get isBeanTransaction => 
    type == TransactionType.gift_received || 
    (type == TransactionType.exchange && amount < 0); // Beans spent in exchange

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.receivedAmount,
    this.giftId,
    this.fromUid,
    this.toUid,
    required this.timestamp,
    required this.description,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> data, String id) {
    // Determine type safely to prevent crashes on new/unrecognized types
    final typeString = data['type'] ?? 'recharge';
    final txType = TransactionType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => TransactionType.recharge,
    );

    return WalletTransaction(
      id: id,
      type: txType,
      amount: data['amount'] ?? 0,
      receivedAmount: data['receivedAmount'],
      giftId: data['giftId'],
      fromUid: data['fromUid'],
      toUid: data['toUid'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'giftId': giftId,
      'fromUid': fromUid,
      'toUid': toUid,
      'timestamp': FieldValue.serverTimestamp(),
      'description': description,
    };
  }
}
