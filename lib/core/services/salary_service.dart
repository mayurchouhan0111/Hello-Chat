import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';
import '../models/salary_model.dart';
import '../models/user_model.dart';
import '../models/agency_model.dart';

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
      final user = UserModel.fromMap(userDoc.data()!);
      
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

      // Process distributions for each new level reached
      for (var level in newlyReachedLevels) {
        await _createPayoutsForLevel(transaction, user, level);
      }
    });
  }

  /// Calculates and creates payout documents for a specific level milestone.
  Future<void> _createPayoutsForLevel(Transaction transaction, UserModel host, int level) async {
    final salaryLevel = SalaryLevel.getLevel(level);
    final now = DateTime.now();
    
    // 1. Host Payout (60%) - Available Next Day
    final hostPayoutDate = DateTime(now.year, now.month, now.day + 1);
    final hostPayoutRef = _db.collection('salaryPayouts').doc();
    transaction.set(hostPayoutRef, SalaryPayout(
      id: hostPayoutRef.id,
      uid: host.uid,
      amount: salaryLevel.hostShare,
      type: 'host',
      level: level,
      scheduledDate: hostPayoutDate,
      createdAt: now,
    ).toMap());

    // 2. Agency Payout (30%) - Bi-Weekly (15th or 30th)
    if (host.agencyId != null) {
      final agencyPayoutDate = _getNextBiWeeklyDate(now);
      final agencyPayoutRef = _db.collection('salaryPayouts').doc();
      transaction.set(agencyPayoutRef, SalaryPayout(
        id: agencyPayoutRef.id,
        uid: host.uid, // Tracked under host but for agency
        agencyId: host.agencyId,
        amount: salaryLevel.agencyShare,
        type: 'agency',
        level: level,
        scheduledDate: agencyPayoutDate,
        createdAt: now,
      ).toMap());
    }

    // 3. Admin Payout (10%) - Bi-Weekly
    final adminPayoutDate = _getNextBiWeeklyDate(now);
    final adminPayoutRef = _db.collection('salaryPayouts').doc();
    transaction.set(adminPayoutRef, SalaryPayout(
      id: adminPayoutRef.id,
      uid: 'SYSTEM_ADMIN',
      amount: salaryLevel.adminShare,
      type: 'admin',
      level: level,
      scheduledDate: adminPayoutDate,
      createdAt: now,
    ).toMap());
  }

  /// Calculates the next payout date (15th or End of Month).
  DateTime _getNextBiWeeklyDate(DateTime now) {
    if (now.day < 15) {
      return DateTime(now.year, now.month, 15);
    } else {
      // Last day of current month
      return DateTime(now.year, now.month + 1, 0);
    }
  }

  /// Fetches the user's current salary status.
  Stream<SalaryStatus?> getSalaryStatus(String uid) {
    return _db.collection('salaryStatus').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SalaryStatus.fromMap(doc.data()!);
    });
  }

  /// Fetches pending and past payouts for a user.
  Stream<List<SalaryPayout>> getPayoutHistory(String uid) {
    return _db.collection('salaryPayouts')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => SalaryPayout.fromMap(doc.data(), doc.id)).toList());
  }

  /// (Admin Utility) Processes all due payouts and updates wallet balances.
  Future<void> processScheduledPayouts() async {
    final now = DateTime.now();
    final query = await _db.collection('salaryPayouts')
        .where('status', isEqualTo: 'pending')
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .limit(50) // Process in chunks for stability
        .get();

    for (var doc in query.docs) {
      final payout = SalaryPayout.fromMap(doc.data(), doc.id);
      
      try {
        await _db.runTransaction((transaction) async {
          // 1. Double-check status inside transaction
          final freshDoc = await transaction.get(doc.reference);
          if (freshDoc.data()?['status'] == 'paid') return;

          // 2. Update status to paid
          transaction.update(doc.reference, {'status': 'paid'});

          // 3. Add to wallet balance and log transaction
          if (payout.type == 'host') {
            final userRef = _db.collection('users').doc(payout.uid);
            final userSnapshot = await transaction.get(userRef);
            if (!userSnapshot.exists) return;

            transaction.update(userRef, {
              'walletBalance': FieldValue.increment(payout.amount),
            });
            
            // Log in user's transaction history
            final txRef = userRef.collection('transactions').doc();
            transaction.set(txRef, {
              'id': txRef.id,
              'amount': payout.amount,
              'type': 'salary_reward',
              'category': 'wallet',
              'description': 'Level ${payout.level} Host Reward',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
            });
          } else if (payout.type == 'agency' && payout.agencyId != null) {
            final agencyRef = _db.collection('agencies').doc(payout.agencyId);
            final agencySnapshot = await transaction.get(agencyRef);
            if (!agencySnapshot.exists) return;

            transaction.update(agencyRef, {
              'beansBalance': FieldValue.increment(payout.amount.toInt()),
            });

            // Log in global transactions for audit
            final globalTxRef = _db.collection('transactions').doc();
            transaction.set(globalTxRef, {
              'id': globalTxRef.id,
              'uid': payout.uid,
              'agencyId': payout.agencyId,
              'amount': payout.amount,
              'type': 'salary_reward',
              'category': 'bean',
              'milestone': 'level_${payout.level}',
              'description': 'Level ${payout.level} Agency Share (Host: ${payout.uid})',
              'timestamp': FieldValue.serverTimestamp(),
            });
          } else if (payout.type == 'admin') {
            // Update global platform stats
            final statsRef = _db.collection('platformStats').doc('revenue');
            transaction.set(statsRef, {
              'totalAdminEarnings': FieldValue.increment(payout.amount),
              'lastUpdate': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // Log global transaction
            final globalTxRef = _db.collection('transactions').doc();
            transaction.set(globalTxRef, {
              'id': globalTxRef.id,
              'type': 'admin_commission',
              'amount': payout.amount,
              'description': 'Level ${payout.level} Admin Share (Host: ${payout.uid})',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        });
      } catch (e) {
        print("Error processing payout ${payout.id}: $e");
      }
    }
  }

  /// (Admin) Get total volume of payouts for a specific type.
  Future<double> getAdminTotalPayouts(String type) async {
    final query = await _db.collection('salaryPayouts')
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: 'paid')
        .get();
    
    double total = 0;
    for (var doc in query.docs) {
      total += (doc.data()['amount'] as num).toDouble();
    }
    return total;
  }
}

final salaryServiceProvider = Provider<SalaryService>((ref) => SalaryService());

final salaryStatusProvider = StreamProvider.family<SalaryStatus?, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getSalaryStatus(uid);
});

final payoutHistoryProvider = StreamProvider.family<List<SalaryPayout>, String>((ref, uid) {
  return ref.watch(salaryServiceProvider).getPayoutHistory(uid);
});
