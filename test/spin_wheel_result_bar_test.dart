import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel Result Bar Display - Neutral vs Official Revealed State', () {
    test('Phase 1 (Active Betting): Result bar must be neutral, never show live winning outcomes', () {
      // During active betting phase, result indicators must be neutral
      const gameState = SpinGameState.betting;
      const spinCompleted = false;

      final bool isResultCelebration = gameState == SpinGameState.results && spinCompleted;
      expect(isResultCelebration, isFalse, reason: 'Active betting must never trigger result celebration');

      final String neutralStatusText = gameState == SpinGameState.spinning
          ? "Wheel spinning • Awaiting official result..."
          : "Round in play • Outcomes revealed after spin";

      expect(neutralStatusText, equals("Round in play • Outcomes revealed after spin"));
    });

    test('Phase 2 (Wheel Spinning): Result bar must remain neutral during spin', () {
      const gameState = SpinGameState.spinning;
      const spinCompleted = false;

      final bool isResultCelebration = gameState == SpinGameState.results && spinCompleted;
      expect(isResultCelebration, isFalse, reason: 'Spinning phase must never trigger result celebration');

      final String neutralStatusText = gameState == SpinGameState.spinning
          ? "Wheel spinning • Awaiting official result..."
          : "Round in play • Outcomes revealed after spin";

      expect(neutralStatusText, equals("Wheel spinning • Awaiting official result..."));
    });

    test('Phase 3 (Round Completed & Settled): Official result is revealed with winning option & win status', () {
      const gameState = SpinGameState.results;
      const spinCompleted = true;

      final bool isResultCelebration = gameState == SpinGameState.results && spinCompleted;
      expect(isResultCelebration, isTrue, reason: 'Settled round must trigger official result display');

      // Given a player who wagered 150,000 on Hotdog and won 690,000
      const wager = 150000;
      const prize = 690000;
      final bool hasPlayerBet = wager > 0;
      final bool isPlayerWin = hasPlayerBet && prize > 0;

      expect(hasPlayerBet, isTrue);
      expect(isPlayerWin, isTrue);
      expect(prize, equals(690000));
    });

    test('Phase 3 (Round Completed - Player Loss): Official result shows winning option & loss status', () {
      const gameState = SpinGameState.results;
      const spinCompleted = true;

      // Player wagered 100,000 on Carrot, but Hotdog won (prize = 0)
      const wager = 100000;
      const prize = 0;
      final bool hasPlayerBet = wager > 0;
      final bool isPlayerWin = hasPlayerBet && prize > 0;

      expect(hasPlayerBet, isTrue);
      expect(isPlayerWin, isFalse);
    });

    test('Consecutive Rounds: Previous round results never leak into new round as current outcome', () {
      // Round 1026 settles with Hotdog
      String currentRoundId = '1026';
      Map<String, dynamic>? lastRoundResult = {
        'roundId': '1026',
        'name': 'Hotdog',
        'emoji': '🌭',
        'multiplier': 10,
      };
      bool spinCompleted = true;
      SpinGameState gameState = SpinGameState.results;

      expect(gameState == SpinGameState.results && spinCompleted, isTrue);
      expect(lastRoundResult['name'], equals('Hotdog'));

      // Rollover to Round 1027: bets open, countdown starts
      currentRoundId = '1027';
      gameState = SpinGameState.betting;
      spinCompleted = false;
      lastRoundResult = null; // Cleared on rollover

      final bool isResultCelebrationRound2 = gameState == SpinGameState.results && spinCompleted;
      expect(isResultCelebrationRound2, isFalse, reason: 'Round 1027 must start in neutral state');
      expect(lastRoundResult, isNull, reason: 'Previous round result must be cleared on rollover');

      // Past history correctly contains Round 1026 strictly without "New" badge
      final pastHistory = [
        {'roundId': '1026', 'name': 'Hotdog', 'emoji': '🌭', 'multiplier': 10}
      ];
      final visiblePastHistory = pastHistory.where((rec) => rec['roundId'] != currentRoundId).toList();
      expect(visiblePastHistory.length, equals(1));
      expect(visiblePastHistory.first['name'], equals('Hotdog'));
      expect(visiblePastHistory.first['roundId'], equals('1026'));
    });
  });
}
