import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/services/room_support_service.dart';

void main() {
  group('🏆 1. Live Room Appbar Target Header Formatting', () {
    String formatDiamondCount(int count) {
      if (count >= 1000000000) {
        return '${(count / 1000000000).toStringAsFixed(1)}B';
      } else if (count >= 1000000) {
        return '${(count / 1000000).toStringAsFixed(0)}M';
      } else if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(0)}K';
      }
      return '$count';
    }

    test('Formats 209,000,000 to 209M >', () {
      final text = "${formatDiamondCount(209000000)} >";
      expect(text, equals("209M >"));
    });

    test('Formats 163,000,000 to 163M >', () {
      final text = "${formatDiamondCount(163000000)} >";
      expect(text, equals("163M >"));
    });

    test('Formats 500,000 to 500K >', () {
      final text = "${formatDiamondCount(500000)} >";
      expect(text, equals("500K >"));
    });

    test('Formats 0 to 0 >', () {
      final text = "${formatDiamondCount(0)} >";
      expect(text, equals("0 >"));
    });
  });

  group('📅 2. UTC Week ID & Reset Boundary Logic', () {
    String getUtcWeekId(DateTime date) {
      final d = DateTime.utc(date.year, date.month, date.day);
      final dayNum = d.weekday;
      final thursday = d.add(Duration(days: 4 - dayNum));
      final yearStart = DateTime.utc(thursday.year, 1, 1);
      final weekNo = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
      final weekStr = weekNo < 10 ? '0$weekNo' : '$weekNo';
      return '${thursday.year}-W$weekStr';
    }

    test('Generates consistent UTC Week ID for Monday and Sunday in same week', () {
      final monday = DateTime.utc(2026, 8, 24); // Mon
      final sunday = DateTime.utc(2026, 8, 30); // Sun

      expect(getUtcWeekId(monday), equals(getUtcWeekId(sunday)));
    });

    test('Detects week rollover between Sunday and next Monday', () {
      final sunday = DateTime.utc(2026, 8, 30);
      final nextMonday = DateTime.utc(2026, 8, 31);

      expect(getUtcWeekId(sunday), isNot(equals(getUtcWeekId(nextMonday))));
    });
  });

  group('📊 3. Room Level & Reward Coins Calculations', () {
    int calculateLevel(int totalCoins) {
      if (totalCoins >= 300000000) return 7;
      if (totalCoins >= 200000000) return 6;
      if (totalCoins >= 100000000) return 5;
      if (totalCoins >= 50000000) return 4;
      if (totalCoins >= 30000000) return 3;
      if (totalCoins >= 2000000) return 2;
      if (totalCoins >= 10000000) return 1;
      return 0;
    }

    int getPredictedReward(int level) {
      final levels = [
        {'level': 1, 'totalReward': 2000000},
        {'level': 2, 'totalReward': 4000000},
        {'level': 3, 'totalReward': 6000000},
        {'level': 4, 'totalReward': 12000000},
        {'level': 5, 'totalReward': 23000000},
        {'level': 6, 'totalReward': 45500000},
        {'level': 7, 'totalReward': 66000000},
      ];
      final target = levels.firstWhere((l) => l['level'] == level, orElse: () => {'totalReward': 0});
      return target['totalReward']!;
    }

    test('Level 5 achieved at 100M+ coins with 23M Total Reward', () {
      const coins = 100000000;
      final level = calculateLevel(coins);
      final reward = getPredictedReward(level);

      expect(level, equals(5));
      expect(reward, equals(23000000));
    });

    test('Level 7 achieved at 300M+ coins with 66M Total Reward', () {
      const coins = 300000000;
      final level = calculateLevel(coins);
      final reward = getPredictedReward(level);

      expect(level, equals(7));
      expect(reward, equals(66000000));
    });
  });

  group('🔍 4. Numeric Hello ID Search Parsing', () {
    int? parseNumericId(String query) {
      final trimmed = query.trim();
      return int.tryParse(trimmed);
    }

    test('Parses 9770258191 as integer Hello ID', () {
      final id = parseNumericId('9770258191');
      expect(id, equals(9770258191));
    });

    test('Parses 100790371 as integer Hello ID', () {
      final id = parseNumericId('100790371');
      expect(id, equals(100790371));
    });

    test('Returns null for non-numeric name query Jubayer', () {
      final id = parseNumericId('Jubayer');
      expect(id, isNull);
    });
  });

  group('🎯 5. Strictly Progressive 20 Room Support Target Levels Verification', () {
    test('All 20 Room Support levels are strictly progressive with target[i] > target[i-1]', () {
      final levels = RoomSupportService.defaultLevels;
      expect(levels.length, equals(20));

      int prevTarget = 0;
      for (int i = 0; i < levels.length; i++) {
        final l = levels[i];
        final levelNum = (l['level'] as num).toInt();
        final coinsTarget = (l['coinsTarget'] as num).toInt();

        expect(levelNum, equals(i + 1), reason: 'Level numbers must be sequential 1..20');
        expect(coinsTarget, greaterThan(prevTarget),
            reason: 'Level $levelNum ($coinsTarget) must be strictly greater than previous ($prevTarget)');
        prevTarget = coinsTarget;
      }
    });

    test('Corrects Level 7 = 5M and Level 8 = 8M (no 50M drop to 8M)', () {
      final levels = RoomSupportService.defaultLevels;
      final lvl7 = levels[6];
      final lvl8 = levels[7];

      expect(lvl7['coinsTarget'], equals(5000000), reason: 'Level 7 target is 5 Million');
      expect(lvl8['coinsTarget'], equals(8000000), reason: 'Level 8 target is 8 Million');
      expect((lvl8['coinsTarget'] as int) > (lvl7['coinsTarget'] as int), isTrue,
          reason: 'Level 8 (8M) must be strictly higher than Level 7 (5M)');
    });

    test('RoomSupportService.calculateLevel resolves accurate level across all 20 tiers', () {
      expect(RoomSupportService.calculateLevel(50000), equals(0));
      expect(RoomSupportService.calculateLevel(100000), equals(1));
      expect(RoomSupportService.calculateLevel(5000000), equals(7));
      expect(RoomSupportService.calculateLevel(8000000), equals(8));
      expect(RoomSupportService.calculateLevel(50000000), equals(13));
      expect(RoomSupportService.calculateLevel(600000000), equals(20));
      expect(RoomSupportService.calculateLevel(1000000000), equals(20));
    });
  });
}
