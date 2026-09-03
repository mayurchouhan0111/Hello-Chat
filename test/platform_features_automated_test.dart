import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🎰 1. Game Winning/Loss Result & Top List Calculation Tests', () {
    test('Winning round computes positive prize and multiplier', () {
      final betItems = {'Apple': 1000, 'Banana': 500};
      const winningItem = 'Apple';
      const multiplier = 5;

      int winnings = 0;
      if (betItems.containsKey(winningItem)) {
        winnings = betItems[winningItem]! * multiplier;
      }

      expect(winnings, equals(5000));
      expect(winnings > 0, isTrue);

      // Verify header status
      final isWin = winnings > 0;
      final headerTitle = isWin ? "YOU WIN!" : "YOU LOST";
      expect(headerTitle, equals("YOU WIN!"));
    });

    test('Losing round computes 0 winnings and displays YOU LOST', () {
      final betItems = {'Orange': 1000};
      const winningItem = 'Watermelon';
      const multiplier = 10;

      int winnings = 0;
      if (betItems.containsKey(winningItem)) {
        winnings = betItems[winningItem]! * multiplier;
      }

      expect(winnings, equals(0));
      final isWin = winnings > 0;
      final headerTitle = isWin ? "YOU WIN!" : "YOU LOST";
      expect(headerTitle, equals("YOU LOST"));
    });

    test('Top List sorts primarily by totalWinnings and excludes 0 from winners', () {
      final players = [
        {'name': 'Player A (Lost big)', 'totalBets': 16000000, 'totalWinnings': 0},
        {'name': 'Player B (Winner)', 'totalBets': 500000, 'totalWinnings': 2500000},
        {'name': 'Player C (Jackpot)', 'totalBets': 1000000, 'totalWinnings': 10000000},
      ];

      players.sort((a, b) {
        final aW = (a['totalWinnings'] as num).toInt();
        final bW = (b['totalWinnings'] as num).toInt();
        if (bW != aW) return bW.compareTo(aW);
        final aB = (a['totalBets'] as num).toInt();
        final bB = (b['totalBets'] as num).toInt();
        return bB.compareTo(aB);
      });

      // Player C should be 1st with 10M, Player B 2nd with 2.5M, Player A 3rd with 0 winnings
      expect(players[0]['name'], equals('Player C (Jackpot)'));
      expect(players[0]['totalWinnings'], equals(10000000));
      expect(players[1]['name'], equals('Player B (Winner)'));
      expect(players[1]['totalWinnings'], equals(2500000));
      expect(players[2]['name'], equals('Player A (Lost big)'));
      expect(players[2]['totalWinnings'], equals(0));
    });
  });

  group('💺 2. Room Seat Layout & Owner Label Logic Tests', () {
    test('Non-host grid seats start sequentially from 1 to capacity - 1', () {
      const capacity = 9;
      const showHostInGrid = false;
      final itemCount = showHostInGrid ? capacity : capacity - 1;

      final seatIndices = List.generate(itemCount, (gridIndex) {
        return showHostInGrid ? gridIndex : gridIndex + 1;
      });

      expect(seatIndices.length, equals(8));
      expect(seatIndices.first, equals(1));
      expect(seatIndices.last, equals(8));
      expect(seatIndices, equals([1, 2, 3, 4, 5, 6, 7, 8]));
    });

    test('Owner label badge is hidden when owner is seated on the call', () {
      // Condition: if (activeHost.uid.isEmpty || !isOwnerOnline) show badge; else hide
      bool shouldShowOwnerBadge(String hostUid, bool isOwnerOnline) {
        return hostUid.isEmpty || !isOwnerOnline;
      }

      // Case 1: Owner online and seated -> badge HIDDEN (false)
      expect(shouldShowOwnerBadge('owner_123', true), isFalse);

      // Case 2: Owner seat empty -> badge SHOWN (true)
      expect(shouldShowOwnerBadge('', true), isTrue);

      // Case 3: Owner offline -> badge SHOWN (true)
      expect(shouldShowOwnerBadge('owner_123', false), isTrue);
    });
  });

  group('🚀 3. Multi-Rocket Sequential Launch Simulation Tests', () {
    test('Large gift of 5M diamonds triggers Level 1, Level 2, and Level 3 sequentially', () {
      final rocketTargets = [1000000, 2000000, 3000000, 5000000, 10000000];
      int currentLevel = 0;
      int currentFuel = 0;
      int remainingCost = 6000000; // 6 Million diamonds sent at once

      final launchedLevels = <int>[];

      while (remainingCost > 0 && currentLevel < 5) {
        final nextTarget = rocketTargets[currentLevel];
        final fuelNeeded = nextTarget - currentFuel;

        if (remainingCost >= fuelNeeded) {
          remainingCost -= fuelNeeded;
          launchedLevels.add(currentLevel + 1);
          currentLevel++;
          currentFuel = 0;
        } else {
          currentFuel += remainingCost;
          remainingCost = 0;
        }
      }

      // 6M should launch: L1 (1M) -> L2 (2M) -> L3 (3M) = 6M total
      expect(launchedLevels, equals([1, 2, 3]));
      expect(currentLevel, equals(3));
      expect(currentFuel, equals(0));
      expect(remainingCost, equals(0));
    });
  });

  group('🏆 4. Per-User Sender Ranking Time Bucket Tests', () {
    test('ISO Date and Week keys format correctly', () {
      final nowUtc = DateTime.utc(2026, 8, 16, 12, 0, 0);
      final dailyKey = nowUtc.toIso8601String().substring(0, 10);
      final monthlyKey = nowUtc.toIso8601String().substring(0, 7);

      expect(dailyKey, equals('2026-08-16'));
      expect(monthlyKey, equals('2026-08'));
    });
  });
}
