import 'package:cloud_firestore/cloud_firestore.dart';

class RoomMessage {
  final String msgId;
  final String uid;
  final String text;
  final String type; // "text" | "system" | "gift"
  final String? giftId;
  final String? animationUrl;
  final DateTime createdAt;

  RoomMessage({
    required this.msgId,
    required this.uid,
    required this.text,
    required this.type,
    this.giftId,
    this.animationUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'text': text,
      'type': type,
      'giftId': giftId,
      'animationUrl': animationUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RoomMessage.fromMap(Map<String, dynamic> map, String docId) {
    return RoomMessage(
      msgId: docId,
      uid: map['uid'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      giftId: map['giftId'],
      animationUrl: map['animationUrl'],
      createdAt: _parseDate(map['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }
}
