import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BroadcastModel {
  final String id;
  final String message;
  final String type; // "system", "event", "alert"
  final DateTime createdAt;
  final bool isActive;

  BroadcastModel({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isActive = true,
  });

  factory BroadcastModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BroadcastModel(
      id: doc.id,
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
}

final broadcastServiceProvider = Provider((ref) => BroadcastService());

final activeBroadcastsProvider = StreamProvider<List<BroadcastModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('global_announcements')
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(3)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => BroadcastModel.fromFirestore(doc)).toList());
});

class BroadcastService {
  final _db = FirebaseFirestore.instance;

  Future<void> sendAdminBroadcast(String message, {String type = 'system'}) async {
    await _db.collection('global_announcements').add({
      'message': message,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }
}
