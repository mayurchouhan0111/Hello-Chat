import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel - Diamond Balance Deduction & Real-Time Updating', () {
    int calculateDisplayedBalance({
      required int serverBalance,
      required Map<String, int> currentBets,
      required Map<String, int> confirmedBets,
      int optimisticWinnings = 0,
    }) {
      final totalLocalBet = currentBets.values.fold(0, (sum, val) => sum + val);
      final totalConfirmedBet = confirmedBets.values.fold(0, (sum, val) => sum + val);
      final pendingUnconfirmedBet = math.max(0, totalLocalBet - totalConfirmedBet);
      return math.max(0, serverBalance - pendingUnconfirmedBet + optimisticWinnings);
    }

    test('Single Bet: 100 Diamonds bet immediately deducts exactly 100, and server confirmation causes zero double-deduction', () {
      int initialBalance = 5000;
      final currentBets = <String, int>{};
      final confirmedBets = <String, int>{};

      // Step 1: Initial state
      int displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(5000));

      // Step 2: User taps 100 chip on Tomato
      currentBets['Tomato'] = 100;
      displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(4900), reason: "Balance must be deducted immediately by 100");

      // Step 3: Backend confirms 100 bet and deducts from Firestore
      initialBalance = 4900; // Updated from Firestore stream
      confirmedBets['Tomato'] = 100;
      displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(4900), reason: "Balance must remain exactly 4900 without double-deduction");
    });

    test('Single Bet: 500 Diamonds bet immediately deducts exactly 500', () {
      int initialBalance = 10000;
      final currentBets = <String, int>{};
      final confirmedBets = <String, int>{};

      // User bets 500 on Steak
      currentBets['Steak'] = 500;
      int displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(9500), reason: "Must deduct exactly 500");

      // Backend commits
      initialBalance = 9500;
      confirmedBets['Steak'] = 500;
      displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(9500), reason: "Zero double-deduction on 500 bet");
    });

    test('Single Bet: 1000 Diamonds bet immediately deducts exactly 1000', () {
      int initialBalance = 10000;
      final currentBets = <String, int>{};
      final confirmedBets = <String, int>{};

      // User bets 1000 on Hotdog
      currentBets['Hotdog'] = 1000;
      int displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(9000), reason: "Must deduct exactly 1000");

      // Backend commits
      initialBalance = 9000;
      confirmedBets['Hotdog'] = 1000;
      displayed = calculateDisplayedBalance(
        serverBalance: initialBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      );
      expect(displayed, equals(9000), reason: "Zero double-deduction on 1000 bet");
    });

    test('Sequential Multi-Bet: 100 -> 500 -> 1000 keeps balance completely accurate at every tap', () {
      int serverBalance = 10000;
      final currentBets = <String, int>{};
      final confirmedBets = <String, int>{};

      // 1. Tap 100 on Tomato
      currentBets['Tomato'] = 100;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(9900));

      // Server confirms 100
      serverBalance = 9900;
      confirmedBets['Tomato'] = 100;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(9900));

      // 2. Tap 500 on Steak
      currentBets['Steak'] = 500;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(9400));

      // Server confirms 500
      serverBalance = 9400;
      confirmedBets['Steak'] = 500;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(9400));

      // 3. Tap 1000 on Hotdog
      currentBets['Hotdog'] = 1000;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(8400));

      // Server confirms 1000
      serverBalance = 8400;
      confirmedBets['Hotdog'] = 1000;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(8400));
    });

    test('Winnings Payout: Bet deduction during betting phase, and prize credit at round reveal', () {
      int serverBalance = 10000;
      final currentBets = {'Tomato': 100};
      final confirmedBets = {'Tomato': 100};
      serverBalance = 9900; // Deducted 100 on server

      // While wheel is spinning: balance is 9900 (NO premature winnings)
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
      ), equals(9900));

      // Wheel lands on Tomato (5x win -> 500 prize):
      // Client optimistic winnings applied
      currentBets.clear();
      confirmedBets.clear();
      int optimisticWinnings = 500;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
        optimisticWinnings: optimisticWinnings,
      ), equals(10400), reason: "Displays 9900 + 500 win = 10400");

      // Server settles round: adds 500 to serverBalance
      serverBalance = 10400;
      optimisticWinnings = 0;
      expect(calculateDisplayedBalance(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
        optimisticWinnings: optimisticWinnings,
      ), equals(10400), reason: "Settled balance matches exactly 10400");
    });
  });

  group('Spin Wheel - Funds Validation & No False Rejection', () {
    bool canPlaceChip({
      required int serverBalance,
      required Map<String, int> currentBets,
      required Map<String, int> confirmedBets,
      required int chipValue,
    }) {
      final currentTotalBet = currentBets.values.fold(0, (sum, val) => sum + val);
      final confirmedTotalBet = confirmedBets.values.fold(0, (sum, val) => sum + val);
      final pendingUnconfirmedBet = math.max(0, currentTotalBet - confirmedTotalBet);
      return pendingUnconfirmedBet + chipValue <= serverBalance;
    }

    test('User with 1000 Diamonds bets 600 (confirmed), can still bet remaining 400', () {
      // 1000 starting balance, 600 confirmed -> serverBalance is now 400
      const serverBalance = 400;
      final currentBets = {'Tomato': 600};
      final confirmedBets = {'Tomato': 600};

      // Tap 200 chip: must be ALLOWED
      expect(canPlaceChip(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
        chipValue: 200,
      ), isTrue, reason: "Must allow betting up to remaining 400 balance");

      // Tap another 200 chip (total 400 unconfirmed): must be ALLOWED
      currentBets['Steak'] = 200;
      expect(canPlaceChip(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
        chipValue: 200,
      ), isTrue, reason: "Must allow exhausting remaining balance");

      // Tap 100 chip beyond 400: must be REJECTED
      currentBets['Steak'] = 400;
      expect(canPlaceChip(
        serverBalance: serverBalance,
        currentBets: currentBets,
        confirmedBets: confirmedBets,
        chipValue: 100,
      ), isFalse, reason: "Must reject when exceeding available balance");
    });
  });

  group('Lucky Draw - Balance Net Change Math', () {
    int calculateLuckyDrawFinalBalance(int initialBalance, int betAmount, int prize) {
      final netChange = prize - betAmount;
      return initialBalance + netChange;
    }

    test('Loss: 100 bet, 0 prize -> exactly 100 deducted', () {
      final finalBal = calculateLuckyDrawFinalBalance(1000, 100, 0);
      expect(finalBal, equals(900));
    });

    test('Win: 100 bet, 10x prize (1000) -> balance increases by 900 net', () {
      final finalBal = calculateLuckyDrawFinalBalance(1000, 100, 1000);
      expect(finalBal, equals(1900));
    });

    test('500 bet, 0 prize -> exactly 500 deducted', () {
      final finalBal = calculateLuckyDrawFinalBalance(5000, 500, 0);
      expect(finalBal, equals(4500));
    });
  });
}
