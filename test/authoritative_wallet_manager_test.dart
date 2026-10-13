import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthoritativeWalletManager - Production Test Matrix (Scenarios A through O)', () {
    late AuthoritativeWalletManager walletManager;

    setUp(() {
      walletManager = AuthoritativeWalletManager();
    });

    test('Scenario A: NO BET - Balance 800 -> Watch 5+ complete rounds -> MUST remain 800', () {
      // User opens game with balance 800 at seq 41
      final applied = walletManager.updateFromStream(
        streamDiamonds: 800,
        streamSeq: 41,
        lastTxnId: 'init_txn',
      );
      expect(applied, isTrue);
      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.seq, equals(41));

      // Watch 5 consecutive rounds without placing any bets
      for (int round = 1; round <= 5; round++) {
        // 1. Round Start / Betting Phase
        walletManager.onRoundStart();
        expect(walletManager.isBettingPhase, isTrue);
        expect(walletManager.displayedBalance, equals(800));

        // 2. Periodic Firestore heartbeats / presence updates (seq 0 or stale seq 41)
        final ignoredHeartbeat = walletManager.updateFromStream(
          streamDiamonds: 800,
          streamSeq: 0,
          lastTxnId: 'presence_heartbeat_r$round',
        );
        expect(ignoredHeartbeat, isFalse);
        expect(walletManager.displayedBalance, equals(800));

        // 3. Betting closes at 30s
        walletManager.exitBettingPhase();
        expect(walletManager.isBettingPhase, isFalse);
        expect(walletManager.displayedBalance, equals(800));

        // 4. Wheel lands at 35s - Spectator settlement attempt (user had NO bet)
        walletManager.reconcileSettlement(
          txnId: 'spin_win_round_$round',
          serverBalance: 800,
          serverSeq: 41,
          prize: 0,
          roundId: 'round_$round',
          userHadAcceptedBet: false, // NO BET PLACED
        );
        expect(walletManager.displayedBalance, equals(800));
        expect(walletManager.confirmedBalance, equals(800));
        expect(walletManager.seq, equals(41));

        // 5. Results phase at 35s-39s
        walletManager.exitBettingPhaseAndApplyDeferredCredits();
        expect(walletManager.displayedBalance, equals(800));
      }

      // FINAL INVARIANT: After 5 full rounds with zero bets, balance is STILL exactly 800!
      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.seq, equals(41));
    });

    test('Scenario B: LOSS - 800 -> bet 75 -> 725 immediately -> LOSS -> remain 725', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.enterBettingPhase();

      // Place bet 75
      const betTxnId = 'bet_loss_1';
      walletManager.addPendingDebit(txnId: betTxnId, amount: 75, roundId: '100');
      expect(walletManager.displayedBalance, equals(725));

      // Backend confirms bet deduction
      walletManager.reconcileBetSuccess(
        txnId: betTxnId,
        serverBalance: 725,
        serverSeq: 42,
        roundId: '100',
      );
      expect(walletManager.confirmedBalance, equals(725));
      expect(walletManager.displayedBalance, equals(725));
      expect(walletManager.seq, equals(42));

      // Round ends with LOSS
      walletManager.exitBettingPhase();
      walletManager.reconcileSettlement(
        txnId: 'spin_win_round_100',
        serverBalance: 725,
        serverSeq: 42,
        prize: 0,
        roundId: '100',
        userHadAcceptedBet: true,
      );

      expect(walletManager.confirmedBalance, equals(725));
      expect(walletManager.displayedBalance, equals(725));
      expect(walletManager.seq, equals(42));
    });

    test('Scenario C: WIN - 800 -> bet 75 -> 725 immediately -> WIN -> credit exact authoritative reward once', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.enterBettingPhase();

      const betTxnId = 'bet_win_1';
      walletManager.addPendingDebit(txnId: betTxnId, amount: 75, roundId: '101');
      expect(walletManager.displayedBalance, equals(725));

      walletManager.reconcileBetSuccess(
        txnId: betTxnId,
        serverBalance: 725,
        serverSeq: 42,
        roundId: '101',
      );
      expect(walletManager.displayedBalance, equals(725));

      // Betting ends, wheel spins and lands on user's pod
      walletManager.exitBettingPhase();

      // Backend settles win: prize 375, serverBalance 1100, seq 43
      const winTxnId = 'spin_win_round_101';
      walletManager.reconcileSettlement(
        txnId: winTxnId,
        serverBalance: 1100,
        serverSeq: 43,
        prize: 375,
        roundId: '101',
        userHadAcceptedBet: true,
      );

      expect(walletManager.confirmedBalance, equals(1100));
      expect(walletManager.displayedBalance, equals(1100));
      expect(walletManager.seq, equals(43));
    });

    test('Scenario D: MULTIPLE BETS - Verify every transaction independently', () {
      walletManager.updateFromStream(streamDiamonds: 1000, streamSeq: 10);
      walletManager.enterBettingPhase();

      const txn1 = 'bet_carrot';
      const txn2 = 'bet_steak';
      const txn3 = 'bet_pizza';

      walletManager.addPendingDebit(txnId: txn1, amount: 100, roundId: '200');
      expect(walletManager.displayedBalance, equals(900));

      walletManager.addPendingDebit(txnId: txn2, amount: 200, roundId: '200');
      expect(walletManager.displayedBalance, equals(700));

      walletManager.addPendingDebit(txnId: txn3, amount: 50, roundId: '200');
      expect(walletManager.displayedBalance, equals(650));
      expect(walletManager.pendingDebits.length, equals(3));

      // Reconcile txn2 first
      walletManager.reconcileBetSuccess(txnId: txn2, serverBalance: 800, serverSeq: 11, roundId: '200');
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.displayedBalance, equals(650)); // 800 - 150 = 650

      // Reconcile txn1 next
      walletManager.reconcileBetSuccess(txnId: txn1, serverBalance: 700, serverSeq: 12, roundId: '200');
      expect(walletManager.confirmedBalance, equals(700));
      expect(walletManager.displayedBalance, equals(650)); // 700 - 50 = 650

      // Reconcile txn3 last
      walletManager.reconcileBetSuccess(txnId: txn3, serverBalance: 650, serverSeq: 13, roundId: '200');
      expect(walletManager.confirmedBalance, equals(650));
      expect(walletManager.displayedBalance, equals(650));
      expect(walletManager.pendingDebits.isEmpty, isTrue);
      expect(walletManager.seq, equals(13));
    });

    test('Scenario E: RAPID BETS - Verify no double deduction', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 40);
      walletManager.enterBettingPhase();

      const betTxnId = 'bet_batch_1';

      // 3 rapid taps: 100 + 100 + 100 = 300
      walletManager.addPendingDebit(txnId: betTxnId, amount: 100);
      walletManager.addPendingDebit(txnId: betTxnId, amount: 100);
      walletManager.addPendingDebit(txnId: betTxnId, amount: 100);
      expect(walletManager.displayedBalance, equals(500));

      // In-flight first batch confirmation (100 confirmed, 200 remaining pending)
      walletManager.reconcileBetSuccess(
        txnId: betTxnId,
        serverBalance: 700,
        serverSeq: 41,
        remainingPendingAmount: 200,
      );
      expect(walletManager.confirmedBalance, equals(700));
      expect(walletManager.displayedBalance, equals(500)); // Stays 500, never jumps to 700

      // Second batch confirmation (remaining 200 confirmed)
      walletManager.reconcileBetSuccess(
        txnId: betTxnId,
        serverBalance: 500,
        serverSeq: 42,
        remainingPendingAmount: 0,
      );
      expect(walletManager.confirmedBalance, equals(500));
      expect(walletManager.displayedBalance, equals(500));
      expect(walletManager.pendingDebits.isEmpty, isTrue);
    });

    test('Scenario F: DUPLICATE SOCKET EVENT - No duplicate wallet mutation', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);

      // Duplicate socket event with same sequence arrives
      final appliedDup = walletManager.updateFromStream(
        streamDiamonds: 800,
        streamSeq: 41,
        lastTxnId: 'dup_socket_event',
      );
      expect(appliedDup, isFalse);
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.seq, equals(41));
    });

    test('Scenario G: DUPLICATE RESULT EVENT - No duplicate reward (Idempotency)', () {
      walletManager.updateFromStream(streamDiamonds: 725, streamSeq: 42);
      walletManager.exitBettingPhase();

      const winTxnId = 'spin_win_round_999';

      // First settlement delivery: prize 200 credited
      walletManager.reconcileSettlement(
        txnId: winTxnId,
        serverBalance: 925,
        serverSeq: 43,
        prize: 200,
        roundId: '999',
        userHadAcceptedBet: true,
      );
      expect(walletManager.confirmedBalance, equals(925));
      expect(walletManager.displayedBalance, equals(925));
      expect(walletManager.seq, equals(43));

      // Duplicate delivery of the exact same settlement event
      walletManager.reconcileSettlement(
        txnId: winTxnId,
        serverBalance: 925,
        serverSeq: 43,
        prize: 200,
        roundId: '999',
        userHadAcceptedBet: true,
      );

      // Invariant: Balance MUST NOT double credit to 1125! Stays 925!
      expect(walletManager.confirmedBalance, equals(925));
      expect(walletManager.displayedBalance, equals(925));
      expect(walletManager.seq, equals(43));
    });

    test('Scenario H: OLD FIRESTORE CACHE - Must never restore old balance', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.addPendingDebit(txnId: 'bet_1', amount: 75);
      walletManager.reconcileBetSuccess(txnId: 'bet_1', serverBalance: 725, serverSeq: 42);

      // Cached snapshot with balance 800 and seq 41 arrives late
      final appliedCache = walletManager.updateFromStream(
        streamDiamonds: 800,
        streamSeq: 41,
        fromCache: true,
        lastTxnId: 'cached_stale_doc',
      );

      expect(appliedCache, isFalse);
      expect(walletManager.confirmedBalance, equals(725));
      expect(walletManager.displayedBalance, equals(725));
      expect(walletManager.seq, equals(42));
    });

    test('Scenario I: APP RESTART - Latest server wallet state must be restored', () {
      // Brand new manager instance simulates fresh app startup
      final freshWalletManager = AuthoritativeWalletManager();
      expect(freshWalletManager.hasInitialBalance, isFalse);

      // Firestore delivers latest user profile document
      final applied = freshWalletManager.updateFromStream(
        streamDiamonds: 950,
        streamSeq: 55,
        lastTxnId: 'init_after_restart',
      );

      expect(applied, isTrue);
      expect(freshWalletManager.hasInitialBalance, isTrue);
      expect(freshWalletManager.confirmedBalance, equals(950));
      expect(freshWalletManager.displayedBalance, equals(950));
      expect(freshWalletManager.seq, equals(55));
    });

    test('Scenario J: RECONNECT - No duplicate listeners or duplicate transactions', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.addPendingDebit(txnId: 'bet_reconnect', amount: 100);
      walletManager.reconcileBetSuccess(
        txnId: 'bet_reconnect',
        serverBalance: 700,
        serverSeq: 42,
      );

      // Reconnect fires: re-subscribes and pushes same stream event
      final reconnectedEvent = walletManager.updateFromStream(
        streamDiamonds: 700,
        streamSeq: 42,
        lastTxnId: 'bet_reconnect',
      );

      expect(reconnectedEvent, isFalse);
      expect(walletManager.confirmedBalance, equals(700));
      expect(walletManager.displayedBalance, equals(700));
      expect(walletManager.seq, equals(42));
    });

    test('Scenario K: ROUND TRANSITION - Balance must not change simply because a new round begins', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      expect(walletManager.displayedBalance, equals(800));

      // Transition across 3 rounds without betting
      for (int i = 0; i < 3; i++) {
        walletManager.onRoundStart();
        expect(walletManager.displayedBalance, equals(800));
        walletManager.exitBettingPhase();
        expect(walletManager.displayedBalance, equals(800));
      }
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.seq, equals(41));
    });

    test('Scenario L: USER WITHOUT BET - Game results, room events, ranking events must NOT change balance', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.enterBettingPhase();

      // Wheel lands on Carrot (5x), but user placed NO bet
      walletManager.exitBettingPhase();

      // UI result event arrives
      walletManager.reconcileSettlement(
        txnId: 'spin_win_round_500',
        serverBalance: 800,
        serverSeq: 41,
        prize: 0,
        roundId: '500',
        userHadAcceptedBet: false,
      );

      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.seq, equals(41));
    });

    test('Scenario M: TWO USERS IN SAME ROOM - Another user result/reward must NEVER affect current user', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.enterBettingPhase();

      // User A (current user) placed NO bet.
      // User B in the same room placed 1,000 on Pizza and won 45,000!
      // Room event broadcasts User B win.
      // Current user manager must strictly ignore it:
      walletManager.exitBettingPhase();
      walletManager.reconcileSettlement(
        txnId: 'spin_win_userB_round_501',
        serverBalance: 800,
        serverSeq: 41,
        prize: 0,
        roundId: '501',
        userHadAcceptedBet: false,
      );

      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.confirmedBalance, equals(800));
    });

    test('Scenario N: SLOW NETWORK - Out-of-order responses must not overwrite newer wallet state', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);

      // Fast forward to seq 45 with balance 1200 (external top up during betting phase)
      walletManager.updateFromStream(streamDiamonds: 1200, streamSeq: 45);
      expect(walletManager.confirmedBalance, equals(1200));
      // Displayed balance remains safely clamped to 800 during active betting phase!
      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.seq, equals(45));

      // Betting phase closes -> displayed balance reveals confirmed 1200
      walletManager.exitBettingPhase();
      expect(walletManager.displayedBalance, equals(1200));

      // Delayed packet from seq 43 (balance 900) arrives late
      final slowPacket = walletManager.updateFromStream(
        streamDiamonds: 900,
        streamSeq: 43,
      );

      // Must be rejected!
      expect(slowPacket, isFalse);
      expect(walletManager.confirmedBalance, equals(1200));
      expect(walletManager.displayedBalance, equals(1200));
      expect(walletManager.seq, equals(45));
    });

    test('Scenario O: FAILED TRANSACTION - No phantom credit or phantom deduction', () {
      walletManager.updateFromStream(streamDiamonds: 800, streamSeq: 41);
      walletManager.enterBettingPhase();

      const txnId = 'bet_failed_insufficient';
      walletManager.addPendingDebit(txnId: txnId, amount: 200);
      expect(walletManager.displayedBalance, equals(600));

      // Reconcile failure
      walletManager.reconcileBetFailure(
        txnId: txnId,
        errorMessage: 'Insufficient balance on server',
      );

      // Balance returns cleanly to 800 with zero drift
      expect(walletManager.displayedBalance, equals(800));
      expect(walletManager.confirmedBalance, equals(800));
      expect(walletManager.pendingDebits.isEmpty, isTrue);
      expect(walletManager.seq, equals(41));
    });

    test('Scenario P: AFTER-ROUND REWARD UPDATE - Winning reward updates displayed balance immediately after round and reconciles', () {
      walletManager.updateFromStream(streamDiamonds: 1000, streamSeq: 50);
      walletManager.enterBettingPhase();

      // Bet 100 on winning sector
      const betTxnId = 'bet_round_200';
      walletManager.addPendingDebit(txnId: betTxnId, amount: 100, roundId: '200');
      expect(walletManager.displayedBalance, equals(900));

      walletManager.reconcileBetSuccess(
        txnId: betTxnId,
        serverBalance: 900,
        serverSeq: 51,
        roundId: '200',
      );
      expect(walletManager.displayedBalance, equals(900));
      expect(walletManager.confirmedBalance, equals(900));

      // 1. Betting closes (30s) -> spinning phase
      walletManager.exitBettingPhase();

      // 2. Wheel lands at 34s on winning sector -> reward 500
      const winTxnId = 'spin_win_200';
      walletManager.recordPendingCredit(
        txnId: winTxnId,
        amount: 500,
        roundId: '200',
      );

      // Displayed balance MUST immediately update to 1400 right after the round!
      expect(walletManager.displayedBalance, equals(1400));
      expect(walletManager.pendingCredits[winTxnId], equals(500));

      // 3. Server settlement returns at 36s
      walletManager.reconcileSettlement(
        txnId: winTxnId,
        serverBalance: 1400,
        serverSeq: 52,
        prize: 500,
        roundId: '200',
        userHadAcceptedBet: true,
      );

      // Confirmed balance is 1400, pending credit is cleared, displayed balance is 1400
      expect(walletManager.confirmedBalance, equals(1400));
      expect(walletManager.displayedBalance, equals(1400));
      expect(walletManager.pendingCredits.containsKey(winTxnId), isFalse);
      expect(walletManager.seq, equals(52));

      // 4. Round rolls over at 40s -> new round betting phase starts with full 1400
      walletManager.onRoundStart();
      expect(walletManager.isBettingPhase, isTrue);
      expect(walletManager.displayedBalance, equals(1400));
      expect(walletManager.bettingPhaseCeiling, equals(1400));
    });

    group('Critical Bug Fix: Loss Deduction & Accurate Balance Updates', () {
      test('LOSS: Deducts bet amount and NEVER reverts balance even if isPastRound is true', () {
        // Initial balance: 10,000 diamonds
        walletManager.updateFromStream(streamDiamonds: 10000, streamSeq: 1);
        walletManager.enterBettingPhase();
        expect(walletManager.displayedBalance, equals(10000));

        // User places a 2,000 diamond bet in Round 500
        const betTxnId = 'bet_round_500';
        walletManager.addPendingDebit(txnId: betTxnId, amount: 2000, roundId: '500');
        expect(walletManager.displayedBalance, equals(8000), reason: 'Pending debit immediately reduces displayed balance');

        // Backend accepts bet: confirms 8000 balance
        walletManager.reconcileBetSuccess(
          txnId: betTxnId,
          serverBalance: 8000,
          serverSeq: 2,
          roundId: '500',
        );
        expect(walletManager.confirmedBalance, equals(8000));
        expect(walletManager.displayedBalance, equals(8000));

        // Betting closes, spin ends with LOSS (prize: 0)
        walletManager.exitBettingPhase();

        // Settlement arrives after round boundary (isPastRound = true)
        const settleTxnId = 'spin_win_500';
        walletManager.reconcileSettlement(
          txnId: settleTxnId,
          serverBalance: 8000, // Authoritative server balance reflects the 2000 loss
          serverSeq: 3,
          prize: 0,
          roundId: '500',
          userHadAcceptedBet: true,
          isPastRound: true, // Crucial: past round settlement must NOT reset to pre-bet 10000!
        );

        // Verification: Balance MUST remain 8,000. It must NOT pop back to 10,000!
        expect(walletManager.confirmedBalance, equals(8000));
        expect(walletManager.displayedBalance, equals(8000));
        expect(walletManager.pendingDebits.isEmpty, isTrue);
        expect(walletManager.pendingCredits.isEmpty, isTrue);
      });

      test('WIN: Increases balance by exact winning amount and matches serverBalance', () {
        // Initial balance: 5,000 diamonds
        walletManager.updateFromStream(streamDiamonds: 5000, streamSeq: 10);
        walletManager.enterBettingPhase();

        // User bets 1,000 diamonds on Carrot (5x multiplier)
        const betTxn = 'bet_round_600';
        walletManager.addPendingDebit(txnId: betTxn, amount: 1000, roundId: '600');
        expect(walletManager.displayedBalance, equals(4000));

        walletManager.reconcileBetSuccess(
          txnId: betTxn,
          serverBalance: 4000,
          serverSeq: 11,
          roundId: '600',
        );
        expect(walletManager.confirmedBalance, equals(4000));

        walletManager.exitBettingPhase();

        // Server settles win: prize 5,000 -> final balance 9,000
        const winTxn = 'spin_win_600';
        walletManager.reconcileSettlement(
          txnId: winTxn,
          serverBalance: 9000,
          serverSeq: 12,
          prize: 5000,
          roundId: '600',
          userHadAcceptedBet: true,
          isPastRound: false,
        );

        expect(walletManager.confirmedBalance, equals(9000));
        expect(walletManager.displayedBalance, equals(9000));
      });

      test('CONSECUTIVE ROUNDS: Round 1 loss settled in Round 2 preserves Round 2 pending debits', () {
        // Start Round 1 with 20,000
        walletManager.updateFromStream(streamDiamonds: 20000, streamSeq: 20);
        walletManager.enterBettingPhase();

        // Round 1 Bet: 5,000
        walletManager.addPendingDebit(txnId: 'bet_r1', amount: 5000, roundId: 'round_1');
        walletManager.reconcileBetSuccess(
          txnId: 'bet_r1',
          serverBalance: 15000,
          serverSeq: 21,
          roundId: 'round_1',
        );
        expect(walletManager.displayedBalance, equals(15000));

        walletManager.exitBettingPhase();

        // Round 2 Starts before Round 1 settles
        walletManager.enterBettingPhase();

        // User places a 3,000 bet for Round 2
        walletManager.addPendingDebit(txnId: 'bet_r2', amount: 3000, roundId: 'round_2');
        expect(walletManager.displayedBalance, equals(12000)); // 15000 - 3000

        // Now Round 1 settles as a LOSS (prize = 0, serverBalance = 15000, isPastRound = true)
        walletManager.reconcileSettlement(
          txnId: 'spin_win_round_1',
          serverBalance: 15000,
          serverSeq: 22,
          prize: 0,
          roundId: 'round_1',
          userHadAcceptedBet: true,
          isPastRound: true,
        );

        // Round 1 loss is permanently settled, and Round 2 pending bet of 3000 is STILL deducted!
        expect(walletManager.confirmedBalance, equals(15000));
        expect(walletManager.displayedBalance, equals(12000), reason: 'Round 2 pending debit must remain active');
        expect(walletManager.pendingDebits.containsKey('bet_r2'), isTrue);
      });

      test('SPECTATOR: Zero-bet round settlement NEVER modifies wallet balance', () {
        walletManager.updateFromStream(streamDiamonds: 50000, streamSeq: 30);
        expect(walletManager.displayedBalance, equals(50000));

        // Spectator settlement received
        walletManager.reconcileSettlement(
          txnId: 'spin_win_round_spectator',
          serverBalance: 999999, // Rogue or mismatched server balance payload
          serverSeq: 31,
          prize: 100000,
          roundId: 'round_spectator',
          userHadAcceptedBet: false, // Spectator!
        );

        // Balance remains completely unchanged
        expect(walletManager.confirmedBalance, equals(50000));
        expect(walletManager.displayedBalance, equals(50000));
      });

      test('PRODUCTION FLOW: Every round deducts bet instantly and credits win immediately on result reveal', () {
        // Initial setup: Player has 1,000,000 diamonds
        walletManager.updateFromStream(streamDiamonds: 1000000, streamSeq: 100);
        expect(walletManager.displayedBalance, equals(1000000));

        // ================= ROUND 1 =================
        walletManager.onRoundStart();
        expect(walletManager.isBettingPhase, isTrue);

        // 1. Bet placed -> deducts instantly
        walletManager.addPendingDebit(txnId: 'bet_r1', amount: 100000, roundId: 'r1');
        expect(walletManager.displayedBalance, equals(900000), reason: 'Bet deducted instantly');

        // Server confirms bet deduction
        walletManager.reconcileBetSuccess(txnId: 'bet_r1', serverBalance: 900000, serverSeq: 101, roundId: 'r1');
        expect(walletManager.displayedBalance, equals(900000));
        expect(walletManager.confirmedBalance, equals(900000));

        // 2. Betting closes at 30s -> spinning
        walletManager.exitBettingPhase();
        expect(walletManager.isBettingPhase, isFalse);

        // 3. Wheel lands at 35s -> WIN 500,000 credited IMMEDIATELY on round result reveal
        walletManager.recordPendingCredit(txnId: 'spin_win_r1', amount: 500000, roundId: 'r1');
        expect(walletManager.displayedBalance, equals(1400000), reason: 'Winning amount added immediately after round result');

        // 4. Server settles round
        walletManager.reconcileSettlement(
          txnId: 'spin_win_r1',
          serverBalance: 1400000,
          serverSeq: 102,
          prize: 500000,
          roundId: 'r1',
          userHadAcceptedBet: true,
        );
        expect(walletManager.confirmedBalance, equals(1400000));
        expect(walletManager.displayedBalance, equals(1400000));

        // ================= ROUND 2 =================
        // Round 2 starts -> ceiling begins at full 1,400,000
        walletManager.onRoundStart();
        expect(walletManager.isBettingPhase, isTrue);
        expect(walletManager.displayedBalance, equals(1400000));

        // 1. Round 2 Bet placed -> deducts instantly from new 1,400,000 balance
        walletManager.addPendingDebit(txnId: 'bet_r2', amount: 200000, roundId: 'r2');
        expect(walletManager.displayedBalance, equals(1200000), reason: 'Round 2 bet deducted instantly');

        walletManager.reconcileBetSuccess(txnId: 'bet_r2', serverBalance: 1200000, serverSeq: 103, roundId: 'r2');
        expect(walletManager.displayedBalance, equals(1200000));

        // 2. Round 2 Betting closes -> spinning
        walletManager.exitBettingPhase();

        // 3. Round 2 Wheel lands -> WIN 1,000,000 credited IMMEDIATELY
        walletManager.recordPendingCredit(txnId: 'spin_win_r2', amount: 1000000, roundId: 'r2');
        expect(walletManager.displayedBalance, equals(2200000), reason: 'Round 2 win credited immediately on result');

        // 4. Round 2 Settles
        walletManager.reconcileSettlement(
          txnId: 'spin_win_r2',
          serverBalance: 2200000,
          serverSeq: 104,
          prize: 1000000,
          roundId: 'r2',
          userHadAcceptedBet: true,
        );
        expect(walletManager.confirmedBalance, equals(2200000));
        expect(walletManager.displayedBalance, equals(2200000));

        // ================= ROUND 3 =================
        walletManager.onRoundStart();
        expect(walletManager.displayedBalance, equals(2200000));

        // Round 3 Bet placed (loss)
        walletManager.addPendingDebit(txnId: 'bet_r3', amount: 50000, roundId: 'r3');
        expect(walletManager.displayedBalance, equals(2150000));

        walletManager.reconcileBetSuccess(txnId: 'bet_r3', serverBalance: 2150000, serverSeq: 105, roundId: 'r3');
        walletManager.exitBettingPhase();

        // Round 3 Loss: prize = 0, no credit added
        walletManager.reconcileSettlement(
          txnId: 'spin_win_r3',
          serverBalance: 2150000,
          serverSeq: 106,
          prize: 0,
          roundId: 'r3',
          userHadAcceptedBet: true,
        );
        expect(walletManager.displayedBalance, equals(2150000));
        expect(walletManager.confirmedBalance, equals(2150000));

        // Round 4 starts with exact 2,150,000
        walletManager.onRoundStart();
        expect(walletManager.displayedBalance, equals(2150000));
      });
    });
  });

  group('LIVE-DEFECT REGRESSIONS (2026-10-05 field test, +250k phantom)', () {
    late AuthoritativeWalletManager walletManager;

    setUp(() {
      walletManager = AuthoritativeWalletManager();
    });

    test('B1: stream carrying settle txnId clears the matching pending credit', () {
      walletManager.updateFromStream(streamDiamonds: 800000, streamSeq: 41, lastTxnId: 'init');
      walletManager.addPendingDebit(txnId: 'bet_44778761', amount: 30000);
      walletManager.reconcileBetSuccess(
          txnId: 'bet_44778761', serverBalance: 770000, serverSeq: 42);
      expect(walletManager.displayedBalance, equals(770000));

      // Wheel stops: optimistic win credit +150000
      walletManager.recordPendingCredit(txnId: 'spin_win_44778761', amount: 150000, roundId: '44778761');
      expect(walletManager.displayedBalance, equals(920000));

      // Server settles: doc = 920000, lastTxnId = spin_win_44778761
      final applied = walletManager.updateFromStream(
        streamDiamonds: 920000,
        streamSeq: 84,
        lastTxnId: 'spin_win_44778761',
      );
      expect(applied, isTrue);
      // Credit must be cleared - otherwise the win displays TWICE (920000 + 150000)
      expect(walletManager.displayedBalance, equals(920000));
      expect(walletManager.confirmedBalance, equals(920000));
    });

    test('B2: duplicate settle txnId (pre-registered by stream) still applies a differing authoritative balance', () {
      walletManager.updateFromStream(streamDiamonds: 557703, streamSeq: 80, lastTxnId: 'init');

      // Betting closes before the settle snapshot arrives (matches live log order)
      walletManager.exitBettingPhase();

      // Stream delivers settle txnId first - pre-registers it in processed ids
      walletManager.updateFromStream(
        streamDiamonds: 572703,
        streamSeq: 83,
        lastTxnId: 'spin_win_44778761',
      );
      expect(walletManager.displayedBalance, equals(572703));

      // Authoritative settle RESPONSE arrives with the true server balance
      walletManager.reconcileSettlement(
        txnId: 'spin_win_44778761',
        serverBalance: 677703, // differs from the (transient/stale) stream value
        serverSeq: 84,
        prize: 150000,
        roundId: '44778761',
        userHadAcceptedBet: true,
      );
      // Previously dropped as duplicate -> client stuck on the wrong balance
      expect(walletManager.confirmedBalance, equals(677703));
      expect(walletManager.displayedBalance, equals(677703));

      // And an exact repeat stays idempotent
      walletManager.reconcileSettlement(
        txnId: 'spin_win_44778761',
        serverBalance: 677703,
        serverSeq: 84,
        prize: 150000,
        roundId: '44778761',
        userHadAcceptedBet: true,
      );
      expect(walletManager.displayedBalance, equals(677703));
    });

    test('B3: dropStalePendingCredits keeps the in-flight round, sweeps rounds 2+ behind', () {
      walletManager.updateFromStream(streamDiamonds: 557703, streamSeq: 80, lastTxnId: 'init');
      walletManager.recordPendingCredit(txnId: 'spin_win_44778760', amount: 100000, roundId: '44778760');
      walletManager.recordPendingCredit(txnId: 'spin_win_44778761', amount: 150000, roundId: '44778761');
      expect(walletManager.displayedBalance, equals(807703));

      // Rollover into 44778761: round 44778760's settle is STILL IN FLIGHT
      // (lands up to ~10s after rollover) - the credit must survive, and with
      // it the correct balance/ceiling for the whole betting window.
      walletManager.dropStalePendingCredits('44778761');
      expect(walletManager.displayedBalance, equals(807703));

      // Next rollover: 44778760 never reconciled -> swept; 44778761 still recent.
      walletManager.recordPendingCredit(txnId: 'spin_win_44778762', amount: 50000, roundId: '44778762');
      walletManager.dropStalePendingCredits('44778762');
      expect(walletManager.displayedBalance, equals(757703));

      walletManager.dropStalePendingCredits('44778763');
      expect(walletManager.displayedBalance, equals(607703));

      walletManager.dropStalePendingCredits('44778764');
      expect(walletManager.displayedBalance, equals(557703));
    });
  });
}
