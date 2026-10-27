import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { recharge, gift_sent, gift_received, exchange, noble_purchase, vip_purchase, purchase, cash_out, game_win, game_bet }

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

  // Categorization helpers for UI Tabs
  bool get isDiamondTransaction => 
    type == TransactionType.recharge || 
    type == TransactionType.purchase || 
    type == TransactionType.gift_sent ||
    type == TransactionType.vip_purchase ||
    type == TransactionType.noble_purchase ||
    type == TransactionType.game_win ||
    type == TransactionType.game_bet ||
    receivedAmount != null; // Diamonds received in exchange

  bool get isBeanTransaction => 
    type == TransactionType.gift_received || 
    (type == TransactionType.exchange && amount < 0); // Beans spent in exchange

  bool get isOfficialRecharge =>
    type == TransactionType.recharge &&
    !description.toLowerCase().contains('bonus') &&
    !description.toLowerCase().contains('reward');

  bool get isEventBonus =>
    description.toLowerCase().contains('bonus') ||
    description.toLowerCase().contains('giveaway') ||
    description.toLowerCase().contains('reward') ||
    description.toLowerCase().contains('event');

  bool get isGiftTransaction =>
    type == TransactionType.gift_sent ||
    type == TransactionType.gift_received;

  bool get isOtherTransaction =>
    !isOfficialRecharge && !isEventBonus && !isGiftTransaction;

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

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final intMs = int.tryParse(value);
      if (intMs != null) return DateTime.fromMillisecondsSinceEpoch(intMs);
    }
    return DateTime.now();
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> data, String id) {
    // Determine type safely to prevent crashes on new/unrecognized types
    final rawType = (data['action'] ?? data['type'] ?? 'recharge').toString().toLowerCase().trim();
    TransactionType txType;
    if (rawType == 'spin_wheel_cost' || rawType == 'game_bet') {
      txType = TransactionType.game_bet;
    } else if (rawType == 'spin_wheel_prize' || rawType == 'game_win') {
      txType = TransactionType.game_win;
    } else if (rawType == 'spin_wheel_loss' || rawType == 'game_settle_loss') {
      txType = TransactionType.game_bet;
    } else if (rawType == 'spin_reconciliation_offset' || rawType == 'balance_reconciliation' || rawType == 'official_recharge') {
      txType = TransactionType.recharge;
    } else if (rawType == 'gift_sent' || rawType == 'send_gift') {
      txType = TransactionType.gift_sent;
    } else if (rawType == 'gift_received' || rawType == 'receive_gift') {
      txType = TransactionType.gift_received;
    } else if (rawType.contains('salary') || rawType.contains('reward')) {
      txType = TransactionType.recharge;
    } else {
      txType = TransactionType.values.firstWhere(
        (e) => e.name == rawType,
        orElse: () => TransactionType.recharge,
      );
    }

    final num? rawAmount = data['amount'] as num? ?? data['diamonds'] as num? ?? data['beans'] as num?;
    final int amount = (rawAmount ?? 0).toInt();

    final num? rawReceived = data['receivedAmount'] as num? ?? data['diamondAmount'] as num?;
    final int? receivedAmount = rawReceived?.toInt();

    final rawTs = data['timestamp'] ?? data['createdAt'] ?? data['created_at'] ?? data['settledAt'];
    final timestamp = _parseDateTime(rawTs);

    return WalletTransaction(
      id: id,
      type: txType,
      amount: amount,
      receivedAmount: receivedAmount,
      giftId: data['giftId']?.toString(),
      fromUid: data['fromUid']?.toString(),
      toUid: data['toUid']?.toString(),
      timestamp: timestamp,
      description: data['description']?.toString() ?? '',
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
