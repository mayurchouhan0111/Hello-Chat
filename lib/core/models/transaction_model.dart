import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { recharge, gift_sent, gift_received, cash_out }

class WalletTransaction {
  final String id;
  final TransactionType type;
  final int amount;
  final String? giftId;
  final String? fromUid;
  final String? toUid;
  final DateTime timestamp;
  final String description;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.giftId,
    this.fromUid,
    this.toUid,
    required this.timestamp,
    required this.description,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> data, String id) {
    return WalletTransaction(
      id: id,
      type: TransactionType.values.byName(data['type'] ?? 'recharge'),
      amount: data['amount'] ?? 0,
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
