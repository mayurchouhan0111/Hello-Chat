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

  /// Fetch room rankings
  Stream<List<Map<String, dynamic>>> rankingsStream() {
    return _db.collection('room_support_rankings').doc('rankings')
      .collection('rooms').orderBy('totalCoins', descending: true).limit(50).snapshots().map(
      (s) => s.docs.map((d) => ({...d.data(), 'id': d.id})).toList(),
    );
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
