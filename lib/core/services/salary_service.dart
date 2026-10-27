import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';
import '../models/salary_model.dart';

class SalaryService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Main logic to process new earnings and check for milestones.
  /// This should be called whenever a host receives beans.
  Future<void> processEarnings(String hostUid, int beansReceived) async {
    final statusRef = _db.collection('salaryStatus').doc(hostUid);
    final userRef = _db.collection('users').doc(hostUid);

    await _db.runTransaction((transaction) async {
      final statusDoc = await transaction.get(statusRef);
      final userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) return;
      
      SalaryStatus status;
      if (!statusDoc.exists) {
        status = SalaryStatus(
          uid: hostUid,
          lastDailyPayout: DateTime.now(),
          lastBiWeeklyPayout: DateTime.now(),
        );
      } else {
        status = SalaryStatus.fromMap(statusDoc.data()!);
      }

      final newTotalBeans = status.totalBeansEarned + beansReceived;
      final newMonthBeans = status.currentMonthBeans + beansReceived;
      
      // Check for new milestones reached
      List<int> newlyReachedLevels = [];
      for (var lv in SalaryLevel.allLevels) {
        if (newTotalBeans >= lv.targetBeans && !status.completedLevels.contains(lv.level)) {
          newlyReachedLevels.add(lv.level);
        }
      }

      // Update status
      final updatedStatus = SalaryStatus(
        uid: hostUid,
        totalBeansEarned: newTotalBeans,
        currentMonthBeans: newMonthBeans,
        completedLevels: [...status.completedLevels, ...newlyReachedLevels],
        currentLevel: newlyReachedLevels.isNotEmpty ? newlyReachedLevels.last : status.currentLevel,
        lastDailyPayout: status.lastDailyPayout,
        lastBiWeeklyPayout: status.lastBiWeeklyPayout,
      );

      transaction.set(statusRef, updatedStatus.toMap());

      // Target-based status tracking. Automated financial payouts and dollar-crediting
      // are permanently disabled on client. Only Cloud Functions with verified business logic
      // and explicit authorization may drive financial transactions.
    });
  }


  /// Fetches the user's current salary status.
  Stream<SalaryStatus?> getSalaryStatus(String uid) {
    return _db.collection('salaryStatus').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SalaryStatus.fromMap(doc.data()!);
    }).handleError((err) {
      debugPrint("Error fetching salary status: $err");
      return null;
    });
  }

  /// Fetches pending and past payouts for a user.
  Stream<List<SalaryPayout>> getPayoutHistory(String uid) {
    return _db.collection('salaryPayouts')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => SalaryPayout.fromMap(doc.data(), doc.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((err) {
          debugPrint("Error fetching payout history: $err");
          return <SalaryPayout>[];
        });
  }



  /// Generates ISO 8601 UTC week ID (e.g. 2026-W35) matching Monday-Sunday week bounds.
  static String getUtcWeekId(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final dayNum = d.weekday;
    final thursday = d.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    final weekStr = weekNo < 10 ? '0$weekNo' : '$weekNo';
    return '${thursday.year}-W$weekStr';
  }

  /// Stream strictly current week's earnings and target progress (resetting Monday 00:00 UTC)
  Stream<Map<String, dynamic>> getWeeklyTargetStatus(String uid) {
    final currentWeekId = getUtcWeekId(DateTime.now().toUtc());
    return _db.collection('users').doc(uid).collection('weeklyTargets').doc(currentWeekId).snapshots().map((doc) {
      if (!doc.exists) {
        return {
          'weekId': currentWeekId,
          'weeklyBeans': 0,
          'targetBeans': 50000,
          'progress': 0.0,
        };
      }
      final data = doc.data()!;
      final beans = (data['weeklyBeans'] as num?)?.toInt() ?? 0;
      final target = (data['targetBeans'] as num?)?.toInt() ?? 50000;
      return {
        'weekId': currentWeekId,
        'weeklyBeans': beans,
        'targetBeans': target,
        'progress': target > 0 ? (beans / target).clamp(0.0, 1.0) : 0.0,
      };
    }).handleError((_) {
      return {
        'weekId': currentWeekId,
        'weeklyBeans': 0,
        'targetBeans': 50000,
        'progress': 0.0,
      };
    });
  }
}

final salaryServiceProvider = Provider<SalaryService>((ref) => SalaryService());

final salaryStatusProvider = StreamProvider.family<SalaryStatus?, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getSalaryStatus(uid);
});

final payoutHistoryProvider = StreamProvider.family<List<SalaryPayout>, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getPayoutHistory(uid);
});

final weeklyTargetStatusProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getWeeklyTargetStatus(uid);
});

final hostMetricsProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('host_metrics').doc(uid).snapshots().map((doc) {
    if (!doc.exists) {
      return {
        'liveMinutesTotal': 0,
        'liveHoursTotal': 0.0,
        'liveDayCount': 0,
        'liveSessionsTotal': 0,
      };
    }
    final data = doc.data()!;
    final minutes = (data['liveMinutesTotal'] as num?)?.toInt() ?? 0;
    final byDay = data['liveMinutesByDay'] as Map<String, dynamic>? ?? {};
    final sessions = (data['liveSessionsTotal'] as num?)?.toInt() ?? 0;
    return {
      'liveMinutesTotal': minutes,
      'liveHoursTotal': (minutes / 60.0),
      'liveDayCount': byDay.keys.length,
      'liveSessionsTotal': sessions,
      'monthlyTargetBeans': (data['monthlyTargetBeans'] as num?)?.toInt(),
      'totalRechargeUSD': (data['totalRechargeUSD'] as num?)?.toDouble() ?? (data['totalRechargeGenerated'] as num?)?.toDouble(),
    };
  }).handleError((_) {
    return {
      'liveMinutesTotal': 0,
      'liveHoursTotal': 0.0,
      'liveDayCount': 0,
      'liveSessionsTotal': 0,
      'monthlyTargetBeans': null,
      'totalRechargeUSD': 0.0,
    };
  });
});

