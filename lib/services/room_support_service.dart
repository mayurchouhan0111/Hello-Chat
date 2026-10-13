import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    return _db.collection('room_support_configs').doc('settings').snapshots().map((s) {
      final d = s.data();
      if (d == null) return null;
      return Map<String, dynamic>.from(d);
    });
  }

  /// Fetch current cycle for a room
  Stream<Map<String, dynamic>?> cycleStream(String roomId) {
    return _db.collection('room_support_cycles').doc(roomId).snapshots().map((s) {
      final d = s.data();
      if (d == null) return null;
      return Map<String, dynamic>.from(d);
    });
  }

  /// Evaluates whether a partner document is active for the current salary assignment cycle.
  /// Partners from the previous cycle are automatically inactive once the Wednesday payout completes,
  /// ensuring they never remain visible on Wednesday, Thursday, Friday, Saturday, or Sunday.
  static bool isPartnerActiveForCycle(Map<String, dynamic> data, [DateTime? nowUtc]) {
    final now = nowUtc ?? DateTime.now().toUtc();
    final isMonOrTue = (now.weekday == DateTime.monday || now.weekday == DateTime.tuesday);

    // 1. Filter out already paid, archived, or expired partners
    if (data['paid'] == true || data['status'] == 'paid' || data['status'] == 'expired') {
      return false;
    }

    // 2. Outside Monday-Tuesday window (Wednesday through Sunday):
    // Wednesday salary process has executed or assignment is closed.
    // Partners from the previous salary cycle must NEVER remain visible on Wed, Thu, Fri, Sat, Sun.
    if (!isMonOrTue) {
      return false;
    }

    // 3. During Monday-Tuesday: Only show partners assigned for the CURRENT cycle
    // (assigned on or after Monday 00:00 UTC of this week).
    final assignedAt = data['assignedAt'];
    if (assignedAt is Timestamp) {
      final daysSinceMonday = now.weekday - DateTime.monday;
      final mondayStart = DateTime.utc(now.year, now.month, now.day - daysSinceMonday, 0, 0, 0);
      if (assignedAt.toDate().isBefore(mondayStart)) {
        return false;
      }
    } else if (assignedAt is DateTime) {
      final daysSinceMonday = now.weekday - DateTime.monday;
      final mondayStart = DateTime.utc(now.year, now.month, now.day - daysSinceMonday, 0, 0, 0);
      if (assignedAt.isBefore(mondayStart)) {
        return false;
      }
    }

    return true;
  }

  /// Fetch active salary partners for a room for the current cycle
  Stream<List<Map<String, dynamic>>> partnersStream(String roomId) {
    return _db.collection('room_support_cycles').doc(roomId).collection('partners').snapshots().map(
      (s) => s.docs
          .where((d) => isPartnerActiveForCycle(d.data()))
          .map((d) {
            final map = Map<String, dynamic>.from(d.data());
            map['id'] = d.id;
            return map;
          }).toList(),
    );
  }

  /// Fetch weekly history for a room
  Stream<List<Map<String, dynamic>>> historyStream(String roomId) {
    return _db.collection('room_support_history').doc(roomId).collection('weeks')
      .orderBy('weekEnd', descending: true).limit(10).snapshots().map(
      (s) => s.docs.map((d) {
        final map = Map<String, dynamic>.from(d.data());
        map['id'] = d.id;
        return map;
      }).toList(),
    );
  }

  static const List<Map<String, dynamic>> defaultLevels = [
    {'level': 1, 'coinsTarget': 100000, 'partnerSlots': 4, 'ownerReward': 11250, 'partnerReward': 1875, 'totalReward': 18750},
    {'level': 2, 'coinsTarget': 300000, 'partnerSlots': 4, 'ownerReward': 32850, 'partnerReward': 4050, 'totalReward': 49050},
    {'level': 3, 'coinsTarget': 500000, 'partnerSlots': 4, 'ownerReward': 49700, 'partnerReward': 5075, 'totalReward': 70000},
    {'level': 4, 'coinsTarget': 1000000, 'partnerSlots': 5, 'ownerReward': 96600, 'partnerReward': 8680, 'totalReward': 140000},
    {'level': 5, 'coinsTarget': 2000000, 'partnerSlots': 5, 'ownerReward': 200000, 'partnerReward': 18000, 'totalReward': 290000},
    {'level': 6, 'coinsTarget': 3500000, 'partnerSlots': 6, 'ownerReward': 360000, 'partnerReward': 30000, 'totalReward': 540000},
    {'level': 7, 'coinsTarget': 5000000, 'partnerSlots': 6, 'ownerReward': 525000, 'partnerReward': 45000, 'totalReward': 795000},
    {'level': 8, 'coinsTarget': 8000000, 'partnerSlots': 7, 'ownerReward': 840000, 'partnerReward': 70000, 'totalReward': 1330000},
    {'level': 9, 'coinsTarget': 12000000, 'partnerSlots': 7, 'ownerReward': 1280000, 'partnerReward': 100000, 'totalReward': 1980000},
    {'level': 10, 'coinsTarget': 18000000, 'partnerSlots': 8, 'ownerReward': 1950000, 'partnerReward': 150000, 'totalReward': 3150000},
    {'level': 11, 'coinsTarget': 25000000, 'partnerSlots': 8, 'ownerReward': 2750000, 'partnerReward': 200000, 'totalReward': 4350000},
    {'level': 12, 'coinsTarget': 35000000, 'partnerSlots': 9, 'ownerReward': 3900000, 'partnerReward': 280000, 'totalReward': 6420000},
    {'level': 13, 'coinsTarget': 50000000, 'partnerSlots': 9, 'ownerReward': 5600000, 'partnerReward': 400000, 'totalReward': 9200000},
    {'level': 14, 'coinsTarget': 75000000, 'partnerSlots': 10, 'ownerReward': 8500000, 'partnerReward': 600000, 'totalReward': 14500000},
    {'level': 15, 'coinsTarget': 100000000, 'partnerSlots': 10, 'ownerReward': 11500000, 'partnerReward': 850000, 'totalReward': 20000000},
    {'level': 16, 'coinsTarget': 150000000, 'partnerSlots': 11, 'ownerReward': 17500000, 'partnerReward': 1250000, 'totalReward': 31250000},
    {'level': 17, 'coinsTarget': 200000000, 'partnerSlots': 11, 'ownerReward': 23500000, 'partnerReward': 1700000, 'totalReward': 42200000},
    {'level': 18, 'coinsTarget': 300000000, 'partnerSlots': 12, 'ownerReward': 35500000, 'partnerReward': 2500000, 'totalReward': 65500000},
    {'level': 19, 'coinsTarget': 450000000, 'partnerSlots': 12, 'ownerReward': 54000000, 'partnerReward': 3800000, 'totalReward': 99600000},
    {'level': 20, 'coinsTarget': 600000000, 'partnerSlots': 12, 'ownerReward': 72000000, 'partnerReward': 5000000, 'totalReward': 132000000},
  ];

  static int calculateLevel(int totalCoins, [List<Map<String, dynamic>>? levels]) {
    final list = (levels != null && levels.isNotEmpty) ? levels : defaultLevels;
    final sorted = List<Map<String, dynamic>>.from(list)
      ..sort((a, b) => ((a['coinsTarget'] as num?)?.toInt() ?? 0).compareTo((b['coinsTarget'] as num?)?.toInt() ?? 0));
    int level = 0;
    for (final l in sorted) {
      final lvl = (l['level'] as num?)?.toInt() ?? 0;
      final target = (l['coinsTarget'] as num?)?.toInt() ?? 0;
      if (totalCoins >= target && lvl > level) level = lvl;
    }
    return level;
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

              final level = calculateLevel(totalCoins);

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
            final level = calculateLevel(totalCoins);

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
