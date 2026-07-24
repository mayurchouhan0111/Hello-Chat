import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/base_firebase_service.dart';

final roomSupportServiceProvider = Provider<RoomSupportService>((ref) {
  return RoomSupportService();
});

class RoomSupportService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch room support config (target table)
  Stream<Map<String, dynamic>?> configStream() {
    return _db.collection('room_support_configs').doc('settings').snapshots().map((s) => s.data());
  }

  /// Fetch current cycle for a room
  Stream<Map<String, dynamic>?> cycleStream(String roomId) {
    return _db.collection('room_support_cycles').doc(roomId).snapshots().map((s) => s.data());
  }

  /// Fetch partners for a room
  Stream<List<Map<String, dynamic>>> partnersStream(String roomId) {
    return _db.collection('room_support_cycles').doc(roomId).collection('partners').snapshots().map(
      (s) => s.docs.map((d) => ({...d.data(), 'id': d.id})).toList(),
    );
  }

  /// Fetch weekly history for a room
  Stream<List<Map<String, dynamic>>> historyStream(String roomId) {
    return _db.collection('room_support_history').doc(roomId).collection('weeks')
      .orderBy('weekEnd', descending: true).limit(10).snapshots().map(
      (s) => s.docs.map((d) => ({...d.data(), 'id': d.id})).toList(),
    );
  }

  /// Fetch room rankings (Live stream from active cycles with fallback)
  Stream<List<Map<String, dynamic>>> rankingsStream() {
    return _db
        .collection('room_support_cycles')
        .orderBy('totalCoins', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isNotEmpty) {
            final List<Map<String, dynamic>> results = [];
            for (final doc in snap.docs) {
              final data = doc.data();
              final roomId = doc.id;
              String roomName = data['roomName'] ?? '';
              
              // If roomName not cached in cycle doc, fetch from rooms collection
              if (roomName.isEmpty) {
                try {
                  final roomDoc = await _db.collection('rooms').doc(roomId).get();
                  if (roomDoc.exists) {
                    roomName = roomDoc.data()?['name'] ?? roomDoc.data()?['title'] ?? 'Room #$roomId';
                  }
                } catch (_) {}
              }
              if (roomName.isEmpty) roomName = 'Room #$roomId';

              results.add({
                'id': roomId,
                'roomId': roomId,
                'roomName': roomName,
                'totalCoins': (data['totalCoins'] as num?)?.toInt() ?? 0,
                'level': data['level'] ?? 1,
              });
            }
            return results;
          }

          // Fallback to active rooms collection
          final roomsSnap = await _db
              .collection('rooms')
              .where('status', isEqualTo: 'active')
              .limit(50)
              .get();

          return roomsSnap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'roomId': d.id,
              'roomName': data['name'] ?? data['title'] ?? 'Room #${d.id}',
              'totalCoins': (data['totalCoins'] as num?)?.toInt() ?? (data['weeklyCoins'] as num?)?.toInt() ?? 0,
              'level': data['level'] ?? 1,
            };
          }).toList();
        });
  }

  /// Assign a salary partner (owner only, Mon-Tue only)
  Future<void> assignPartner(String roomId, String partnerUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await user.getIdToken(false);
    await callFunction('assignRoomPartner', {
      'roomId': roomId,
      'partnerUid': partnerUid,
    });
  }

  /// Remove a salary partner
  Future<void> removePartner(String roomId, String partnerUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await user.getIdToken(false);
    await callFunction('removeRoomPartner', {
      'roomId': roomId,
      'partnerUid': partnerUid,
    });
  }
}
