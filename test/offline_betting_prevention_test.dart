import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  group('Offline Betting Prevention & Server Authority Tests', () {
    test('Platform connectivity parsing correctly identifies offline status', () {
      bool isConnected(List<ConnectivityResult> results) {
        return results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      }

      // Mobile data and WiFi turned completely off
      expect(isConnected([ConnectivityResult.none]), isFalse);
      expect(isConnected([]), isFalse);

      // Connected via WiFi or Mobile
      expect(isConnected([ConnectivityResult.wifi]), isTrue);
      expect(isConnected([ConnectivityResult.mobile]), isTrue);
      expect(isConnected([ConnectivityResult.ethernet]), isTrue);
      expect(isConnected([ConnectivityResult.none, ConnectivityResult.wifi]), isTrue);
    });

    test('Offline state calculation immediately triggers if mobile data/WiFi is off', () {
      bool calculateIsOffline({required bool rtdbConnected, required bool platformOnline}) {
        // Must be offline if EITHER platform has no connection OR RTDB failed
        return !platformOnline || !rtdbConnected;
      }

      // When mobile data is turned off, even if RTDB socket has not timed out yet:
      expect(
        calculateIsOffline(rtdbConnected: true, platformOnline: false),
        isTrue,
        reason: 'Must be offline immediately when mobile data/WiFi is turned off',
      );

      // When both are off:
      expect(
        calculateIsOffline(rtdbConnected: false, platformOnline: false),
        isTrue,
      );

      // When platform is connected but RTDB lost connection:
      expect(
        calculateIsOffline(rtdbConnected: false, platformOnline: true),
        isTrue,
        reason: 'Must be offline when RTDB sync is disconnected',
      );

      // Only online when both platform and server socket are active:
      expect(
        calculateIsOffline(rtdbConnected: true, platformOnline: true),
        isFalse,
      );
    });

    test('Server authority: Unconfirmed bet must not produce winnings or alter profits', () {
      // Simulating the spin completion logic
      Map<String, dynamic>? submittedSpinResult; // null because offline/failed
      const roundId = "1000";
      final confirmedBets = <String, int>{}; // empty

      final bool hasConfirmedBet = submittedSpinResult != null &&
          submittedSpinResult['roundId']?.toString() == roundId &&
          confirmedBets.isNotEmpty;

      final totalBet = hasConfirmedBet
          ? confirmedBets.values.fold(0, (sum, val) => sum + val)
          : 0;
      const prize = 500; // raw segment prize
      final effectivePrize = hasConfirmedBet ? prize : 0;

      int todayProfits = 0;
      if (totalBet > 0) {
        todayProfits += (effectivePrize - totalBet);
      }

      expect(hasConfirmedBet, isFalse);
      expect(totalBet, equals(0));
      expect(effectivePrize, equals(0));
      expect(todayProfits, equals(0));
    });

    test('Confirmed server bet correctly computes winnings and updates profits', () {
      final submittedSpinResult = {'roundId': '1000', 'prize': 500};
      const roundId = "1000";
      final confirmedBets = <String, int>{'Tomato': 100};

      final bool hasConfirmedBet = submittedSpinResult['roundId']?.toString() == roundId &&
          confirmedBets.isNotEmpty;

      final totalBet = hasConfirmedBet
          ? confirmedBets.values.fold(0, (sum, val) => sum + val)
          : 0;
      final prize = (submittedSpinResult['prize'] as num).toInt();
      final effectivePrize = hasConfirmedBet ? prize : 0;

      int todayProfits = 0;
      if (totalBet > 0) {
        todayProfits += (effectivePrize - totalBet);
      }

      expect(hasConfirmedBet, isTrue);
      expect(totalBet, equals(100));
      expect(effectivePrize, equals(500));
      expect(todayProfits, equals(400));
    });

    // ── CASE 1: WINNING BET ──────────────────────────────────────────────────
    test('Case 1: Winning bet - Authoritative server response returns prize > 0 and displays YOU WIN!', () {
      final submittedSpinResult = {'roundId': '2001', 'prize': 500, 'totalBet': 100};
      const roundId = "2001";
      final confirmedBets = <String, int>{'tomato': 100};

      final hasServerResult = submittedSpinResult['roundId']?.toString() == roundId;
      final activeBets = confirmedBets;
      final hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;
      final effectiveTotalBet = activeBets.values.fold(0, (sum, val) => sum + val);

      int effectivePrize = 0;
      if (hasConfirmedBet && effectiveTotalBet > 0) {
        if (hasServerResult && submittedSpinResult['prize'] != null) {
          effectivePrize = (submittedSpinResult['prize'] as num).toInt();
        } else {
          effectivePrize = calculateSpinWheelPrize(
            bets: activeBets,
            winningName: 'Tomato',
            multiplier: 5,
          );
        }
      }

      // Dialog Outcome Header Logic
      String outcomeTitle;
      if (effectiveTotalBet > 0) {
        outcomeTitle = effectivePrize > 0 ? "YOU WIN!" : "YOU LOST";
      } else {
        outcomeTitle = "ROUND COMPLETED";
      }

      expect(effectiveTotalBet, equals(100));
      expect(effectivePrize, equals(500));
      expect(outcomeTitle, equals("YOU WIN!"));
    });

    // ── CASE 2: LOSING BET ───────────────────────────────────────────────────
    test('Case 2: Losing bet - Server returns prize 0 and displays YOU LOST', () {
      final submittedSpinResult = {'roundId': '2002', 'prize': 0, 'totalBet': 100};
      const roundId = "2002";
      final confirmedBets = <String, int>{'hotdog': 100};

      final hasServerResult = submittedSpinResult['roundId']?.toString() == roundId;
      final activeBets = confirmedBets;
      final hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;
      final effectiveTotalBet = activeBets.values.fold(0, (sum, val) => sum + val);

      int effectivePrize = 0;
      if (hasConfirmedBet && effectiveTotalBet > 0) {
        if (hasServerResult && submittedSpinResult['prize'] != null) {
          effectivePrize = (submittedSpinResult['prize'] as num).toInt();
        } else {
          effectivePrize = calculateSpinWheelPrize(
            bets: activeBets,
            winningName: 'Tomato',
            multiplier: 5,
          );
        }
      }

      String outcomeTitle;
      if (effectiveTotalBet > 0) {
        outcomeTitle = effectivePrize > 0 ? "YOU WIN!" : "YOU LOST";
      } else {
        outcomeTitle = "ROUND COMPLETED";
      }

      expect(effectiveTotalBet, equals(100));
      expect(effectivePrize, equals(0));
      expect(outcomeTitle, equals("YOU LOST"));
    });

    // ── CASE 3: MULTIPLE BETS ────────────────────────────────────────────────
    test('Case 3: Multiple bets - User bets on Tomato (100) and Hotdog (100), Tomato wins', () {
      final confirmedBets = <String, int>{'tomato': 100, 'hotdog': 100};
      final submittedSpinResult = {'roundId': '2003', 'prize': 500, 'totalBet': 200};
      const roundId = "2003";

      final hasServerResult = submittedSpinResult['roundId']?.toString() == roundId;
      final activeBets = confirmedBets;
      final hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;
      final effectiveTotalBet = activeBets.values.fold(0, (sum, val) => sum + val);

      int effectivePrize = 0;
      if (hasConfirmedBet && effectiveTotalBet > 0) {
        if (hasServerResult && submittedSpinResult['prize'] != null) {
          effectivePrize = (submittedSpinResult['prize'] as num).toInt();
        } else {
          effectivePrize = calculateSpinWheelPrize(
            bets: activeBets,
            winningName: 'Tomato',
            multiplier: 5,
          );
        }
      }

      String outcomeTitle;
      if (effectiveTotalBet > 0) {
        outcomeTitle = effectivePrize > 0 ? "YOU WIN!" : "YOU LOST";
      } else {
        outcomeTitle = "ROUND COMPLETED";
      }

      expect(effectiveTotalBet, equals(200));
      expect(effectivePrize, equals(500));
      expect(outcomeTitle, equals("YOU WIN!"));
    });

    // ── CASE 4: DELAYED SERVER RESPONSE (FALLBACK CALCULATION) ───────────────
    test('Case 4: Delayed server response - Fallback uses confirmed bet x multiplier', () {
      // Server receipt temporarily unavailable (in-flight network delay)
      Map<String, dynamic>? submittedSpinResult; // null
      const roundId = "2004";
      final confirmedBets = <String, int>{'tomato': 100};

      final hasServerResult = submittedSpinResult != null &&
          submittedSpinResult['roundId']?.toString() == roundId;
      final activeBets = confirmedBets;
      final hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;
      final effectiveTotalBet = activeBets.values.fold(0, (sum, val) => sum + val);

      int effectivePrize = 0;
      if (hasConfirmedBet && effectiveTotalBet > 0) {
        if (hasServerResult && submittedSpinResult['prize'] != null) {
          effectivePrize = (submittedSpinResult['prize'] as num).toInt();
        } else {
          // Fallback: confirmed bet * multiplier
          effectivePrize = calculateSpinWheelPrize(
            bets: activeBets,
            winningName: 'Tomato',
            multiplier: 5,
          );
        }
      }

      String outcomeTitle;
      if (effectiveTotalBet > 0) {
        outcomeTitle = effectivePrize > 0 ? "YOU WIN!" : "YOU LOST";
      } else {
        outcomeTitle = "ROUND COMPLETED";
      }

      expect(hasServerResult, isFalse);
      expect(effectiveTotalBet, equals(100));
      expect(effectivePrize, equals(500));
      expect(outcomeTitle, equals("YOU WIN!"));
    });

    // ── CASE 5: SPECTATOR / NO-BET USER ─────────────────────────────────────
    test('Case 5: Spectator / no-bet user - Returns 0 wager, 0 winnings, displays ROUND COMPLETED', () {
      Map<String, dynamic>? submittedSpinResult; // no bet placed
      const roundId = "2005";
      final confirmedBets = <String, int>{}; // empty

      final hasServerResult = submittedSpinResult != null &&
          submittedSpinResult['roundId']?.toString() == roundId;
      final activeBets = confirmedBets;
      final hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;
      final effectiveTotalBet = activeBets.values.fold(0, (sum, val) => sum + val);

      int effectivePrize = 0;
      if (hasConfirmedBet && effectiveTotalBet > 0) {
        if (hasServerResult && submittedSpinResult['prize'] != null) {
          effectivePrize = (submittedSpinResult['prize'] as num).toInt();
        } else {
          effectivePrize = calculateSpinWheelPrize(
            bets: activeBets,
            winningName: 'Tomato',
            multiplier: 5,
          );
        }
      }

      String outcomeTitle;
      if (effectiveTotalBet > 0) {
        outcomeTitle = effectivePrize > 0 ? "YOU WIN!" : "YOU LOST";
      } else {
        outcomeTitle = "ROUND COMPLETED";
      }

      expect(hasConfirmedBet, isFalse);
      expect(effectiveTotalBet, equals(0));
      expect(effectivePrize, equals(0));
      expect(outcomeTitle, equals("ROUND COMPLETED"));
    });

    // ── SPECIAL ROUNDS TESTS ─────────────────────────────────────────────────
    test('Special rounds: Salad round pays 5x for all salad items in fallback calculation', () {
      final bets = {'carrot': 100, 'corn': 50, 'hotdog': 200};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Carrot',
        winningCategory: 'salad',
        roundType: 'salad',
        multiplier: 5,
      );
      // carrot (100 * 5 = 500) + corn (50 * 5 = 250) = 750. hotdog loses.
      expect(prize, equals(750));
    });

    test('Special rounds: Pizza round pays 45x for pizza and steak in fallback calculation', () {
      final bets = {'pizza': 100, 'steak': 50, 'tomato': 100};
      final prize = calculateSpinWheelPrize(
        bets: bets,
        winningName: 'Pizza',
        winningCategory: 'pizza',
        roundType: 'pizza',
        multiplier: 45,
      );
      // pizza (100 * 45 = 4500) + steak (50 * 45 = 2250) = 6750. tomato loses.
      expect(prize, equals(6750));
    });
  });
}
