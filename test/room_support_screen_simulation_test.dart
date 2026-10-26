import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/week_helper.dart';

void main() {
  group('Room Support Monday Reset & Phase Simulations', () {

    int calculateLevel(int coins) {
      if (coins >= 75000000) return 14;
      if (coins >= 50000000) return 13;
      if (coins >= 100000) return 1;
      return 0;
    }

    int getRequiredSlots(int level) {
      if (level == 13) return 9;
      if (level == 14) return 10;
      if (level >= 1) return 4;
      return 4;
    }

    test('Simulation 1: Sunday 23:59:00 UTC (End of Week 2026-W43)', () {
      final simTime = DateTime.parse('2026-10-25T23:59:00.000Z');
      final weekId = WeekHelper.getIsoWeekId(simTime);
      final isFillIn = WeekHelper.isFillInWindow(simTime);

      // Room cycle document in Firestore
      final cycle = {
        'weekId': '2026-W43',
        'totalCoins': 50200000,
        'level': 13,
        'lastWeekCoins': 0,
        'lastWeekLevel': 0,
      };

      expect(weekId, equals('2026-W43'));
      expect(isFillIn, isFalse);

      final isMatchingWeek = cycle['weekId'] == weekId;
      expect(isMatchingWeek, isTrue);

      // On Sunday night:
      final thisWeekCoins = isMatchingWeek ? (cycle['totalCoins'] as int) : 0;
      final thisWeekLevel = calculateLevel(thisWeekCoins);

      expect(thisWeekCoins, equals(50200000));
      expect(thisWeekLevel, equals(13));
      print('✅ [Sunday 23:59 UTC] Week: $weekId, This Week Coins: 50.2M, Level: 13, Assignment Open: $isFillIn');
    });

    test('Simulation 2: Monday 00:01:00 UTC (New Week Started, Client Guard Active)', () {
      final simTime = DateTime.parse('2026-10-26T00:01:00.000Z');
      final currentWeekId = WeekHelper.getIsoWeekId(simTime);
      final isFillIn = WeekHelper.isFillInWindow(simTime);

      // Un-updated cycle doc still holds 2026-W43 data from Sunday
      final cycle = {
        'weekId': '2026-W43',
        'totalCoins': 50200000,
        'level': 13,
        'lastWeekCoins': 0,
        'lastWeekLevel': 0,
      };

      expect(currentWeekId, equals('2026-W44'));
      expect(isFillIn, isTrue);

      // CLIENT GUARD EVALUATION:
      final isMatchingWeek = cycle['weekId'] == currentWeekId;
      expect(isMatchingWeek, isFalse); // Stale document!

      int thisWeekCoins = 0;
      int thisWeekLevel = 0;
      int lastWeekCoins = 0;
      int lastWeekLevel = 0;

      if (isMatchingWeek) {
        thisWeekCoins = cycle['totalCoins'] as int;
        thisWeekLevel = cycle['level'] as int;
      } else {
        thisWeekCoins = 0; // RESET TO ZERO!
        thisWeekLevel = 0;
        if (isFillIn) {
          lastWeekCoins = cycle['totalCoins'] as int; // 50.2M transferred to last week
          lastWeekLevel = cycle['level'] as int;     // Level 13 transferred to last week
        }
      }

      final activeLevelForPartners = isFillIn ? (lastWeekLevel > 0 ? lastWeekLevel : thisWeekLevel) : thisWeekLevel;
      final requiredSlots = getRequiredSlots(activeLevelForPartners);

      expect(thisWeekCoins, equals(0));
      expect(thisWeekLevel, equals(0));
      expect(lastWeekCoins, equals(50200000));
      expect(lastWeekLevel, equals(13));
      expect(activeLevelForPartners, equals(13));
      expect(requiredSlots, equals(9));

      print('✅ [Monday 00:01 UTC] Week: $currentWeekId, This Week: 0 Coins (Lvl 0), Last Week: 50.2M (Lvl 13), Slots Open: $requiredSlots');
    });

    test('Simulation 3: Tuesday 23:59:00 UTC (Final Minute of Fill-in Window)', () {
      final simTime = DateTime.parse('2026-10-27T23:59:00.000Z');
      final currentWeekId = WeekHelper.getIsoWeekId(simTime);
      final isFillIn = WeekHelper.isFillInWindow(simTime);

      // Suppose gifts have been sent in W44:
      final cycle = {
        'weekId': '2026-W44',
        'totalCoins': 1250000, // Level 1 reached this week
        'level': 1,
        'lastWeekCoins': 50200000,
        'lastWeekLevel': 13,
      };

      expect(currentWeekId, equals('2026-W44'));
      expect(isFillIn, isTrue);

      final isMatchingWeek = cycle['weekId'] == currentWeekId;
      expect(isMatchingWeek, isTrue);

      final thisWeekCoins = cycle['totalCoins'] as int;
      final thisWeekLevel = calculateLevel(thisWeekCoins);
      final lastWeekCoins = cycle['lastWeekCoins'] as int;
      final lastWeekLevel = cycle['lastWeekLevel'] as int;
      final activeLevelForPartners = isFillIn ? lastWeekLevel : thisWeekLevel;
      final requiredSlots = getRequiredSlots(activeLevelForPartners);

      expect(thisWeekCoins, equals(1250000));
      expect(thisWeekLevel, equals(1));
      expect(lastWeekCoins, equals(50200000));
      expect(lastWeekLevel, equals(13));
      expect(activeLevelForPartners, equals(13));
      expect(requiredSlots, equals(9));

      print('✅ [Tuesday 23:59 UTC] Week: $currentWeekId, This Week: 1.25M (Lvl 1), Last Week: 50.2M (Lvl 13), Slots Still Open: $requiredSlots');
    });

    test('Simulation 4: Wednesday 00:30:00 UTC (Fill-in Window Closed, Rewards Paid)', () {
      final simTime = DateTime.parse('2026-10-28T00:30:00.000Z');
      final currentWeekId = WeekHelper.getIsoWeekId(simTime);
      final isFillIn = WeekHelper.isFillInWindow(simTime);

      expect(currentWeekId, equals('2026-W44'));
      expect(isFillIn, isFalse); // Window closed!

      final cycle = {
        'weekId': '2026-W44',
        'totalCoins': 1250000,
        'level': 1,
        'lastWeekCoins': 50200000,
        'lastWeekLevel': 13,
      };

      final activeLevelForPartners = isFillIn ? (cycle['lastWeekLevel'] as int) : (cycle['level'] as int);
      expect(activeLevelForPartners, equals(1));

      print('✅ [Wednesday 00:30 UTC] Week: $currentWeekId, Window Closed (isFillIn = false), Active Target: Level 1');
    });
  });
}
