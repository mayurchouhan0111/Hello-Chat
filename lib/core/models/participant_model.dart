import 'package:cloud_firestore/cloud_firestore.dart';

class Participant {
  final String uid;
  final DateTime joinedAt;
  final int? seatIndex;
  final bool isMuted;
  final String role; // "host" | "admin" | "speaker" | "audience"

  Participant({
    required this.uid,
    required this.joinedAt,
    this.seatIndex,
    required this.isMuted,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'seatIndex': seatIndex,
      'isMuted': isMuted,
      'role': role,
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map, String docId) {
    return Participant(
      uid: docId,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      seatIndex: map['seatIndex'],
      isMuted: map['isMuted'] ?? false,
      role: map['role'] ?? 'audience',
    );
  }
}
