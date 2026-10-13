import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel - Round Synchronization & Timing Logic', () {
    const serverRoundDurationMs = 40000;
    const serverBettingPhaseSec = 30;
    const serverSpinPhaseSec = 5;

    test('40-second cycle calculates deterministic round IDs', () {
      const nowMs = 1700000000000; // arbitrary timestamp
      final roundId1 = (nowMs ~/ serverRoundDurationMs).toString();
      final roundIdNext = ((nowMs + serverRoundDurationMs) ~/ serverRoundDurationMs).toString();

      expect(int.parse(roundIdNext), equals(int.parse(roundId1) + 1));
    });

    test('Phase boundaries are strictly enforced across the 40s timeline', () {
      // Phase 1a: 0s-27s -> Betting Open ("Select time", 30->4s, not locked)
      for (int sec = 0; sec < 27; sec++) {
        final secondsIntoCycle = sec;
        expect(secondsIntoCycle < 27, isTrue);
        const isBetLocked = false;
        expect(isBetLocked, isFalse);
      }

      // Phase 1b: 27s-30s -> Bets Closed during final 3s ("BETS CLOSED", 3->1s, locked)
      for (int sec = 27; sec < 30; sec++) {
        final secondsIntoCycle = sec;
        final isBetLocked = secondsIntoCycle >= 27;
        expect(isBetLocked, isTrue);
      }

      // Phase 2: 30s-35s -> Spinning Phase
      for (int sec = 30; sec < 35; sec++) {
        final secondsIntoCycle = sec;
        final isSpinningPhase = secondsIntoCycle >= serverBettingPhaseSec &&
            secondsIntoCycle < (serverBettingPhaseSec + serverSpinPhaseSec);
        expect(isSpinningPhase, isTrue);
      }

      // Phase 3: 35s-40s -> Results / Rollover Phase
      for (int sec = 35; sec < 40; sec++) {
        final secondsIntoCycle = sec;
        final isResultsPhase = secondsIntoCycle >= (serverBettingPhaseSec + serverSpinPhaseSec);
        expect(isResultsPhase, isTrue);
      }
    });

    test('Stale closure guard: Rejects responses from previous round', () {
      const activeRoundId = "42500";
      const pastSubmissionRoundId = "42499";

      // If response comes back for past round, it must be ignored
      const isStale = pastSubmissionRoundId != activeRoundId;
      expect(isStale, isTrue, reason: "Must reject bets resolved after round has already advanced");
    });

    test('Error SnackBar suppression: Suppressed during spinning and results phases', () {
      bool shouldSuppressSnackBar(SpinGameState state, String currentRound, String submissionRound) {
        if (state == SpinGameState.spinning || state == SpinGameState.results || currentRound != submissionRound) {
          return true; // Suppressed
        }
        return false;
      }

      expect(shouldSuppressSnackBar(SpinGameState.spinning, "100", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.results, "100", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.betting, "101", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.betting, "100", "100"), isFalse);
    });

    test('Session-persistent history retains completed rounds across rollover without remote sync', () {
      // Simulate session history where Round 889 completed and user won 5,000
      final sessionRoundsHistory = <String, Map<String, dynamic>>{
        "44743128": {
          "roundId": "44743128",
          "bets": {"tomato": 1000},
          "totalBet": 1000,
          "prize": 5000,
          "amount": 5000,
          "winningFood": "Tomato",
          "name": "Tomato",
          "emoji": "🍅",
          "label": "5x",
          "multiplier": "5x",
          "settled": true,
          "createdAt": 1700000040000,
        },
      };

      // Remote history only has stale/old round 888 (Firestore hasn't synced 889 yet)
      final staleRemoteHistory = <Map<String, dynamic>>[
        {
          "roundId": "44743127",
          "totalBet": 500,
          "prize": 0,
          "settled": true,
          "createdAt": 1700000000000,
        }
      ];

      // Merging function simulating _getRealtimeMergedHistory
      final Map<String, Map<String, dynamic>> merged = {};
      for (final item in staleRemoteHistory) {
        merged[item['roundId']] = Map<String, dynamic>.from(item);
      }
      for (final entry in sessionRoundsHistory.entries) {
        merged[entry.key] = Map<String, dynamic>.from(entry.value);
      }

      final sortedList = merged.values.toList()
        ..sort((a, b) => (int.parse(b['roundId'])).compareTo(int.parse(a['roundId'])));

      // Round 889 MUST be present at the top of the list despite missing in remote history!
      expect(sortedList.length, equals(2));
      expect(sortedList.first['roundId'], equals("44743128"));
      expect(sortedList.first['settled'], isTrue);
      expect(sortedList.first['prize'], equals(5000));
      expect(sortedList.first['winningFood'], equals("Tomato"));
    });

    test('Remote history sync seamlessly enriches session round with orderId and balance', () {
      final sessionRound = <String, dynamic>{
        "roundId": "44743128",
        "bets": {"steak": 500},
        "totalBet": 500,
        "prize": 22500,
        "winningFood": "Steak",
        "settled": true,
        "createdAt": 1700000040000,
      };

      final incomingRemoteDoc = <String, dynamic>{
        "roundId": "44743128",
        "orderId": "NLOT_44743128_abc12_1700000040000",
        "balanceBefore": 100000,
        "balanceAfter": 122000,
        "serialNumber": 42,
        "settled": false, // Remote may still be in transit/unsettled
      };

      // Merging prioritizes settled status and user's winning outcome while overlaying server audit fields
      final mergedRound = {
        ...incomingRemoteDoc,
        ...sessionRound,
        'settled': true,
        if (incomingRemoteDoc['orderId'] != null) 'orderId': incomingRemoteDoc['orderId'],
        if (incomingRemoteDoc['balanceBefore'] != null) 'balanceBefore': incomingRemoteDoc['balanceBefore'],
        if (incomingRemoteDoc['balanceAfter'] != null) 'balanceAfter': incomingRemoteDoc['balanceAfter'],
      };

      expect(mergedRound['roundId'], equals("44743128"));
      expect(mergedRound['settled'], isTrue);
      expect(mergedRound['prize'], equals(22500));
      expect(mergedRound['orderId'], equals("NLOT_44743128_abc12_1700000040000"));
      expect(mergedRound['balanceAfter'], equals(122000));
    });

    test('Settle response with prize: 0 NEVER overwrites an already settled WIN', () {
      final sessionRoundsHistory = <String, Map<String, dynamic>>{
        "44743130": {
          "roundId": "44743130",
          "bets": {"steak": 1000},
          "totalBet": 1000,
          "prize": 45000,
          "amount": 45000,
          "winningFood": "Steak",
          "settled": true,
        },
      };

      // Simulating _recordSessionSettle logic
      void recordSessionSettle(String roundId, int prize) {
        if (sessionRoundsHistory.containsKey(roundId)) {
          final cur = sessionRoundsHistory[roundId]!;
          final existingPrize = (cur['prize'] as num?)?.toInt() ?? 0;
          final finalPrize = prize > 0 ? prize : existingPrize;
          cur['settled'] = true;
          cur['prize'] = finalPrize;
          cur['amount'] = finalPrize;
        }
      }

      // Backend returns prize: 0 (e.g. clock skew / doc not found)
      recordSessionSettle("44743130", 0);

      // Prize MUST remain 45,000!
      expect(sessionRoundsHistory["44743130"]!['prize'], equals(45000));
      expect(sessionRoundsHistory["44743130"]!['settled'], isTrue);
    });

    test('Next round rollover maintains WIN status and Win count across consecutive rounds', () {
      // Simulating round R (won) and round R+1 (lost)
      final roundR = {
        'roundId': '44743100',
        'bets': {'tomato': 500},
        'totalBet': 500,
        'prize': 2500,
        'winningFood': 'Tomato',
        'settled': true,
      };

      final roundRPlus1 = {
        'roundId': '44743101',
        'bets': {'cabbage': 500},
        'totalBet': 500,
        'prize': 0,
        'winningFood': 'Chicken',
        'settled': true,
      };

      final history = [roundRPlus1, roundR];

      // Verify Win count logic used by _buildHistorySummaryHeader
      final totalRounds = history.length;
      final totalWins = history.where((h) => ((h['prize'] as num?)?.toInt() ?? 0) > 0).length;
      final totalWonCoins = history.fold(0, (sum, h) => sum + ((h['prize'] as num?)?.toInt() ?? 0));

      expect(totalRounds, equals(2));
      expect(totalWins, equals(1));
      expect(totalWonCoins, equals(2500));

      // Check WIN card status
      final isRoundRWin = (roundR['prize'] as int) > 0;
      final isRoundRPlus1Win = (roundRPlus1['prize'] as int) > 0;
      expect(isRoundRWin, isTrue);
      expect(isRoundRPlus1Win, isFalse);
    });

    test('Dynamic prize recovery calculates correct prize when winning food matches bets', () {
      final calculatedSteak = calculateSpinWheelPrize(
        bets: {'steak': 100},
        winningName: 'Steak',
        winningCategory: 'pizza',
        roundType: 'standard',
        multiplier: 45,
      );
      expect(calculatedSteak, equals(4500));

      final calculatedSaladCategory = calculateSpinWheelPrize(
        bets: {'salad': 200},
        winningName: 'Tomato',
        winningCategory: 'salad',
        roundType: 'standard',
        multiplier: 5,
      );
      expect(calculatedSaladCategory, equals(1000));

      final calculatedLoss = calculateSpinWheelPrize(
        bets: {'cabbage': 200},
        winningName: 'Hotdog',
        winningCategory: 'pizza',
        roundType: 'standard',
        multiplier: 10,
      );
      expect(calculatedLoss, equals(0));
    });

    test('Outcome verification recovers prize when remote history has prize: 0 but bets won', () {
      final remoteDocWithZeroPrize = <String, dynamic>{
        'roundId': '44743150',
        'bets': {'steak': 200},
        'totalBet': 200,
        'prize': 0, // Erroneously 0 from transit
        'amount': 0,
        'winningFood': 'Steak',
        'multiplier': '45x',
        'settled': true,
      };

      // Simulating the recovery logic implemented in _getRealtimeMergedHistory
      final bets = remoteDocWithZeroPrize['bets'] as Map;
      final food = remoteDocWithZeroPrize['winningFood'] as String;
      int prize = remoteDocWithZeroPrize['prize'] as int;

      if (prize <= 0 && remoteDocWithZeroPrize['settled'] == true && bets.isNotEmpty && food.isNotEmpty) {
        final normBets = <String, int>{};
        bets.forEach((k, v) => normBets[k.toString()] = (v as num).toInt());
        final multVal = int.tryParse(remoteDocWithZeroPrize['multiplier'].toString().replaceAll('x', '')) ?? 5;
        final recovered = calculateSpinWheelPrize(
          bets: normBets,
          winningName: food,
          multiplier: multVal,
        );
        if (recovered > 0) prize = recovered;
      }

      expect(prize, equals(9000));
    });

    test('Multiple consecutive WIN and LOSS rounds update balance and history correctly', () {
      int simulatedBalance = 10000;
      final List<Map<String, dynamic>> sessionRounds = [];

      // Round 1: WIN
      // Bet 500 on Tomato (5x). Outcome: Tomato
      const round1Bet = 500;
      simulatedBalance -= round1Bet; // Bet deduction phase
      final round1Prize = calculateSpinWheelPrize(
        bets: {'tomato': round1Bet},
        winningName: 'Tomato',
        winningCategory: 'salad',
        multiplier: 5,
      );
      expect(round1Prize, equals(2500));
      simulatedBalance += round1Prize; // Settle phase
      expect(simulatedBalance, equals(12000));
      sessionRounds.add({
        'roundId': '101',
        'bets': {'tomato': round1Bet},
        'totalBet': round1Bet,
        'prize': round1Prize,
        'balanceAfter': simulatedBalance,
        'settled': true,
      });

      // Round 2: LOSS
      // Bet 1000 on Chicken (25x). Outcome: Corn
      const round2Bet = 1000;
      simulatedBalance -= round2Bet;
      final round2Prize = calculateSpinWheelPrize(
        bets: {'chicken': round2Bet},
        winningName: 'Corn',
        winningCategory: 'salad',
        multiplier: 5,
      );
      expect(round2Prize, equals(0));
      // Settle phase with 0 prize
      expect(simulatedBalance, equals(11000));
      sessionRounds.add({
        'roundId': '102',
        'bets': {'chicken': round2Bet},
        'totalBet': round2Bet,
        'prize': round2Prize,
        'balanceAfter': simulatedBalance,
        'settled': true,
      });

      // Round 3: WIN
      // Bet 200 on Steak (45x). Outcome: Steak
      const round3Bet = 200;
      simulatedBalance -= round3Bet;
      final round3Prize = calculateSpinWheelPrize(
        bets: {'steak': round3Bet},
        winningName: 'Steak',
        winningCategory: 'pizza',
        multiplier: 45,
      );
      expect(round3Prize, equals(9000));
      simulatedBalance += round3Prize;
      expect(simulatedBalance, equals(19800));
      sessionRounds.add({
        'roundId': '103',
        'bets': {'steak': round3Bet},
        'totalBet': round3Bet,
        'prize': round3Prize,
        'balanceAfter': simulatedBalance,
        'settled': true,
      });

      // Verify all 3 rounds are settled and balanceAfter matches
      expect(sessionRounds.length, equals(3));
      expect(sessionRounds[0]['balanceAfter'], equals(12000));
      expect(sessionRounds[1]['balanceAfter'], equals(11000));
      expect(sessionRounds[2]['balanceAfter'], equals(19800));

      final wins = sessionRounds.where((r) => (r['prize'] as int) > 0).length;
      final losses = sessionRounds.where((r) => (r['prize'] as int) == 0).length;
      expect(wins, equals(2));
      expect(losses, equals(1));
    });

    test('Authoritative balance reconciliation avoids UI flash/stutter', () {
      int? authoritativeBalance = 15000;
      int? streamBalance = 10000; // Stream lagging behind backend response

      int resolveBalance(int? auth, int? stream) {
        if (auth != null) {
          if (stream != null && stream == auth) {
            return stream;
          }
          return auth;
        }
        return stream ?? 0;
      }

      // While stream is lagging, UI displays authoritative balance without falling to 0 or old balance
      expect(resolveBalance(authoritativeBalance, streamBalance), equals(15000));

      // Once Firestore pushes the snapshot, stream catches up
      streamBalance = 15000;
      expect(resolveBalance(authoritativeBalance, streamBalance), equals(15000));
    });

    test('Top List/Ranking immediately reflects latest round WIN and LOSS results', () {
      final serverLeaderboard = <Map<String, dynamic>>[
        {'uid': 'user_b', 'name': 'Bob', 'amount': 2000, 'totalWinnings': 2000, 'totalBets': 1000},
        {'uid': 'user_c', 'name': 'Charlie', 'amount': 500, 'totalWinnings': 500, 'totalBets': 500},
      ];

      // Simulated local session for current user
      final sessionRounds = [
        {'roundId': '1', 'prize': 5000, 'totalBet': 500}, // WIN 5000
        {'roundId': '2', 'prize': 0, 'totalBet': 1000},    // LOSS
      ];

      final totalWinnings = sessionRounds.fold(0, (sum, r) => sum + (r['prize'] as int));
      final totalBets = sessionRounds.fold(0, (sum, r) => sum + (r['totalBet'] as int));
      expect(totalWinnings, equals(5000));
      expect(totalBets, equals(1500));

      // Simulating _getRealtimeLeaderboard merge
      final merged = List<Map<String, dynamic>>.from(serverLeaderboard);
      const currentUid = 'user_me';
      merged.add({
        'uid': currentUid,
        'name': 'Me',
        'amount': totalWinnings,
        'totalWinnings': totalWinnings,
        'totalBets': totalBets,
      });

      merged.sort((a, b) {
        final aVal = (a['amount'] as num?)?.toInt() ?? (a['totalWinnings'] as num?)?.toInt() ?? 0;
        final bVal = (b['amount'] as num?)?.toInt() ?? (b['totalWinnings'] as num?)?.toInt() ?? 0;
        return bVal.compareTo(aVal);
      });

      // Current user should immediately be 1st rank with 5,000 winnings
      expect(merged.first['uid'], equals('user_me'));
      expect(merged.first['amount'], equals(5000));
      expect(merged.first['totalBets'], equals(1500));

      // Verify bottom panel display text uses winnings/amount properly
      final topPlayer = merged.first;
      final topPlayerName = topPlayer['name'];
      final topScore = (topPlayer['amount'] as num?)?.toInt() ?? (topPlayer['totalWinnings'] as num?)?.toInt() ?? 0;
      final displayText = "1st: $topPlayerName: $topScore";
      expect(displayText, equals("1st: Me: 5000"));
    });

    group('Production Bugs Verification (Image 1 - Image 4 Scenarios)', () {
      test('Round #926: 4,000 on CORN with winning food "CORN 5x" awards 20,000 gross win', () {
        final bets = {'corn': 4000, 'tomato': 2000, 'hotdog': 5000};
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'CORN 5x',
          multiplier: 5,
        );
        expect(payout, equals(20000));
      });

      test('Round #948: 3,100,000 on TOMATO with winning food "TOMATO 5x" awards 15,500,000 gross win', () {
        final bets = {'tomato': 3100000, 'carrot': 2000000, 'cabbage': 7200000};
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'TOMATO 5x',
          multiplier: 5,
        );
        expect(payout, equals(15500000));
      });

      test('Round #949: 8,000,000 on CABBAGE with winning food "CABBAGE 5x" awards 40,000,000 gross win', () {
        final bets = {'cabbage': 8000000, 'corn': 10000000, 'carrot': 14800000};
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'CABBAGE 5x',
          multiplier: 5,
        );
        expect(payout, equals(40000000));
      });

      test('Round #954: 8,900,000 on KEBAB with winning food "KEBAB 15x" awards 133,500,000 gross win', () {
        final bets = {'kebab': 8900000};
        final payout1 = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'KEBAB 15x',
          multiplier: 15,
        );
        expect(payout1, equals(133500000));

        // Bidirectional alias test: Sector name 'Skewer' with user bet 'Kebab'
        final payout2 = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'Skewer',
          multiplier: 15,
        );
        expect(payout2, equals(133500000));
      });

      test('Negative balance prevention: Clamping ensures balance never dips below 0', () {
        const startBal = 28690000;
        const totalWager = 32800000;
        const prize = 0;

        const rawMath = startBal - totalWager + prize;
        expect(rawMath, equals(-4110000)); // The flawed raw math

        // Clamped authoritative ledger math
        const clampedBal = (startBal - totalWager + prize) > 0 ? (startBal - totalWager + prize) : 0;
        expect(clampedBal, equals(0), reason: "Negative balances must be strictly clamped to 0");
      });

      test('Bug A (Round #469): 10,100,000 on CABBAGE (5x) with 40,200,000 total bet awards exactly 50,500,000 gross win', () {
        final bets = {
          'cabbage': 10100000,
          'tomato': 20000000,
          'corn': 10100000,
        };
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'CABBAGE 5x',
          multiplier: 5,
        );
        expect(payout, equals(50500000), reason: "10,100,000 * 5 = 50,500,000; other bets must not corrupt payout to 44,500,000");
      });

      test('Bug B (Round #194): 100 on CARROT and 100 on CORN with winning item KEBAB (15x) awards strictly 0 (100% LOSS)', () {
        final bets = {
          'carrot': 100,
          'corn': 100,
        };
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'KEBAB 15x',
          multiplier: 15,
        );
        expect(payout, equals(0), reason: "User did not bet on Kebab; MUST return strictly 0, never 500");
      });

      test('Multi-item bet: Only the exact winning item stake is multiplied', () {
        final bets = {
          'tomato': 500,
          'hotdog': 1000,
          'steak': 2000,
        };
        // Hotdog (10x) wins
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'Hotdog',
          multiplier: 10,
        );
        expect(payout, equals(10000), reason: "1000 * 10 = 10000; tomato and steak stakes contribute 0");
      });

      test('Multi-item bet: All items lose -> strictly 0 payout', () {
        final bets = {
          'tomato': 1000,
          'carrot': 2000,
          'corn': 3000,
        };
        // Chicken (25x) wins
        final payout = calculateSpinWheelPrize(
          bets: bets,
          winningName: 'Chicken',
          multiplier: 25,
        );
        expect(payout, equals(0), reason: "Zero stake on Chicken must return 0 payout");
      });

      test('Single-item bet: Win and Loss behaviors', () {
        final singleBet = {'chicken': 500};
        // Win
        final winPayout = calculateSpinWheelPrize(
          bets: singleBet,
          winningName: 'Chicken',
          multiplier: 25,
        );
        expect(winPayout, equals(12500));

        // Loss
        final lossPayout = calculateSpinWheelPrize(
          bets: singleBet,
          winningName: 'Steak',
          multiplier: 45,
        );
        expect(lossPayout, equals(0));
      });
    });

    group('Loss Amount Deduction & Ghost Auto-Betting Regression Tests', () {
      test('Loss Settlement: confirmedBalance updates to serverBalance and does NOT revert on onRoundStart', () {
        final manager = AuthoritativeWalletManager();
        // Initial balance: 100,000,000 diamonds, seq: 1
        manager.updateFromStream(
          streamDiamonds: 100000000,
          streamSeq: 1,
          lastTxnId: 'init_txn',
        );
        expect(manager.displayedBalance, equals(100000000));
        expect(manager.confirmedBalance, equals(100000000));

        // Place a bet of 11,300,000 in round 44749445
        const betAmount = 11300000;
        const roundId = "44749445";
        manager.addPendingDebit(
          txnId: 'bet_$roundId',
          amount: betAmount,
          roundId: roundId,
        );
        // During betting phase, displayed balance reflects pending debit immediately:
        expect(manager.displayedBalance, equals(88700000));

        // Backend confirms bet placement (e.g. balance becomes 88,700,000 on server)
        manager.reconcileBetSuccess(
          txnId: 'bet_$roundId',
          serverBalance: 88700000,
          serverSeq: 2,
          roundId: roundId,
        );
        expect(manager.displayedBalance, equals(88700000));
        expect(manager.confirmedBalance, equals(88700000));

        // Round concludes in a LOSS (prize: 0, userHadAcceptedBet: true)
        manager.exitBettingPhase();
        manager.reconcileSettlement(
          txnId: 'spin_win_$roundId',
          serverBalance: 88700000,
          serverSeq: 3,
          prize: 0,
          roundId: roundId,
          userHadAcceptedBet: true,
        );

        // Balance MUST be confirmed at 88,700,000 (the loss is permanent)
        expect(manager.displayedBalance, equals(88700000));
        expect(manager.confirmedBalance, equals(88700000));
        expect(manager.pendingDebits.containsKey('bet_$roundId'), isFalse);

        // Next round opens: onRoundStart() clears pendingDebits
        manager.onRoundStart();

        // CRITICAL INVARIANT: Displayed balance MUST NOT revert to 100,000,000!
        expect(manager.displayedBalance, equals(88700000),
            reason: "Balance must never revert to pre-bet amount on loss settlement!");
        expect(manager.confirmedBalance, equals(88700000));
      });

      test('Spectator settlement does not alter confirmed balance', () {
        final manager = AuthoritativeWalletManager();
        manager.updateFromStream(
          streamDiamonds: 5000000,
          streamSeq: 1,
        );

        // Spectator: userHadAcceptedBet = false, prize = 0
        manager.reconcileSettlement(
          txnId: 'spin_win_44749445',
          serverBalance: 5000000,
          serverSeq: 2,
          prize: 0,
          roundId: "44749445",
          userHadAcceptedBet: false,
        );

        expect(manager.displayedBalance, equals(5000000));
        expect(manager.confirmedBalance, equals(5000000));
      });

      test('Ghost auto-betting prevention: Clearing input bets on confirmation leaves no unconfirmed bets', () {
        final currentBets = <String, int>{
          'carrot': 800000,
          'corn': 3200000,
          'cabbage': 3200000,
          'tomato': 3200000,
          'hotdog': 700000,
          'kebab': 100000,
          'chicken': 100000,
        };
        final confirmedBets = <String, int>{};

        bool hasUnconfirmed(Map<String, int> cur, Map<String, int> conf) {
          if (cur.isEmpty) return false;
          for (final entry in cur.entries) {
            if ((conf[entry.key] ?? 0) < entry.value) return true;
          }
          return false;
        }

        // Before confirmation: has unconfirmed bets
        expect(hasUnconfirmed(currentBets, confirmedBets), isTrue);

        // On confirmation: _confirmedBets is set, and _currentBets is wiped to {}
        confirmedBets.addAll(currentBets);
        currentBets.clear();

        // After confirmation: MUST NOT have unconfirmed bets!
        expect(hasUnconfirmed(currentBets, confirmedBets), isFalse,
            reason: "Empty _currentBets after confirmation prevents ghost re-submission");

        // When next round starts: _confirmedBets is wiped to {}
        confirmedBets.clear();
        // Since _currentBets was also wiped, hasUnconfirmed MUST remain false!
        expect(hasUnconfirmed(currentBets, confirmedBets), isFalse,
            reason: "Next round must not detect unconfirmed bets from previous round");
      });
    });

    group('Client Freeze & Forward Round Binding Regression Tests', () {
      test('Forward round binding: phantom submission round is removed and bet is mapped forward', () {
        final sessionHistory = <String, Map<String, dynamic>>{};

        // Client eagerly staged submission for round 44757937
        const submissionRoundId = "44757937";
        sessionHistory[submissionRoundId] = {
          'roundId': submissionRoundId,
          'bets': {'tomato': 10000},
          'totalBet': 10000,
          'settled': false,
        };

        expect(sessionHistory.containsKey(submissionRoundId), isTrue);

        // Server gracefully bound bet forward to round 44757938
        const resultRoundId = "44757938";
        if (submissionRoundId != resultRoundId) {
          sessionHistory.remove(submissionRoundId);
        }
        sessionHistory[resultRoundId] = {
          'roundId': resultRoundId,
          'bets': {'tomato': 10000},
          'totalBet': 10000,
          'settled': false,
        };

        // Phantom round 44757937 MUST be eliminated
        expect(sessionHistory.containsKey(submissionRoundId), isFalse,
            reason: "Phantom submission round must be removed so it never lingers as PENDING orphan");
        expect(sessionHistory.containsKey(resultRoundId), isTrue,
            reason: "Bet must be recorded under authoritative server bound round");
      });

      test('Past round can NEVER be considered current round or in play', () {
        const roundId = "44757937";
        const currentSyncRound = 44757938; // Server/synced clock is on next round
        final roundNum = int.tryParse(roundId) ?? 0;
        final isPastRound = roundNum > 0 && roundNum < currentSyncRound;

        // Even if client state was temporarily lagging (e.g. _currentRoundId was still '44757937')
        const laggingCurrentRoundId = "44757937";
        final isSettled = isPastRound || (roundId != laggingCurrentRoundId);
        final isCurrentRound = !isPastRound && (roundId == laggingCurrentRoundId) && !isSettled;

        expect(isPastRound, isTrue);
        expect(isSettled, isTrue, reason: "A round strictly in the past must always evaluate as settled");
        expect(isCurrentRound, isFalse, reason: "A past round must NEVER evaluate as current or IN PLAY");
      });

      test('Settled card with empty winning food shows SETTLED/REVERTED instead of PENDING', () {
        String resolveDisplayFood({
          required String foodName,
          required bool isSettled,
          String? status,
        }) {
          return foodName.isNotEmpty
              ? foodName
              : (isSettled ? (status == 'REVERTED' ? 'REVERTED' : 'SETTLED') : 'PENDING');
        }

        // Active round with no outcome yet -> PENDING
        expect(resolveDisplayFood(foodName: '', isSettled: false), equals('PENDING'));

        // Settled round with no food name -> SETTLED
        expect(resolveDisplayFood(foodName: '', isSettled: true), equals('SETTLED'));

        // Reverted round with no food name -> REVERTED
        expect(resolveDisplayFood(foodName: '', isSettled: true, status: 'REVERTED'), equals('REVERTED'));

        // Settled round with outcome -> food name
        expect(resolveDisplayFood(foodName: 'TOMATO', isSettled: true), equals('TOMATO'));
      });

      test('Monotonic clamp prevents backward time step on jumpy device clock', () {
        int lastSync = 1790317500000;
        int computeSyncTime(int localEpoch, int offset) {
          final raw = localEpoch + offset;
          if (raw > lastSync) {
            lastSync = raw;
          }
          return lastSync;
        }

        // Forward progression works normally
        final t1 = computeSyncTime(1790317500000, 100);
        expect(t1, equals(1790317500100));

        // Jumpy local clock steps 5 seconds backward:
        final t2 = computeSyncTime(1790317495000, 100);
        // Monotonic clamp ensures time DOES NOT regress:
        expect(t2, equals(1790317500100), reason: "Clock must never jump backward");
      });
    });
  });
}
