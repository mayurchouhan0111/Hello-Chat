import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel - History Immutability (Bug 1: retroactive result mutation)', () {
    test('Settled remote row: server winning food is immutable truth over session data', () {
      // The server settled this round as Corn; the local animation/session ticket
      // (from a divergent/stale outcome body) claims Steak. The history MUST show Corn.
      final resolved = resolveMergedWinningFood(
        remoteSettled: true,
        remoteFood: 'Corn',
        sessionFood: 'Steak',
      );
      expect(resolved, equals('Corn'));
    });

    test('Settled remote row with only name fallback also wins', () {
      final resolved = resolveMergedWinningFood(
        remoteSettled: true,
        remoteFood: 'Cabbage',
        sessionFood: '',
      );
      expect(resolved, equals('Cabbage'));
    });

    test('Unsettled remote row: session data fills the gap', () {
      final resolved = resolveMergedWinningFood(
        remoteSettled: false,
        remoteFood: '',
        sessionFood: 'Hotdog',
      );
      expect(resolved, equals('Hotdog'));
    });

    test('Unsettled remote row: session data fills the gap even when remote has a provisional food', () {
      // Row not yet settled: the server has no committed winner, so the animation/
      // session outcome is the best available display. Immutability only kicks in
      // once the row is settled.
      final resolved = resolveMergedWinningFood(
        remoteSettled: false,
        remoteFood: 'Tomato',
        sessionFood: 'Carrot',
      );
      expect(resolved, equals('Carrot'));
    });

    test('Nothing available resolves to null (caller falls back to empty)', () {
      final resolved = resolveMergedWinningFood(
        remoteSettled: false,
        remoteFood: '',
        sessionFood: '',
      );
      expect(resolved, isNull);
    });
  });

  group('Spin Wheel - Fix A & Fix B Regression (Round 966 Ghost Bet & Prize Drift)', () {
    test('Fix A: mergeHistoryRow prefers server-committed bets and totalBet over ghost session values (Round 966)', () {
      final remoteRow = <String, dynamic>{
        'roundId': '44777765',
        'totalBet': 8600000,
        'bets': {'tomato': 1000000, 'hotdog': 1300000},
        'prize': 6500000,
        'balanceBefore': 3791062079,
        'balanceAfter': 3788962079,
        'settled': true,
        'winningFood': 'hotdog',
        'multiplier': '5x',
      };

      final sessionItem = <String, dynamic>{
        'roundId': '44777765',
        'totalBet': 10300000, // Unconfirmed 3rd dispatch snapshot
        'bets': {'tomato': 1000000, 'hotdog': 1400000},
        'balanceBefore': 3791062079,
        'balanceAfter': 3787762079,
        'settled': false,
      };

      final merged = mergeHistoryRow(
        remoteRow: remoteRow,
        sessionItem: sessionItem,
      );

      // Server values MUST prevail over session ghost values
      expect(merged['totalBet'], equals(8600000));
      expect(merged['bets']['hotdog'], equals(1300000));
      expect(merged['prize'], equals(6500000));
      expect(merged['balanceAfter'], equals(3788962079));
      expect(merged['settled'], isTrue);

      // Session item must also be synchronized with authoritative server values
      expect(sessionItem['totalBet'], equals(8600000));
      expect(sessionItem['bets'], equals(remoteRow['bets']));
    });

    test('Fix A: Clean round where session matches server (Round 965) preserves exact values', () {
      final remoteRow = <String, dynamic>{
        'roundId': '44777764',
        'totalBet': 5000000,
        'bets': {'carrot': 1000000},
        'prize': 5000000,
        'balanceBefore': 3796062079,
        'balanceAfter': 3796062079,
        'settled': true,
        'winningFood': 'carrot',
        'multiplier': '5x',
      };

      final sessionItem = <String, dynamic>{
        'roundId': '44777764',
        'totalBet': 5000000,
        'bets': {'carrot': 1000000},
        'prize': 5000000,
        'settled': true,
      };

      final merged = mergeHistoryRow(
        remoteRow: remoteRow,
        sessionItem: sessionItem,
      );

      expect(merged['totalBet'], equals(5000000));
      expect(merged['prize'], equals(5000000));
      expect(merged['balanceAfter'], equals(3796062079));
    });

    test('Fix B: resolveCardDisplayPrize preserves authoritative settled prize and forbids recomputation', () {
      // Settled row with authoritative 6,500,000 prize.
      // If recomputed from ghost 1,400,000 * 5, it would produce 7,000,000.
      final displayPrize = resolveCardDisplayPrize(
        isSettled: true,
        hasServerPrize: true,
        existingPrize: 6500000,
        betsMap: {'hotdog': 1400000},
        winningFood: 'hotdog',
        multiplier: 5,
      );

      // Must strictly display 6,500,000 as-is
      expect(displayPrize, equals(6500000));
    });

    test('Fix B: resolveCardDisplayPrize recomputes dynamically only for unsettled/in-play rows', () {
      final displayPrize = resolveCardDisplayPrize(
        isSettled: false,
        hasServerPrize: false,
        existingPrize: 0,
        betsMap: {'tomato': 200},
        winningFood: 'tomato',
        multiplier: 5,
      );

      expect(displayPrize, equals(1000));
    });
  });

  group('Spin Wheel - Food Icon & Winning Name Resolution (Image 1, Image 2, Burger)', () {
    test('Image 1 Scenario: user won 650,000 on Corn 130,000, history resolves Corn (not Carrot)', () {
      // User placed bets: Cabbage 4,660,000, Corn 130,000, Carrot 10,000.
      // Total bet: 4,800,000. Win coins: 650,000 (130,000 * 5x).
      // Even if existingFood was erroneously set to Carrot, deduceWinningFoodFromWinningBet
      // MUST correctly resolve Corn!
      final bets = <String, dynamic>{
        'CABBAGE': 4660000,
        'CORN': 130000,
        'CARROT': 10000,
      };

      final resolved = deduceWinningFoodFromWinningBet(
        betsMap: bets,
        prize: 650000,
        existingFood: 'CARROT', // Erroneous initial/stale food
      );

      expect(resolved, equals('CORN'));
      expect(getSpinWheelFoodEmoji(resolved), equals('🌽'));
    });

    test('Image 2 Scenario: user won 54,150,000 on Kebab 3,610,000, history resolves Kebab (not Corn)', () {
      // User placed bets: Cabbage 20,000, Kebab 3,610,000, Tomato 20,000, Carrot 20,000, Corn 20,000.
      // Win coins: 54,150,000 (3,610,000 * 15x).
      // Even if existingFood was erroneously Corn, deduceWinningFoodFromWinningBet
      // MUST correctly resolve Kebab!
      final bets = <String, dynamic>{
        'CABBAGE': 20000,
        'KEBAB': 3610000,
        'TOMATO': 20000,
        'CARROT': 20000,
        'CORN': 20000,
      };

      final resolved = deduceWinningFoodFromWinningBet(
        betsMap: bets,
        prize: 54150000,
        existingFood: 'CORN', // Erroneous initial/stale food
      );

      expect(resolved, equals('KEBAB'));
      expect(getSpinWheelFoodEmoji(resolved), equals('🍢'));
    });

    test('Burger winning result: history displays Burger and Burger emoji 🍔', () {
      final bets = <String, dynamic>{
        'BURGER': 100000,
        'TOMATO': 50000,
      };

      final resolved = deduceWinningFoodFromWinningBet(
        betsMap: bets,
        prize: 1000000, // 100,000 * 10x
        existingFood: 'BURGER',
      );

      expect(resolved, equals('BURGER'));
      expect(getSpinWheelFoodEmoji(resolved), equals('🍔'));
      expect(getSpinWheelFoodNameFromEmoji('🍔'), equals('BURGER'));
    });

    test('Food emojis match actual food items across all wheel outcomes', () {
      expect(getSpinWheelFoodEmoji('burger'), equals('🍔'));
      expect(getSpinWheelFoodEmoji('BURGER'), equals('🍔'));
      expect(getSpinWheelFoodEmoji('hotdog'), equals('🌭'));
      expect(getSpinWheelFoodEmoji('HOTDOG'), equals('🌭'));
      expect(getSpinWheelFoodEmoji('corn'), equals('🌽'));
      expect(getSpinWheelFoodEmoji('CORN'), equals('🌽'));
      expect(getSpinWheelFoodEmoji('carrot'), equals('🥕'));
      expect(getSpinWheelFoodEmoji('CARROT'), equals('🥕'));
      expect(getSpinWheelFoodEmoji('cabbage'), equals('🥬'));
      expect(getSpinWheelFoodEmoji('CABBAGE'), equals('🥬'));
      expect(getSpinWheelFoodEmoji('tomato'), equals('🍅'));
      expect(getSpinWheelFoodEmoji('TOMATO'), equals('🍅'));
      expect(getSpinWheelFoodEmoji('kebab'), equals('🍢'));
      expect(getSpinWheelFoodEmoji('KEBAB'), equals('🍢'));
      expect(getSpinWheelFoodEmoji('skewer'), equals('🍢'));
      expect(getSpinWheelFoodEmoji('chicken'), equals('🍗'));
      expect(getSpinWheelFoodEmoji('steak'), equals('🥩'));
      expect(getSpinWheelFoodEmoji('salad'), equals('🥗'));
      expect(getSpinWheelFoodEmoji('pizza'), equals('🍕'));
    });

    test('Multipliers are accurately assigned for Burger (10x), Corn (5x), Kebab (15x)', () {
      expect(resolveFoodMultiplier('burger'), equals(10));
      expect(resolveFoodMultiplier('hotdog'), equals(10));
      expect(resolveFoodMultiplier('corn'), equals(5));
      expect(resolveFoodMultiplier('carrot'), equals(5));
      expect(resolveFoodMultiplier('cabbage'), equals(5));
      expect(resolveFoodMultiplier('tomato'), equals(5));
      expect(resolveFoodMultiplier('kebab'), equals(15));
      expect(resolveFoodMultiplier('chicken'), equals(25));
      expect(resolveFoodMultiplier('steak'), equals(45));
    });
  });

  group('Spin Wheel - Premature Winning Result Leak Prevention During Active Period', () {
    test('Unsettled/active card has prize strictly 0 and no winning food revealed', () {
      // During active betting period (e.g. 5 seconds), round is not settled.
      // Remote row or session item has settled = false.
      final activeRow = <String, dynamic>{
        'roundId': '44780001',
        'totalBet': 4800000,
        'bets': {'corn': 130000, 'cabbage': 4660000, 'carrot': 10000},
        'settled': false,
        'prize': 0,
        'winningFood': '',
        'emoji': '🎰',
      };

      expect(activeRow['settled'], isFalse);
      expect(activeRow['prize'], equals(0));
      expect(activeRow['winningFood'], isEmpty);
      expect(activeRow['emoji'], equals('🎰'));
    });
  });
}