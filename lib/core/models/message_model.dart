import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable identity of one live combo stream: one sender -> one receiver for one
/// gift. Every message in the same combo shares this key, which is what lets the
/// UI fold 52 per-tap messages into a single banner and a single chat row.
///
/// `targetUid` is written by `sendGiftWithCombo` on every gift message.
String comboKeyFor(String senderUid, String receiverUid, String giftId) =>
    '${senderUid}_${receiverUid}_$giftId';

class RoomMessage {
  final String msgId;
  final String uid;
  final String text;
  final String type; // "text" | "system" | "gift"
  final String? giftId;
  final String? animationUrl;
  final String targetUid;
  final int quantity;
  final int comboCount;
  final DateTime createdAt;
  final String? imageUrl;
  final String? format;
  final String? tier;
  final String? giftName;
  final String? giftCategory;
  final int durationMs;
  final String? soundUrl;

  RoomMessage({
    required this.msgId,
    required this.uid,
    required this.text,
    required this.type,
    this.giftId,
    this.animationUrl,
    this.targetUid = '',
    this.quantity = 1,
    this.comboCount = 0,
    required this.createdAt,
    this.imageUrl,
    this.format,
    this.tier,
    this.giftName,
    this.giftCategory,
    this.durationMs = 0,
    this.soundUrl,
  });

  /// Null when the message is not part of a combo stream.
  String? get giftComboKey {
    if (type != 'gift' || giftId == null || targetUid.isEmpty) return null;
    return comboKeyFor(uid, targetUid, giftId!);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'text': text,
      'type': type,
      'giftId': giftId,
      'animationUrl': animationUrl,
      'targetUid': targetUid,
      'quantity': quantity,
      'comboCount': comboCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'format': format,
      'tier': tier,
      'giftName': giftName,
      'giftCategory': giftCategory,
      'durationMs': durationMs,
      'soundUrl': soundUrl,
    };
  }

  factory RoomMessage.fromMap(Map<String, dynamic> map, String docId) {
    return RoomMessage(
      msgId: docId,
      uid: map['uid'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      giftId: map['giftId']?.toString(),
      animationUrl: (map['animationUrl'] ?? map['animation_url'] ?? map['lottieAssetPath'])?.toString(),
      targetUid: map['targetUid']?.toString() ?? '',
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      comboCount: (map['comboCount'] as num? ?? 0).toInt(),
      createdAt: _parseDate(map['createdAt']),
      imageUrl: map['imageUrl']?.toString(),
      format: (map['format'] ?? map['animationFormat'] ?? map['animation_type'])?.toString(),
      tier: map['tier']?.toString(),
      giftName: (map['giftName'] ?? map['name'])?.toString(),
      giftCategory: (map['giftCategory'] ?? map['category'])?.toString(),
      durationMs: (map['durationMs'] as num? ?? 0).toInt(),
      soundUrl: map['soundUrl']?.toString(),
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }
}
