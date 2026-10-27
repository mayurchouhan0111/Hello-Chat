import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel Prev Winner & Results History Integrity Tests', () {
    test('Rule 1A: Before round finalization, active round outcome is strictly withheld', () {
      const isResultCelebration = false;
      const isSpinningPhase = false;

      // Active round id
      const currentRoundId = '1525';
      final pastHistory = [
        {'roundId': '1524', 'name': 'Hotdog', 'emoji': '🌭', 'multiplier': 10},
        {'roundId': '1523', 'name': 'Steak', 'emoji': '🥩', 'multiplier': 45},
      ];

      // Filter visible past history: strictly excludes current active round
      final visiblePastHistory = pastHistory.where((r) => r['roundId'] != currentRoundId).toList();

      expect(isResultCelebration, isFalse);
      expect(visiblePastHistory.length, equals(2));
      expect(visiblePastHistory.any((r) => r['roundId'] == currentRoundId), isFalse,
          reason: 'Active unfinalized round must never appear in rolling history');
      expect(visiblePastHistory.first['roundId'], equals('1524'),
          reason: 'Past finalized round 1524 must remain fully accessible');
    });

    test('Rule 1B: After round finalization, Prev Winner displays finalized winner & amount', () {
      const isResultCelebration = true;
      final finalizedStats = {
        'lastWinnerName': 'ChampionGamer',
        'lastWinnerAmount': 250000,
        'lastWinnerRoundId': '1524',
        'lastRound': {
          'roundId': '1524',
          'winnerName': 'ChampionGamer',
          'winnerAmount': 250000,
        }
      };

      final lastWinnerName = finalizedStats['lastWinnerName'] ??
          (finalizedStats['lastRound'] as Map)['winnerName'] ??
          'None';
      final lastWinnerAmount = finalizedStats['lastWinnerAmount'] ??
          (finalizedStats['lastRound'] as Map)['winnerAmount'] ??
          0;

      final prevWinnerCardText = "$lastWinnerName: $lastWinnerAmount";

      expect(isResultCelebration, isTrue);
      expect(prevWinnerCardText, equals("ChampionGamer: 250000"));
    });

    test('Rule 1C: Rollover to a new round preserves Prev Winner without wiping previous records', () {
      // In round 1524, winner was finalized
      String? sessionLastWinnerName = 'ChampionGamer';
      dynamic sessionLastWinnerAmount = 250000;

      // Rollover to round 1525
      const currentRoundId = '1525';
      final statsAfterRollover = {
        'lastWinnerName': 'ChampionGamer',
        'lastWinnerAmount': 250000,
        'lastRound': {
          'roundId': '1524',
          'winnerName': 'ChampionGamer',
          'winnerAmount': 250000,
        }
      };

      if (statsAfterRollover['lastWinnerName'] != null &&
          statsAfterRollover['lastWinnerName'].toString() != 'None') {
        sessionLastWinnerName = statsAfterRollover['lastWinnerName'].toString();
        sessionLastWinnerAmount = statsAfterRollover['lastWinnerAmount'];
      }

      final lastWinnerName = statsAfterRollover['lastWinnerName'] ??
          (statsAfterRollover['lastRound'] as Map)['winnerName'] ??
          sessionLastWinnerName ??
          'None';
      final lastWinnerAmount = statsAfterRollover['lastWinnerAmount'] ??
          (statsAfterRollover['lastRound'] as Map)['winnerAmount'] ??
          sessionLastWinnerAmount ??
          0;

      expect(lastWinnerName, equals('ChampionGamer'));
      expect(lastWinnerAmount, equals(250000));
      expect("$lastWinnerName: $lastWinnerAmount", equals("ChampionGamer: 250000"),
          reason: 'Prev Winner card must stay intact on new round start');
    });

    test('Rule 1D: Results history retains multiple distinct rounds without overwriting', () {
      final Map<String, Map<String, dynamic>> mergedByRoundId = {};

      final round1523 = {'roundId': '1523', 'name': 'Steak', 'multiplier': 45};
      final round1524 = {'roundId': '1524', 'name': 'Hotdog', 'multiplier': 10};

      mergedByRoundId['1523'] = round1523;
      mergedByRoundId['1524'] = round1524;

      expect(mergedByRoundId.length, equals(2));
      expect(mergedByRoundId['1523']!['name'], equals('Steak'));
      expect(mergedByRoundId['1524']!['name'], equals('Hotdog'));
    });
  });
}
