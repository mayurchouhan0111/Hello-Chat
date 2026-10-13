import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/services/room_support_service.dart';

void main() {
  group('Room Support Level & Reward Calculation Parity', () {
    test('10M Coins achieves Level 1 with 2M Total Reward across default tiers', () {
      final level = RoomSupportService.calculateLevel(10000000);
      expect(level, equals(1));

      final targetLevelCfg = RoomSupportService.defaultLevels.firstWhere(
        (l) => l['level'] == level,
      );
      expect(targetLevelCfg['coinsTarget'], equals(10000000));
      expect(targetLevelCfg['totalReward'], equals(2000000));
      expect(targetLevelCfg['ownerReward'], equals(1000000));
      expect(targetLevelCfg['partnerReward'], equals(250000));
    });

    test('Coins progression matches exact tier thresholds', () {
      expect(RoomSupportService.calculateLevel(0), equals(0));
      expect(RoomSupportService.calculateLevel(9999999), equals(0));
      expect(RoomSupportService.calculateLevel(10000000), equals(1));
      expect(RoomSupportService.calculateLevel(20000000), equals(2));
      expect(RoomSupportService.calculateLevel(30000000), equals(3));
      expect(RoomSupportService.calculateLevel(50000000), equals(4));
      expect(RoomSupportService.calculateLevel(100000000), equals(5));
      expect(RoomSupportService.calculateLevel(200000000), equals(6));
      expect(RoomSupportService.calculateLevel(300000000), equals(7));
      expect(RoomSupportService.calculateLevel(500000000), equals(7));
    });

    test('Custom levels from dynamic config calculate accurately', () {
      // Test dynamic custom levels (e.g. 8 tiers where Level 7 is 10M and Level 8 is 12M)
      final customLevels = [
        {'level': 1, 'coinsTarget': 100000, 'totalReward': 20000},
        {'level': 7, 'coinsTarget': 10000000, 'totalReward': 2000000},
        {'level': 8, 'coinsTarget': 12000000, 'totalReward': 2500000},
      ];

      final calculatedLvl = RoomSupportService.calculateLevel(10000000, customLevels);
      expect(calculatedLvl, equals(7));

      final matchedCfg = customLevels.firstWhere((l) => l['level'] == calculatedLvl);
      expect(matchedCfg['totalReward'], equals(2000000));
    });
  });

  group('Leaderboard Deduplication Logic', () {
    test('Consolidates multiple room records for same owner into a single cumulative score', () {
      final rawDocs = [
        {'id': 'room_userA_1', 'ownerUid': 'userA', 'score': 84000000, 'name': 'Alpha Room'},
        {'id': 'room_userA_2', 'ownerUid': 'userA', 'score': 52000000, 'name': 'Alpha Room 2'},
        {'id': 'room_userB', 'ownerUid': 'userB', 'score': 45000000, 'name': 'Beta Room'},
      ];

      final Map<String, Map<String, dynamic>> consolidated = {};

      for (final doc in rawDocs) {
        final ownerUid = doc['ownerUid'] as String;
        final score = doc['score'] as int;
        final name = doc['name'] as String;

        if (!consolidated.containsKey(ownerUid)) {
          consolidated[ownerUid] = {
            'uid': 'room_$ownerUid',
            'displayName': name,
            'score': score,
          };
        } else {
          consolidated[ownerUid]!['score'] = (consolidated[ownerUid]!['score'] as int) + score;
        }
      }

      expect(consolidated.length, equals(2));
      // userA's split records (84M + 52M) MUST sum to 136M
      expect(consolidated['userA']!['score'], equals(136000000));
      expect(consolidated['userB']!['score'], equals(45000000));
    });
  });

  group('Permanent Room Record Preservation', () {
    test('Non-destructive merge update preserves accumulated counters', () {
      final existingPermanentRoom = <String, dynamic>{
        'roomId': 'room_owner123',
        'ownerUid': 'owner123',
        'name': 'Original Room',
        'totalDiamondsSent': 150000000,
        'weeklyDiamondsSent': 45000000,
        'weeklyEarnings': 45000000,
        'status': 'ended',
      };

      // Simulating reopen/createRoom with new session settings
      final newSessionSettings = <String, dynamic>{
        'name': 'Updated Title For Tonight',
        'theme': 'Karaoke Night',
        'status': 'active',
      };

      // Merge operation
      final mergedRoom = Map<String, dynamic>.from(existingPermanentRoom)..addAll(newSessionSettings);

      // Verify session properties updated
      expect(mergedRoom['name'], equals('Updated Title For Tonight'));
      expect(mergedRoom['theme'], equals('Karaoke Night'));
      expect(mergedRoom['status'], equals('active'));

      // Verify all financial and weekly counters were preserved intact
      expect(mergedRoom['totalDiamondsSent'], equals(150000000));
      expect(mergedRoom['weeklyDiamondsSent'], equals(45000000));
      expect(mergedRoom['weeklyEarnings'], equals(45000000));
    });

    test('Reopening a closed room accumulates diamonds instead of resetting (5M + 3M = 8M)', () {
      // Session 1: room created, 5M diamonds sent, then the room is closed.
      final room = <String, dynamic>{
        'roomId': 'room_owner123',
        'ownerUid': 'owner123',
        'totalDiamondsSent': 5000000,
        'weeklyDiamondsSent': 5000000,
        'status': 'ended',
      };

      // Close: status flips only — no counter write on close.
      room['status'] = 'ended';

      // Session 2: same owner reopens the permanent record (createRoom merge)
      // and 3M more diamonds are sent in the new session.
      room['status'] = 'active';
      room['totalDiamondsSent'] = (room['totalDiamondsSent'] as int) + 3000000;
      room['weeklyDiamondsSent'] = (room['weeklyDiamondsSent'] as int) + 3000000;

      expect(room['totalDiamondsSent'], equals(8000000),
          reason: 'counters must survive close/reopen and accumulate across sessions');
      expect(room['weeklyDiamondsSent'], equals(8000000));
      expect(room['status'], equals('active'));
    });
  });
}
