import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  });
}
