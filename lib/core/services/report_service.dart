import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final reportServiceProvider = Provider((ref) => ReportService());

class ReportService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> submitReport({
    required String targetUid,
    required String reason,
    String? details,
    String? roomId,
  }) async {
    final reporterUid = _auth.currentUser?.uid;
    if (reporterUid == null) return;

    await _db.collection('reports').add({
      'reporterUid': reporterUid,
      'targetUid': targetUid,
      'reason': reason,
      'details': details,
      'roomId': roomId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _db.collection('users').doc(currentUid).update({
      'blockedUids': FieldValue.arrayUnion([targetUid]),
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _db.collection('users').doc(currentUid).update({
      'blockedUids': FieldValue.arrayRemove([targetUid]),
    });
  }
}
