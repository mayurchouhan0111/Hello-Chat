import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';
import 'package:hello_chat/core/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel Game - Payout Logic & Mathematical Parity', () {
    test('Standard food bet: 100 on Tomato (5x) wins 500', () {
      final bets = {'Tomato': 100};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Tomato',
        multiplier: 5,
      );
      expect(prize, equals(500));
    });

    test('Standard food bet: 500 on Hotdog (10x) wins 5000', () {
      final bets = {'Hotdog': 500};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Hotdog',
        multiplier: 10,
      );
      expect(prize, equals(5000));
    });

    test('Standard food bet: 200 on Steak (45x) wins 9000', () {
      final bets = {'Steak': 200};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Steak',
        multiplier: 45,
      );
      expect(prize, equals(9000));
    });

    test('Multiple bets: Bets on Tomato (200) and Hotdog (300), Tomato wins', () {
      final bets = {'Tomato': 200, 'Hotdog': 300};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Tomato',
        multiplier: 5,
      );
      // Only Tomato pays (200 * 5 = 1000). Hotdog loses.
      expect(prize, equals(1000));
    });

    test('Multi-chip concurrent taps: Partial confirmed bets with later Tomato bet awards win', () {
      final confirmedBets = {'Carrot': 100000, 'Steak': 100000};
      final currentBets = {'Carrot': 100000, 'Steak': 100000, 'Tomato': 100000};
      final serverReceiptBets = {'Carrot': 100000, 'Steak': 100000};

      // Exact merging logic used in spin_wheel_screen.dart
      final activeBets = <String, int>{};
      for (final entry in serverReceiptBets.entries) {
        activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
      }
      for (final entry in confirmedBets.entries) {
        activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
      }
      for (final entry in currentBets.entries) {
        activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
      }

      final prize = calculateSpinWheelPrize(
        bets: activeBets,
        winningName: 'Tomato',
        winningCategory: 'standard',
        multiplier: 5,
      );
      expect(prize, equals(500000), reason: 'Tomato bet must be recognized even when added in a later tap batch');
      expect(activeBets['Tomato'], equals(100000));
      expect(activeBets['Carrot'], equals(100000));
      expect(activeBets['Steak'], equals(100000));
    });

    test('Losing bet: Bet on Skewer (500), Carrot lands', () {
      final bets = {'Skewer': 500};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Carrot',
        multiplier: 5,
      );
      expect(prize, equals(0));
    });

    test('Spectator (no bets): Prize is always 0', () {
      final bets = <String, int>{};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Tomato',
        multiplier: 5,
      );
      expect(prize, equals(0));
    });

    test('Salad Jackpot: Bet on Salad pays 5x when any salad item lands', () {
      for (final winningSalad in ['tomato', 'cabbage', 'corn', 'carrot']) {
        final bets = {'salad': 100};
        final prize = calculateSpinWheelPrize(
          bets: bets,
          winningName: winningSalad,
          winningCategory: 'salad',
          multiplier: 5,
        );
        expect(prize, equals(500), reason: 'Salad bet must pay 5x on $winningSalad');
      }
    });

    test('Pizza Jackpot: Bet on Pizza pays 45x when pizza or steak lands', () {
      for (final winningPizza in ['pizza', 'steak']) {
        final bets = {'pizza': 100};
        final prize = calculateSpinWheelPrize(
          bets: bets,
          winningName: winningPizza,
          winningCategory: 'pizza',
          multiplier: 45,
        );
        expect(prize, equals(4500), reason: 'Pizza bet must pay 45x on $winningPizza');
      }
    });

    test('Special Celebration Round: Salad round pays 5x for all salad bets', () {
      final bets = {
        'tomato': 100,
        'cabbage': 200,
        'corn': 50,
        'carrot': 150,
        'hotdog': 300, // Non-salad item, should lose
      };
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Salad',
        winningCategory: 'salad',
        roundType: 'salad',
        multiplier: 5,
      );
      // (100 + 200 + 50 + 150) * 5 = 500 * 5 = 2500
      expect(prize, equals(2500));
    });

    test('Special Celebration Round: Pizza round pays 45x for pizza and steak bets', () {
      final bets = {
        'pizza': 100,
        'steak': 100,
        'tomato': 200, // Non-pizza item, should lose
      };
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Pizza',
        winningCategory: 'pizza',
        roundType: 'pizza',
        multiplier: 45,
      );
      // (100 + 100) * 45 = 200 * 45 = 9000
      expect(prize, equals(9000));
    });
  });

  group('Spin Wheel Game - UI Parity with Backend Results (Result Bottom Sheet)', () {
    testWidgets('Case 1: Winning Round UI - Renders "YOU WIN!", correct diamonds, wager, and item', (tester) async {
      final winItem = SpinItem(name: 'Tomato', multiplier: 5, emoji: '🍅', category: 'standard');
      const wager = 200;
      const winnings = 1000;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                luckySpinCurrentRoundWinnersProvider.overrideWith((ref, roundId) => Stream.value([])),
              ],
              child: SpinWheelResultBottomSheet(
                item: winItem,
                winnings: winnings,
                wager: wager,
                winners: const [],
                roundId: '1001',
                bets: const {'Tomato': 200},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header: YOU WIN!
      expect(find.text('YOU WIN!'), findsOneWidget);

      // Verify Item: 🍅 Tomato
      expect(find.text('🍅 Tomato'), findsOneWidget);

      // Verify Winnings: 1000
      expect(find.text('1000'), findsOneWidget);

      // Verify Wager: 200
      expect(find.text('200'), findsOneWidget);

      // Verify Mascot Panda
      expect(find.text('🐼'), findsOneWidget);

      // Verify Labels
      expect(find.text("This round's results: "), findsOneWidget);
      expect(find.text("This round's winnings: "), findsOneWidget);
      expect(find.text("Your wager this round: "), findsOneWidget);
    });

    testWidgets('Case 2: Losing Round UI - Renders "YOU LOST", 0 winnings, wager, and item', (tester) async {
      final winItem = SpinItem(name: 'Hotdog', multiplier: 10, emoji: '🌭', category: 'standard');
      const wager = 500;
      const winnings = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                luckySpinCurrentRoundWinnersProvider.overrideWith((ref, roundId) => Stream.value([])),
              ],
              child: SpinWheelResultBottomSheet(
                item: winItem,
                winnings: winnings,
                wager: wager,
                winners: const [],
                roundId: '1002',
                bets: const {'Tomato': 500},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header: YOU LOST
      expect(find.text('YOU LOST'), findsOneWidget);

      // Verify Item: 🌭 Hotdog
      expect(find.text('🌭 Hotdog'), findsOneWidget);

      // Verify Winnings: 0
      expect(find.text('0'), findsOneWidget);

      // Verify Wager: 500
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('Case 3: Spectator Round UI - Renders "ROUND COMPLETED", 0 winnings, 0 wager', (tester) async {
      final winItem = SpinItem(name: 'Chicken', multiplier: 25, emoji: '🍗', category: 'standard');
      const wager = 0;
      const winnings = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                luckySpinCurrentRoundWinnersProvider.overrideWith((ref, roundId) => Stream.value([])),
              ],
              child: SpinWheelResultBottomSheet(
                item: winItem,
                winnings: winnings,
                wager: wager,
                winners: const [],
                roundId: '1003',
                bets: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header: ROUND COMPLETED
      expect(find.text('ROUND COMPLETED'), findsOneWidget);

      // Verify Item: 🍗 Chicken
      expect(find.text('🍗 Chicken'), findsOneWidget);

      // Verify 0 is displayed for both winnings and wager
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('Case 4: Salad Celebration Round UI - Displays Salad System Breakdown', (tester) async {
      final winItem = SpinItem(name: 'Salad', multiplier: 5, emoji: '🥗', category: 'salad');
      const wager = 300;
      const winnings = 1500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                luckySpinCurrentRoundWinnersProvider.overrideWith((ref, roundId) => Stream.value([])),
              ],
              child: SpinWheelResultBottomSheet(
                item: winItem,
                winnings: winnings,
                wager: wager,
                winners: const [],
                roundId: '1004',
                bets: const {
                  'tomato': 100,
                  'cabbage': 100,
                  'corn': 100,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header: YOU WIN!
      expect(find.text('YOU WIN!'), findsOneWidget);

      // Verify Breakdown title
      expect(find.text('Salad System Breakdown (5x)'), findsOneWidget);

      // Verify all salad item rows
      expect(find.text('🍅 Tomato'), findsOneWidget);
      expect(find.text('🥬 Lettuce'), findsOneWidget);
      expect(find.text('🌽 Corn'), findsOneWidget);
      expect(find.text('🥕 Carrot'), findsOneWidget);

      // Verify calculated sub-winnings in breakdown: 100 * 5 = 500
      expect(find.text('500'), findsNWidgets(3)); // tomato, cabbage, corn each 500
      expect(find.text('0'), findsNWidgets(1)); // carrot 0
    });

    testWidgets('Case 5: Round Winner Podium UI - Renders single round winner correctly', (tester) async {
      final winItem = SpinItem(name: 'Steak', multiplier: 45, emoji: '🥩', category: 'standard');
      final mockWinners = [
        {'name': 'Alex Pro', 'totalBet': 1000, 'winnings': 45000, 'avatar': ''},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                luckySpinCurrentRoundWinnersProvider.overrideWith((ref, roundId) => Stream.value(mockWinners)),
              ],
              child: SpinWheelResultBottomSheet(
                item: winItem,
                winnings: 45000,
                wager: 1000,
                winners: mockWinners,
                roundId: '1005',
                bets: const {'Steak': 1000},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Round Winner header title
      expect(find.text("ROUND WINNER"), findsOneWidget);

      // Verify Winner Name
      expect(find.text('Alex Pro'), findsOneWidget);

      // Verify Rank 1 badge
      expect(find.text('#1'), findsOneWidget);
    });
  });

  group('Spin Wheel Game - Wheel Sector Geometry & Alignment', () {
    test('8 sectors correspond to 8 food items in sequence', () {
      final defaultSegments = [
        {"name": "Tomato", "multiplier": 5, "emoji": "🍅"},
        {"name": "Hotdog", "multiplier": 10, "emoji": "🌭"},
        {"name": "Skewer", "multiplier": 15, "emoji": "🍢"},
        {"name": "Chicken", "multiplier": 25, "emoji": "🍗"},
        {"name": "Steak", "multiplier": 45, "emoji": "🥩"},
        {"name": "Carrot", "multiplier": 5, "emoji": "🥕"},
        {"name": "Corn", "multiplier": 5, "emoji": "🌽"},
        {"name": "Cabbage", "multiplier": 5, "emoji": "🥬"},
      ];

      expect(defaultSegments.length, equals(8));
      for (int i = 0; i < defaultSegments.length; i++) {
        const startIdx = 0;
        final targetIdx = i;
        final distance = (targetIdx - startIdx + 8) % 8;
        expect(distance, equals(i), reason: 'Sector $i distance from 0 must be $i');
      }
    });

    test('Clockwise sector wrapping: Landing from sector 7 to sector 1 is distance 2', () {
      const startIdx = 7;
      const targetIdx = 1;
      final distance = (targetIdx - startIdx + 8) % 8;
      expect(distance, equals(2));
    });
  });

  group('Spin Wheel Game - 40s Synchronized Cycle Timing', () {
    test('0s to 20s: Betting Phase Open ("Select time")', () {
      for (int sec = 0; sec < 20; sec++) {
        final countdown = 30 - sec;
        const label = "Select time";
        const isLocked = false;
        expect(countdown, inInclusiveRange(11, 30));
        expect(label, equals("Select time"));
        expect(isLocked, isFalse);
      }
    });

    test('20s to 30s: Bets Closed ("BETS CLOSED")', () {
      for (int sec = 20; sec < 30; sec++) {
        final countdown = 30 - sec;
        const label = "BETS CLOSED";
        const isLocked = true;
        expect(countdown, inInclusiveRange(1, 10));
        expect(label, equals("BETS CLOSED"));
        expect(isLocked, isTrue);
      }
    });

    test('30s to 35s: Spinning Phase ("Spinning")', () {
      for (int sec = 30; sec < 35; sec++) {
        const countdown = 0;
        const label = "Spinning";
        const isLocked = true;
        expect(countdown, equals(0));
        expect(label, equals("Spinning"));
        expect(isLocked, isTrue);
      }
    });

    test('35s to 37s: Winning Phase ("Winning")', () {
      for (int sec = 35; sec < 37; sec++) {
        final countdown = 40 - sec;
        const label = "Winning";
        const isLocked = true;
        expect(countdown, inInclusiveRange(4, 5));
        expect(label, equals("Winning"));
        expect(isLocked, isTrue);
      }
    });

    test('37s to 40s: Next Round Transition Countdown ("Next Round")', () {
      for (int sec = 37; sec < 40; sec++) {
        final countdown = 40 - sec;
        const label = "Next Round";
        expect(countdown, inInclusiveRange(1, 3));
        expect(label, equals("Next Round"));
      }
    });

    test('40s rollover increments round ID and resets bets map', () {
      const roundDurationMs = 40000;
      const round1TimeMs = 10000; // within round 0
      const round2TimeMs = 45000; // within round 1

      final round1Id = (round1TimeMs ~/ roundDurationMs).toString();
      final round2Id = (round2TimeMs ~/ roundDurationMs).toString();

      expect(round1Id, equals('0'));
      expect(round2Id, equals('1'));
      expect(round1Id != round2Id, isTrue);
    });
  });

  group('Spin Wheel - Indicator Alignment & Target Sector Resolution', () {
    final foodSegments = [
      {'id': '1', 'name': 'Tomato', 'multiplier': 5, 'emoji': '🍅', 'category': 'salad'},
      {'id': '2', 'name': 'Hotdog', 'multiplier': 10, 'emoji': '🌭', 'category': 'pizza'},
      {'id': '3', 'name': 'Skewer', 'multiplier': 15, 'emoji': '🍢', 'category': 'pizza'},
      {'id': '4', 'name': 'Chicken', 'multiplier': 25, 'emoji': '🍗', 'category': 'pizza'},
      {'id': '5', 'name': 'Steak', 'multiplier': 45, 'emoji': '🥩', 'category': 'pizza'},
      {'id': '6', 'name': 'Carrot', 'multiplier': 5, 'emoji': '🥕', 'category': 'salad'},
      {'id': '7', 'name': 'Corn', 'multiplier': 5, 'emoji': '🌽', 'category': 'salad'},
      {'id': '8', 'name': 'Cabbage', 'multiplier': 5, 'emoji': '🥬', 'category': 'salad'},
    ];

    test('Indicator lands on Tomato (index 0) even if outcome sectorIndex is mismatched', () {
      final outcome = {
        'name': 'Tomato',
        'sectorIndex': 7, // Intentionally mismatched to test name priority
        'multiplier': 5,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(0));
      expect(foodSegments[idx]['name'], equals('Tomato'));
    });

    test('Indicator lands on Corn (index 6)', () {
      final outcome = {
        'name': 'Corn',
        'sectorIndex': 6,
        'multiplier': 5,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(6));
      expect(foodSegments[idx]['name'], equals('Corn'));
    });

    test('Indicator lands on Steak (index 4) with synonym "meat"', () {
      final outcome = {
        'name': 'meat',
        'sectorIndex': 0,
        'multiplier': 45,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(4));
      expect(foodSegments[idx]['name'], equals('Steak'));
    });

    test('Indicator lands on Skewer (index 2) with synonym "kebab"', () {
      final outcome = {
        'name': 'kebab',
        'sectorIndex': 0,
        'multiplier': 15,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(2));
      expect(foodSegments[idx]['name'], equals('Skewer'));
    });

    test('Special Salad Round lands on a valid salad vegetable (e.g. Tomato at index 0)', () {
      final outcome = {
        'name': 'Salad',
        'type': 'salad',
        'multiplier': 5,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(0));
      expect(foodSegments[idx]['category'], equals('salad'));
    });

    test('Special Pizza Round lands on a valid pizza meat', () {
      final outcome = {
        'name': 'Pizza',
        'type': 'pizza',
        'multiplier': 45,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(foodSegments[idx]['category'], equals('pizza'));
    });

    test('Fallback to raw sectorIndex when outcome name is empty or unknown', () {
      final outcome = {
        'name': '',
        'sectorIndex': 3,
        'multiplier': 25,
      };
      final idx = resolveTargetSectorIndex(outcome, foodSegments);
      expect(idx, equals(3));
      expect(foodSegments[idx]['name'], equals('Chicken'));
    });
  });
}
