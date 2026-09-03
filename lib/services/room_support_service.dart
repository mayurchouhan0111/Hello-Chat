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
              String coverUrl = data['coverUrl'] ?? '';
              final totalCoins = (data['totalCoins'] as num?)?.toInt() ?? 0;
              
              // If roomName / coverUrl not cached in cycle doc, fetch from rooms collection
              if (roomName.isEmpty || coverUrl.isEmpty) {
                try {
                  final roomDoc = await _db.collection('rooms').doc(roomId).get();
                  if (roomDoc.exists) {
                    final rData = roomDoc.data();
                    if (roomName.isEmpty) {
                      roomName = rData?['name'] ?? rData?['title'] ?? 'Room #$roomId';
                    }
                    if (coverUrl.isEmpty) {
                      coverUrl = rData?['coverUrl'] ?? '';
                    }
                  }
                } catch (_) {}
              }
              if (roomName.isEmpty) roomName = 'Room #$roomId';

              int level = 0;
              if (totalCoins >= 300000000) {
                level = 7;
              } else if (totalCoins >= 200000000) {
                level = 6;
              } else if (totalCoins >= 100000000) {
                level = 5;
              } else if (totalCoins >= 50000000) {
                level = 4;
              } else if (totalCoins >= 30000000) {
                level = 3;
              } else if (totalCoins >= 20000000) {
                level = 2;
              } else if (totalCoins >= 10000000) {
                level = 1;
              }

              results.add({
                'id': roomId,
                'roomId': roomId,
                'roomName': roomName,
                'coverUrl': coverUrl,
                'totalCoins': totalCoins,
                'level': level,
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
            final totalCoins = (data['weeklyEarnings'] as num?)?.toInt() ?? (data['totalCoins'] as num?)?.toInt() ?? 0;
            int level = 0;
            if (totalCoins >= 300000000) {
              level = 7;
            } else if (totalCoins >= 200000000) {
              level = 6;
            } else if (totalCoins >= 100000000) {
              level = 5;
            } else if (totalCoins >= 50000000) {
              level = 4;
            } else if (totalCoins >= 30000000) {
              level = 3;
            } else if (totalCoins >= 20000000) {
              level = 2;
            } else if (totalCoins >= 10000000) {
              level = 1;
            }

            return {
              'id': d.id,
              'roomId': d.id,
              'roomName': data['name'] ?? data['title'] ?? 'Room #${d.id}',
              'coverUrl': data['coverUrl'] ?? '',
              'totalCoins': totalCoins,
              'level': level,
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
