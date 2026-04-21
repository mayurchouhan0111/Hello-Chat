import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';

class SalaryService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches the room contribution stats and current progress towards the weekly target.
  Stream<Map<String, dynamic>> getWeeklyProgress(String roomId) {
    return _db.collection('rooms')
        .doc(roomId)
        .collection('salaryMetadata')
        .doc('currentWeek')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  /// Manually triggers a claim if eligible (usually automated by Cloud Functions).
  Future<void> claimSalary() async {
    await callFunction('processUserWeeklySalary', {});
  }

  /// Fetches salary history (payouts received).
  Stream<List<Map<String, dynamic>>> getSalaryHistory(String uid) {
    return _db.collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'salary')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Updates room salary configuration (Admin only).
  Future<void> updateRoomSalaryConfig({
    required String roomId,
    required int weeklyTarget,
    required String distributionMode, // 'equal' or 'weighted'
  }) async {
    await callFunction('updateRoomSalaryConfig', {
      'roomId': roomId,
      'weeklyTarget': weeklyTarget,
      'distributionMode': distributionMode,
    });
  }
}

final salaryServiceProvider = Provider<SalaryService>((ref) => SalaryService());

final weeklyProgressProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, roomId) {
  return ref.watch(salaryServiceProvider).getWeeklyProgress(roomId);
});

final salaryHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getSalaryHistory(uid);
});
