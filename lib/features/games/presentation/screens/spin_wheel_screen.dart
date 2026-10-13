import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/core/services/game_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/wakelock_service.dart';
import 'package:hello_chat/core/services/game_recovery_service.dart';
import 'package:hello_chat/core/services/network_connectivity_service.dart';

/// The SINGLE AUTHORITATIVE SOURCE OF TRUTH for wallet balance in the Spin Wheel game.
/// Immutable Wallet State Model
class WalletState {
  final int confirmedBalance;
  final Map<String, int> pendingDebits; // txnId -> debitAmount
  final Map<String, int> pendingCredits; // txnId -> creditAmount (e.g. winning reward for current/settling round)
  final int seq;
  final bool isSyncing;

  const WalletState({
    this.confirmedBalance = 0,
    this.pendingDebits = const {},
    this.pendingCredits = const {},
    this.seq = 0,
    this.isSyncing = false,
  });

  int get totalPendingDebits =>
      pendingDebits.values.fold(0, (sum, val) => sum + val);

  int get totalPendingCredits =>
      pendingCredits.values.fold(0, (sum, val) => sum + val);

  int get displayedBalance {
    final balance = confirmedBalance - totalPendingDebits + totalPendingCredits;
    return balance > 0 ? balance : 0;
  }

  WalletState copyWith({
    int? confirmedBalance,
    Map<String, int>? pendingDebits,
    Map<String, int>? pendingCredits,
    int? seq,
    bool? isSyncing,
  }) {
    return WalletState(
      confirmedBalance: confirmedBalance ?? this.confirmedBalance,
      pendingDebits: pendingDebits != null
          ? Map.unmodifiable(pendingDebits)
          : this.pendingDebits,
      pendingCredits: pendingCredits != null
          ? Map.unmodifiable(pendingCredits)
          : this.pendingCredits,
      seq: seq ?? this.seq,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Single Source of Truth Wallet Manager
/// Enforces monotonic sequence numbers (`seq`), tracks pending transactions
/// by unique client-generated `txnId`, rejects stale events strictly by sequence,
/// enforces transaction idempotency, and strictly prevents balance increases without authoritative transactions.
class AuthoritativeWalletManager {
  WalletState _state = const WalletState();
  bool _hasInitialBalance = false;
  bool _isBettingPhase = true;
  int? _bettingPhaseCeiling;
  int? _roundInitialBalance;
  final Set<String> _processedTxnIds = <String>{};

  WalletState get state => _state;
  int get confirmedBalance => _state.confirmedBalance;
  int get seq => _state.seq;
  int get walletVersion => _state.seq;
  bool get hasInitialBalance => _hasInitialBalance;
  bool get isBettingPhase => _isBettingPhase;
  int? get bettingPhaseCeiling => _bettingPhaseCeiling;
  int? get roundInitialBalance => _roundInitialBalance;
  int get deferredCredits => 0; // Deprecated scalar accumulator eliminated
  Map<String, int> get pendingDebits => _state.pendingDebits;
  Map<String, int> get pendingCredits => _state.pendingCredits;
  Set<String> get processedTxnIds => Set.unmodifiable(_processedTxnIds);

  /// Pure derivation: confirmed balance minus pending bet deductions,
  /// strictly bounded by the monotonic non-increasing betting ceiling during the betting phase.
  /// INVARIANT: In the betting phase, diamonds can NEVER increase in any way!
  int get displayedBalance {
    final raw = _state.displayedBalance;
    if (_isBettingPhase) {
      final ceiling = _bettingPhaseCeiling ?? raw;
      return math.min(raw, ceiling);
    }
    return raw;
  }

  void enterBettingPhase() {
    _isBettingPhase = true;
    _roundInitialBalance = _state.displayedBalance;
    _bettingPhaseCeiling = _state.displayedBalance;
    logWalletMutation(
      source: 'phase_transition',
      oldBalance: displayedBalance,
      newBalance: displayedBalance,
      transactionId: 'enter_betting',
      walletSeq: _state.seq,
      eventName: 'enter_betting_phase',
      roundId: 'current',
    );
  }

  void exitBettingPhase() {
    final oldBal = displayedBalance;
    _isBettingPhase = false;
    _bettingPhaseCeiling = null;
    _roundInitialBalance = null;
    logWalletMutation(
      source: 'phase_transition',
      oldBalance: oldBal,
      newBalance: displayedBalance,
      transactionId: 'exit_betting',
      walletSeq: _state.seq,
      eventName: 'exit_betting_phase',
      roundId: 'current',
    );
  }

  /// Backward-compatible alias for exiting betting phase.
  /// Note: Loose scalar deferredCredits has been architecturally eliminated.
  void exitBettingPhaseAndApplyDeferredCredits() {
    exitBettingPhase();
  }

  /// Continually synchronizes wallet manager phase with cycle seconds.
  /// 0s-29s = betting phase (zero increase permitted),
  /// 30s-39s = spinning / results phase (ceiling lifted).
  void syncPhaseWithCycle(int secondsIntoCycle) {
    if (secondsIntoCycle < 30) {
      if (!_isBettingPhase) {
        enterBettingPhase();
      }
    } else {
      if (_isBettingPhase) {
        exitBettingPhase();
      }
    }
  }

  /// Required structured debugging logger for every Current Amount mutation.
  void logWalletMutation({
    required String source,
    required int oldBalance,
    required int newBalance,
    required String transactionId,
    String? roundId,
    required int walletSeq,
    bool fromCache = false,
    required String eventName,
    int? timestamp,
  }) {
    final delta = newBalance - oldBalance;
    final direction = delta > 0 ? 'credit' : (delta < 0 ? 'debit' : 'none');
    final effectiveTime = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final effectiveRoundId = (roundId != null && roundId.isNotEmpty) ? roundId : 'N/A';

    final lines = StackTrace.current.toString().split('\n');
    final relevantFrames = lines
        .skip(1)
        .take(3)
        .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .join(' -> ');

    debugPrint('''
[WALLET_MUTATION]
source: $source
oldBalance: $oldBalance
newBalance: $newBalance
delta: $delta
direction: $direction
transactionId: $transactionId
roundId: $effectiveRoundId
walletSeq: $walletSeq
fromCache: $fromCache
eventName: $eventName
timestamp: $effectiveTime
stackTrace: $relevantFrames
''');
  }

  /// Backward-compatible logging bridge.
  void logWalletUpdate({
    required String source,
    required int oldBalance,
    required int newBalance,
    required int seq,
    required String txnId,
    bool fromCache = false,
    int? timestamp,
    required String reason,
  }) {
    logWalletMutation(
      source: source,
      oldBalance: oldBalance,
      newBalance: newBalance,
      transactionId: txnId,
      walletSeq: seq,
      fromCache: fromCache,
      eventName: reason,
      timestamp: timestamp,
    );
  }

  /// Initial load or authoritative update from Firestore stream.
  /// Strictly enforces monotonic sequence numbers: snapshots where streamSeq <= lastAppliedSeq are DROPPED.
  bool updateFromStream({
    required int streamDiamonds,
    required int streamSeq,
    String? lastTxnId,
    bool fromCache = false,
    int? timestamp,
  }) {
    final oldBalance = displayedBalance;
    final currentSeq = _state.seq;

    // 1. First initialization: Accept initial authoritative balance
    if (!_hasInitialBalance) {
      _hasInitialBalance = true;
      _state = _state.copyWith(
        confirmedBalance: streamDiamonds,
        seq: streamSeq,
        isSyncing: false,
      );
      _bettingPhaseCeiling = streamDiamonds;
      _roundInitialBalance = streamDiamonds;
      if (lastTxnId != null) _processedTxnIds.add(lastTxnId);

      logWalletMutation(
        source: 'wallet_stream (initial)',
        oldBalance: oldBalance,
        newBalance: displayedBalance,
        transactionId: lastTxnId ?? 'init_stream',
        walletSeq: streamSeq,
        fromCache: fromCache,
        eventName: 'initial_wallet_load',
        timestamp: timestamp,
      );
      return true;
    }

    // 2. Sequence Gate.
    // Genuinely OLDER sequence -> definitively stale, drop it.
    if (streamSeq < currentSeq) {
      logWalletMutation(
        source: 'wallet_stream (rejected_stale_seq)',
        oldBalance: oldBalance,
        newBalance: displayedBalance,
        transactionId: lastTxnId ?? 'stale_seq',
        walletSeq: streamSeq,
        fromCache: fromCache,
        eventName: 'rejected_stale_seq',
        timestamp: timestamp,
      );
      return false;
    }

    // SAME sequence but the balance actually moved -> this is a real balance change
    // from a money path that does not bump `users.seq` (gift sends, purchases, and
    // any other writer touching diamondBalance directly). Rejecting these froze the
    // game's balance until the next seq-bumping settlement, which is what made the
    // Current Amount look stuck from the second round onwards. Accept the change;
    // the betting-phase ceiling below still forbids the display from going UP
    // mid-betting, so anti-regression is preserved.
    if (streamSeq == currentSeq && streamDiamonds == _state.confirmedBalance) {
      logWalletMutation(
        source: 'wallet_stream (no_change)',
        oldBalance: oldBalance,
        newBalance: displayedBalance,
        transactionId: lastTxnId ?? 'no_change',
        walletSeq: streamSeq,
        fromCache: fromCache,
        eventName: 'skipped_no_balance_change',
        timestamp: timestamp,
      );
      return false;
    }

    // 3. Authoritative Newer Sequence:
    // Advance sequence and update confirmed balance.
    if (lastTxnId != null) {
      _processedTxnIds.add(lastTxnId);
    }
    final updatedPending = Map<String, int>.from(_state.pendingDebits);
    if (lastTxnId != null && updatedPending.containsKey(lastTxnId)) {
      updatedPending.remove(lastTxnId);
    }
    // Mirror for credits: when the authoritative snapshot carries the settle
    // txnId (lastTxnId = spin_win_<roundId>), the winning amount is already
    // inside streamDiamonds - the pending credit must be cleared or the win
    // is displayed TWICE (observed +150k phantom after live round settle).
    final updatedCredits = Map<String, int>.from(_state.pendingCredits);
    if (lastTxnId != null && updatedCredits.containsKey(lastTxnId)) {
      updatedCredits.remove(lastTxnId);
    }

    _state = _state.copyWith(
      confirmedBalance: streamDiamonds,
      seq: streamSeq,
      pendingDebits: updatedPending,
      pendingCredits: updatedCredits,
      isSyncing: updatedPending.isNotEmpty,
    );

    // During betting phase, ceiling keeps displayed balance clamped to non-increasing values
    if (_isBettingPhase) {
      final newRaw = _state.displayedBalance;
      _bettingPhaseCeiling = math.min(_bettingPhaseCeiling ?? newRaw, newRaw);
    }

    logWalletMutation(
      source: 'wallet_stream (applied_newer_seq)',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: lastTxnId ?? 'stream_update',
      walletSeq: streamSeq,
      fromCache: fromCache,
      eventName: 'authoritative_stream_update',
      timestamp: timestamp,
    );
    return true;
  }

  /// Registers a pending bet deduction by unique client txnId for instant UI feedback.
  void addPendingDebit({
    required String txnId,
    required int amount,
    String? roundId,
  }) {
    if (amount <= 0) return;
    final oldBalance = displayedBalance;
    final updatedPending = Map<String, int>.from(_state.pendingDebits);
    updatedPending[txnId] = (updatedPending[txnId] ?? 0) + amount;

    _state = _state.copyWith(
      pendingDebits: updatedPending,
      isSyncing: true,
    );

    // Monotonic Non-Increasing Ratchet: Ceiling moves down with every bet tap
    if (_isBettingPhase) {
      final newRaw = _state.displayedBalance;
      _bettingPhaseCeiling = math.min(_bettingPhaseCeiling ?? newRaw, newRaw);
    }

    logWalletMutation(
      source: 'client_optimistic_bet',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: _state.seq,
      eventName: 'pending_bet_registered',
    );
  }

  /// Registers a pending winning reward credit by unique round/txnId so that right after
  /// the round completes, the user immediately sees the reward amount added to their balance!
  void recordPendingCredit({
    required String txnId,
    required int amount,
    String? roundId,
  }) {
    if (amount <= 0) return;
    final oldBalance = displayedBalance;
    final updatedCredits = Map<String, int>.from(_state.pendingCredits);
    updatedCredits[txnId] = amount;

    _state = _state.copyWith(
      pendingCredits: updatedCredits,
    );

    // Ensure ceiling accommodates the optimistic winning credit
    final newRaw = _state.displayedBalance;
    if (_bettingPhaseCeiling != null && newRaw > _bettingPhaseCeiling!) {
      _bettingPhaseCeiling = newRaw;
    }

    logWalletMutation(
      source: 'client_optimistic_win_credit',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: _state.seq,
      eventName: 'round_win_reward_pending_credited: $amount',
    );
  }

  /// Reconciles confirmed bet transaction using txnId and server sequence.
  void reconcileBetSuccess({
    required String txnId,
    required int serverBalance,
    required int serverSeq,
    String? roundId,
    int? timestamp,
    int? remainingPendingAmount,
  }) {
    final oldBalance = displayedBalance;
    final currentSeq = _state.seq;
    final updatedPending = Map<String, int>.from(_state.pendingDebits);

    if (remainingPendingAmount != null) {
      if (remainingPendingAmount > 0) {
        updatedPending[txnId] = remainingPendingAmount;
      } else {
        updatedPending.remove(txnId);
      }
    } else {
      updatedPending.remove(txnId);
    }

    _processedTxnIds.add(txnId);

    // Apply sequence ordering: if serverSeq > currentSeq, advance sequence
    final newSeq = serverSeq > currentSeq ? serverSeq : currentSeq;

    // During betting phase, serverBalance can never increase confirmedBalance
    final safeBalance = (_isBettingPhase && serverBalance > _state.confirmedBalance)
        ? _state.confirmedBalance
        : serverBalance;

    _state = _state.copyWith(
      confirmedBalance: safeBalance,
      seq: newSeq,
      pendingDebits: updatedPending,
      isSyncing: updatedPending.isNotEmpty,
    );

    _hasInitialBalance = true;

    if (_isBettingPhase) {
      final newRaw = _state.displayedBalance;
      _bettingPhaseCeiling = math.min(_bettingPhaseCeiling ?? newRaw, newRaw);
    }

    logWalletMutation(
      source: 'backend_bet_confirm',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: newSeq,
      timestamp: timestamp,
      eventName: 'authoritative_bet_confirmed',
    );
  }

  /// Reconciles failed/rejected bet transaction: rolls back only this pending txnId.
  void reconcileBetFailure({
    required String txnId,
    required String errorMessage,
    String? roundId,
  }) {
    final oldBalance = displayedBalance;
    final updatedPending = Map<String, int>.from(_state.pendingDebits);
    updatedPending.remove(txnId);

    _state = _state.copyWith(
      pendingDebits: updatedPending,
      isSyncing: updatedPending.isNotEmpty,
    );

    if (_isBettingPhase) {
      final currentRaw = _state.displayedBalance;
      final maxAllowed = _roundInitialBalance ?? currentRaw;
      _bettingPhaseCeiling = math.min(currentRaw, maxAllowed);
    }

    logWalletMutation(
      source: 'backend_bet_rollback',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: _state.seq,
      eventName: 'bet_failure_rollback: $errorMessage',
    );
  }

  /// Rolls back ALL pending + confirmed bets for a round after an authoritative server
  /// revert (revertSpinWheelBets). Clears the staged pending debit and restores the
  /// betting-phase ceiling to the round's initial balance so the refunded diamonds are
  /// spendable again. The wallet stream reconciles the confirmed balance once the refund
  /// transaction lands (higher seq, refunded balance).
  void reconcileBetRevert({
    required String txnId,
    String? roundId,
  }) {
    final oldBalance = displayedBalance;
    final updatedPending = Map<String, int>.from(_state.pendingDebits);
    updatedPending.remove(txnId);
    if (roundId != null) updatedPending.remove('spin_bet_$roundId');

    _state = _state.copyWith(
      pendingDebits: updatedPending,
      isSyncing: updatedPending.isNotEmpty,
    );

    if (_isBettingPhase) {
      _bettingPhaseCeiling = _roundInitialBalance ?? displayedBalance;
      _roundInitialBalance = _bettingPhaseCeiling;
    }

    logWalletMutation(
      source: 'backend_bet_revert',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: _state.seq,
      eventName: 'bets_reverted_refund_pending',
    );
  }

  /// Reconciles round settlement (WIN / LOSS).
  /// Enforces:
  /// 1. NO BET = NO CREDIT (if userHadAcceptedBet is false, prize is strictly 0 and balance does not change).
  /// 2. Idempotency: duplicate txnIds are dropped immediately.
  /// 3. Monotonic sequence advancement.
  void reconcileSettlement({
    required String txnId,
    required int serverBalance,
    required int serverSeq,
    required int prize,
    String? roundId,
    bool userHadAcceptedBet = true,
    int? timestamp,
    bool isPastRound = false,
  }) {
    final effectiveRoundId = (roundId != null && roundId.isNotEmpty) ? roundId : txnId;
    final oldBalance = displayedBalance;
    final currentSeq = _state.seq;

    // INVARIANT 1: Zero Bet = Zero Reward (Pure Spectator)
    if (!userHadAcceptedBet) {
      final updatedCredits = Map<String, int>.from(_state.pendingCredits);
      updatedCredits.remove(txnId);
      if (roundId != null) updatedCredits.remove('spin_win_$roundId');
      _state = _state.copyWith(pendingCredits: updatedCredits);

      if (_processedTxnIds.contains(txnId)) return;
      _processedTxnIds.add(txnId);

      logWalletMutation(
        source: 'backend_settlement_nobet',
        oldBalance: oldBalance,
        newBalance: displayedBalance,
        transactionId: txnId,
        roundId: roundId,
        walletSeq: _state.seq,
        timestamp: timestamp,
        eventName: 'zero_bet_settlement_rejected_credit',
      );
      return;
    }

    // INVARIANT 2: Idempotency
    if (_processedTxnIds.contains(txnId)) {
      // The wallet stream pre-registers lastTxnId in _processedTxnIds, so the
      // authoritative settle RESPONSE often arrives "already processed". The
      // server balance is absolute truth - if it differs from what the stream
      // delivered (transient/stale snapshot), apply it instead of dropping it.
      // Setting an absolute balance twice is a no-op, so this stays idempotent.
      if (serverBalance != _state.confirmedBalance) {
        _state = _state.copyWith(confirmedBalance: serverBalance);
        final dupRaw = _state.displayedBalance;
        if (_isBettingPhase && (_bettingPhaseCeiling == null || dupRaw > _bettingPhaseCeiling!)) {
          _bettingPhaseCeiling = dupRaw;
        }
        logWalletMutation(
          source: 'backend_settlement_duplicate_refresh',
          oldBalance: oldBalance,
          newBalance: displayedBalance,
          transactionId: txnId,
          roundId: roundId,
          walletSeq: _state.seq,
          timestamp: timestamp,
          eventName: 'duplicate_settle_applied_authoritative_balance',
        );
        return;
      }
      logWalletMutation(
        source: 'backend_settlement_duplicate',
        oldBalance: oldBalance,
        newBalance: displayedBalance,
        transactionId: txnId,
        roundId: roundId,
        walletSeq: _state.seq,
        timestamp: timestamp,
        eventName: 'duplicate_settlement_dropped',
      );
      return;
    }
    _processedTxnIds.add(txnId);

    final updatedPending = Map<String, int>.from(_state.pendingDebits);
    updatedPending.remove(txnId);
    if (roundId != null) {
      updatedPending.remove('bet_$roundId');
      updatedPending.remove('spin_bet_$roundId');
    }

    final updatedCredits = Map<String, int>.from(_state.pendingCredits);
    updatedCredits.remove(txnId);
    if (roundId != null) updatedCredits.remove('spin_win_$roundId');

    final newSeq = serverSeq > currentSeq ? serverSeq : currentSeq;
    // Authoritative wallet principle: serverBalance from Cloud Functions is the single source of truth.
    // Never discard serverBalance on past-round settlement, as losses must permanently debit the wallet.
    final targetBalance = serverBalance;

    _state = _state.copyWith(
      confirmedBalance: targetBalance,
      seq: newSeq,
      pendingDebits: updatedPending,
      pendingCredits: updatedCredits,
      isSyncing: updatedPending.isNotEmpty,
    );

    // A prize credit is real money, so the betting-phase ceiling must be able to RISE.
    // It used to be pinned one-way ("intentionally NOT done"), which meant a win landing
    // in the NEXT round's betting window stayed unspendable: displayedBalance is clamped
    // to min(raw, ceiling), every bet was refused, and only re-entering the room - which
    // rebuilds the wallet from Firestore with no clamp - restored betting. Optimistic
    // pending debits must still never let the balance dip mid-betting.
    // Authoritative settlement prize or balance update: adjust ceiling
    final newRaw = _state.displayedBalance;
    if (prize > 0 && _isBettingPhase) {
      _bettingPhaseCeiling = _state.displayedBalance;
    } else if (_isBettingPhase) {
      if (_bettingPhaseCeiling == null || newRaw > _bettingPhaseCeiling!) {
        _bettingPhaseCeiling = newRaw;
      }
    }

    logWalletMutation(
      source: prize > 0
          ? (isPastRound ? 'backend_settlement_win (past_round)' : 'backend_settlement_win')
          : 'backend_settlement_loss',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: txnId,
      roundId: roundId,
      walletSeq: newSeq,
      timestamp: timestamp,
      eventName: prize > 0 ? 'win_prize_credited: $prize' : 'loss_settled_confirmed: balance=$targetBalance',
    );
  }

  /// Legacy helper for backward compatibility
  void confirmBet({
    required int serverBalance,
    required String roundId,
    required int requestSeq,
    required int timestamp,
  }) {
    reconcileBetSuccess(
      txnId: 'spin_bet_$roundId',
      serverBalance: serverBalance,
      serverSeq: requestSeq,
      roundId: roundId,
      timestamp: timestamp,
    );
  }

  /// Legacy helper for backward compatibility
  void confirmSettlement({
    required int serverBalance,
    required int prize,
    required String roundId,
    required int requestSeq,
    required int timestamp,
    bool userHadAcceptedBet = true,
  }) {
    reconcileSettlement(
      txnId: 'spin_win_$roundId',
      serverBalance: serverBalance,
      serverSeq: requestSeq,
      prize: prize,
      roundId: roundId,
      userHadAcceptedBet: userHadAcceptedBet,
      timestamp: timestamp,
    );
  }

  /// Reset round-scoped tracking upon entering a new round.
  ///
  /// Pending debits are deliberately NOT wiped here. An entry still present at the
  /// round boundary is BY DEFINITION unconfirmed - `reconcileBetSuccess` and
  /// `updateFromStream` remove entries as soon as the server confirms them. Clearing
  /// the map unconditionally therefore silently refunded any wager whose confirmation
  /// had not landed yet (slow or lost callable response), leaving the UI showing more
  /// diamonds than the server had actually charged until the next authoritative
  /// event arrived. A genuinely lost response is reconciled by the recovery pass and
  /// by round settlement, which run the authoritative balance back through here.
  void onRoundStart() {
    enterBettingPhase();
  }

  /// Safety net: drops win credits for rounds TWO or more rounds behind
  /// [currentRoundId]. The just-ended round is deliberately kept: its settle
  /// response lands up to ~10s AFTER rollover (observed +3s), and dropping the
  /// credit early both understates the balance and freezes
  /// enterBettingPhase's ceiling at the low value for the whole betting
  /// window. A credit still present one rollover later was never reconciled
  /// (phantom from a stale result, or lost settle response) - sweep it then.
  void dropStalePendingCredits(String currentRoundId) {
    final current = int.tryParse(currentRoundId);
    if (current == null || _state.pendingCredits.isEmpty) return;
    final stale = <String>[];
    for (final key in _state.pendingCredits.keys) {
      final m = RegExp(r'^spin_win_(\d+)$').firstMatch(key);
      if (m == null) continue;
      final creditRound = int.tryParse(m.group(1)!);
      if (creditRound != null && creditRound < current - 1) stale.add(key);
    }
    if (stale.isEmpty) return;
    final oldBalance = displayedBalance;
    final updated = Map<String, int>.from(_state.pendingCredits);
    for (final k in stale) {
      updated.remove(k);
    }
    _state = _state.copyWith(pendingCredits: updated);
    logWalletMutation(
      source: 'stale_pending_credit_sweep',
      oldBalance: oldBalance,
      newBalance: displayedBalance,
      transactionId: stale.join(','),
      roundId: currentRoundId,
      walletSeq: _state.seq,
      eventName: 'stale_pending_credits_dropped',
    );
  }

  /// Pure derivation: confirmed balance minus pending bet deductions
  int getDisplayedBalance([int extraPending = 0]) {
    final balance = _state.confirmedBalance - (_state.totalPendingDebits + extraPending) + _state.totalPendingCredits;
    final raw = balance > 0 ? balance : 0;
    if (_isBettingPhase && _bettingPhaseCeiling != null) {
      return math.min(raw, _bettingPhaseCeiling!);
    }
    return raw;
  }
}

enum SpinGameState { betting, spinning, results }

/// Drops zero/negative entries and coerces keys to strings, so a bet map can be fed
/// straight into [calculateSpinWheelPrize]. Mirrors normalizeSpinBets on the server.
Map<String, int> positiveSpinBets(Map bets) {
  final out = <String, int>{};
  bets.forEach((k, v) {
    final val = (v as num?)?.toInt() ?? 0;
    if (val > 0) out[k.toString()] = val;
  });
  return out;
}

/// Resolves the authoritative winning food for a merged history row.
/// Once the server settles a round, its committed [remoteFood] is the immutable truth;
/// session/animation data may only fill gaps on unsettled rows. This guarantees a
/// settled round can never swap its displayed winning item when the local animation
/// or session cache disagrees with Firestore.
String? resolveMergedWinningFood({
  required bool remoteSettled,
  required String remoteFood,
  required String sessionFood,
}) {
  if (remoteSettled && remoteFood.isNotEmpty) return remoteFood;
  if (sessionFood.isNotEmpty) return sessionFood;
  return remoteFood.isEmpty ? null : remoteFood;
}

/// Merges a remote history row with a session row for a given roundId.
/// Fix A: When a remote/server row exists, server-committed bets and totalBet take precedence.
/// Session values are used only as fallbacks.
Map<String, dynamic> mergeHistoryRow({
  required Map<String, dynamic> remoteRow,
  required Map<String, dynamic> sessionItem,
}) {
  final isRemoteSettled = remoteRow['settled'] == true;
  final isSessionSettled = sessionItem['settled'] == true;
  final settled = isRemoteSettled || isSessionSettled;

  final remoteFood = remoteRow['winningFood']?.toString().isNotEmpty == true
      ? remoteRow['winningFood'].toString()
      : (remoteRow['name']?.toString() ?? '');
  final sessionFood = sessionItem['winningFood']?.toString().isNotEmpty == true
      ? sessionItem['winningFood'].toString()
      : (sessionItem['name']?.toString() ?? '');
  final isRemoteAuthoritative = isRemoteSettled && remoteFood.isNotEmpty;
  final effectiveWinningFood = resolveMergedWinningFood(
        remoteSettled: isRemoteSettled,
        remoteFood: remoteFood,
        sessionFood: sessionFood,
      ) ??
      '';

  final effectiveBets = (remoteRow['bets'] is Map && (remoteRow['bets'] as Map).isNotEmpty)
      ? remoteRow['bets'] as Map
      : (sessionItem['bets'] is Map ? sessionItem['bets'] as Map : {});

  final serverPrize = (remoteRow['prize'] as num?)?.toInt() ?? (remoteRow['amount'] as num?)?.toInt() ?? 0;
  final sessionPrize = (sessionItem['prize'] as num?)?.toInt() ?? serverPrize;

  final finalPrize = isRemoteAuthoritative
      ? serverPrize
      : (effectiveBets.isNotEmpty && effectiveWinningFood.isNotEmpty
          ? calculateSpinWheelPrize(
              bets: positiveSpinBets(effectiveBets),
              winningName: effectiveWinningFood,
              multiplier: int.tryParse(
                      (sessionItem['multiplier'] ?? remoteRow['multiplier'] ?? '5')
                          .toString()
                          .replaceAll('x', '')) ??
                  5,
              roundType: sessionItem['resultType']?.toString(),
            )
          : sessionPrize);

  // Sync session item's bets and totalBet with authoritative server values
  if (remoteRow['bets'] is Map && (remoteRow['bets'] as Map).isNotEmpty) {
    sessionItem['bets'] = remoteRow['bets'];
  }
  final remoteTotalBet = (remoteRow['totalBet'] as num?)?.toInt() ?? (remoteRow['amount'] as num?)?.toInt();
  if (remoteTotalBet != null && remoteTotalBet > 0) {
    sessionItem['totalBet'] = remoteTotalBet;
  }

  final balBefore = (remoteRow['balanceBefore'] as num?)?.toInt() ?? (sessionItem['balanceBefore'] as num?)?.toInt();
  final totalWager = (remoteTotalBet != null && remoteTotalBet > 0)
      ? remoteTotalBet
      : ((sessionItem['totalBet'] as num?)?.toInt() ?? 0);
  final balAfter = (remoteRow['balanceAfter'] as num?)?.toInt() ??
      (balBefore != null && balBefore > 0
          ? math.max(0, settled ? balBefore - totalWager + finalPrize : balBefore - totalWager)
          : (sessionItem['balanceAfter'] as num?)?.toInt());

  return {
    ...remoteRow,
    ...sessionItem,
    'bets': effectiveBets,
    'totalBet': totalWager,
    'settled': settled,
    'prize': finalPrize,
    'amount': finalPrize,
    if (effectiveWinningFood.isNotEmpty) 'winningFood': effectiveWinningFood,
    if (effectiveWinningFood.isNotEmpty) 'name': effectiveWinningFood,
    if (isRemoteAuthoritative && remoteRow['emoji']?.toString().isNotEmpty == true)
      'emoji': remoteRow['emoji'].toString(),
    if (isRemoteAuthoritative && remoteRow['label']?.toString().isNotEmpty == true)
      'label': remoteRow['label'].toString(),
    if (isRemoteAuthoritative && remoteRow['multiplier']?.toString().isNotEmpty == true)
      'multiplier': remoteRow['multiplier'].toString(),
    if (remoteRow['orderId'] != null) 'orderId': remoteRow['orderId'],
    if (balBefore != null) 'balanceBefore': balBefore,
    if (balAfter != null) 'balanceAfter': balAfter,
    if (remoteRow['serialNumber'] != null) 'serialNumber': remoteRow['serialNumber'],
  };
}

/// Evaluates displayed prize for a My Bet card.
/// Fix B: For settled rows or rows where a server prize is present,
/// displays the prize as-is; never recomputes.
int resolveCardDisplayPrize({
  required bool isSettled,
  required bool hasServerPrize,
  required int existingPrize,
  required Map<String, dynamic> betsMap,
  required String winningFood,
  required int multiplier,
  String? roundType,
}) {
  if (isSettled || hasServerPrize) {
    return existingPrize;
  }
  if (betsMap.isNotEmpty && winningFood.isNotEmpty) {
    final normBets = <String, int>{};
    betsMap.forEach((k, v) {
      final val = (v as num?)?.toInt() ?? 0;
      if (val > 0) normBets[k.toString()] = val;
    });
    return calculateSpinWheelPrize(
      bets: normBets,
      winningName: winningFood,
      multiplier: multiplier,
      roundType: roundType,
    );
  }
  return existingPrize;
}

/// Deduce the winning food from the winning bet in betsMap when prize > 0.
/// Guarantees that the highlighted chip, displayed name, and icon in Betting History
/// always match the winning stake that resulted in the payout.
String deduceWinningFoodFromWinningBet({
  required Map<String, dynamic> betsMap,
  required int prize,
  String? existingFood,
  String? roundType,
}) {
  if (prize <= 0 || betsMap.isEmpty) return existingFood ?? '';

  // 1. If existingFood already explains the prize via a bet in betsMap, keep it
  if (existingFood != null && existingFood.isNotEmpty) {
    final normExisting = normalizeFoodKey(existingFood);
    final mult = resolveFoodMultiplier(normExisting);
    for (final entry in betsMap.entries) {
      final normKey = normalizeFoodKey(entry.key.toString());
      final isAliasMatch = normKey == normExisting ||
          (normKey == 'burger' && normExisting == 'hotdog') ||
          (normKey == 'hotdog' && normExisting == 'burger') ||
          (normKey == 'kebab' && normExisting == 'skewer') ||
          (normKey == 'skewer' && normExisting == 'kebab') ||
          (normKey == 'steak' && normExisting == 'meat') ||
          (normKey == 'meat' && normExisting == 'steak') ||
          (normKey == 'cabbage' && (normExisting == 'leaf' || normExisting == 'veg'));
      if (isAliasMatch) {
        final betAmt = (entry.value as num?)?.toInt() ?? 0;
        if (betAmt > 0 && betAmt * mult == prize) {
          return entry.key.toString();
        }
      }
    }
  }

  // 2. Search for the exact bet that matches prize with its food multiplier
  final matchingFoods = <String>[];
  for (final entry in betsMap.entries) {
    final food = entry.key.toString();
    final betAmt = (entry.value as num?)?.toInt() ?? 0;
    if (betAmt <= 0) continue;
    final mult = resolveFoodMultiplier(food);
    if (betAmt * mult == prize) {
      matchingFoods.add(food);
    }
  }

  if (matchingFoods.length == 1) {
    return matchingFoods.first;
  }

  if (matchingFoods.isNotEmpty) {
    if (existingFood != null && existingFood.isNotEmpty) {
      final normExisting = normalizeFoodKey(existingFood);
      for (final f in matchingFoods) {
        if (normalizeFoodKey(f) == normExisting) return f;
      }
    }
    return matchingFoods.first;
  }

  // 3. Category tabs (Salad / Pizza)
  final saladBet = (betsMap['Salad'] ?? betsMap['salad'] as num?)?.toInt() ?? 0;
  if (saladBet > 0 && saladBet * 5 == prize) return 'SALAD';
  final pizzaBet = (betsMap['Pizza'] ?? betsMap['pizza'] as num?)?.toInt() ?? 0;
  if (pizzaBet > 0 && pizzaBet * 45 == prize) return 'PIZZA';

  return existingFood ?? '';
}

class SpinWheelScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const SpinWheelScreen({super.key, this.roomId});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  double _pointerAngle = 0.0;
  int _countdown = 30;
  Timer? _timer;
  int _currentSegment = 0;
  Map<String, int> _currentBets = {};
  Map<String, int> _betClickCounts = {};
  Map<String, int> _confirmedBets = {};
  String? _confirmedRoundId;
  String? _focusedIcon;
  String? _lastResultType;
  int _selectedChipValue = 100;
  int _segmentCount = 8; // Matches server stepAngle = 360 / segments.length
  int _todayProfits = 0;
  bool _isSpinning = false;
  bool _isBetLocked = false;
  bool _isOffline = false;
  bool _platformHasNetwork = true;
  bool? _rtdbConnected;
  int _lastConnectionNoticeMs = 0;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _platformConnectivitySub;

  Map<String, dynamic>? _pendingRoundResult;
  bool _hasPendingResult = false;
  String? _resultPendingRoundId;

  Map<String, dynamic>? _submittedSpinResult;
  bool _isAutoSubmitting = false;

  // Stored result for server-clock-synced display
  SpinItem? _storedWinItem;
  int _storedPrize = 0;
  int _storedWager = 0;
  List<dynamic> _storedWinners = [];
  String _storedRoundId = '';
  Map<String, int>? _storedBets;

  String? _hasShownResultForRound;
  String? _hasTriggeredSpinSyncForRound;
  bool _isBottomSheetOpen = false;
  Route? _bottomSheetRoute;
  DateTime? _bottomSheetOpenTime;
  String? _currentRoundId;
  String? _settledRoundId;
  final Set<String> _settlingRoundIds = <String>{};

  int _roundTransitionCountdown = 0;
  bool _showRoundTransition = false;
  String _countdownLabel = "Select time";

  late AnimationController _idleController;
  late AnimationController _spinController;
  Animation<double>? _spinAnimation;
  Timer? _spinFallbackTimer;
  int _optimisticWinnings = 0;
  final AuthoritativeWalletManager _walletManager = AuthoritativeWalletManager();
  int _balanceSeq = 0;

  int get _currentAuthoritativeDiamonds => _walletManager.displayedBalance;

  SpinGameState _gameState = SpinGameState.betting;
  Map<String, dynamic>? _currentSpinOutcome;

  /// Session-persistent cache of recent rounds played in this app session.
  /// Retains confirmed bets and settled round outcomes so they never vanish
  /// upon round rollover or during Firestore sync latency.
  static final Map<String, Map<String, dynamic>> _sessionRoundsHistory = {};

  static void _pruneSessionHistory() {
    if (_sessionRoundsHistory.length > 50) {
      final sortedKeys = _sessionRoundsHistory.keys.toList()
        ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
      final keysToRemove = sortedKeys.skip(50).toList();
      for (final k in keysToRemove) {
        _sessionRoundsHistory.remove(k);
      }
    }
  }

  void _recordSessionBet({
    required String roundId,
    required Map<String, int> bets,
    required int totalBet,
    int? prize,
    String? winningFood,
    String? emoji,
    String? label,
    bool settled = false,
  }) {
    if (roundId.isEmpty || totalBet <= 0) return;
    final existing = _sessionRoundsHistory[roundId] ?? {};
    final isAlreadySettled = existing['settled'] == true;
    final existingPrize = (existing['prize'] as num?)?.toInt() ?? (existing['amount'] as num?)?.toInt() ?? 0;
    // Critical Guard: If this round already won, NEVER allow a subsequent bet update to reset prize to 0
    final effectivePrize = isAlreadySettled && existingPrize > 0 ? existingPrize : (prize ?? existingPrize);
    final existingBalBefore = (existing['balanceBefore'] as num?)?.toInt();
    final curWalletBal = _walletManager.confirmedBalance;
    final balBefore = existingBalBefore ?? (curWalletBal > 0 ? (curWalletBal + totalBet) : curWalletBal);
    final balAfter = math.max(0, balBefore - totalBet);

    _sessionRoundsHistory[roundId] = {
      ...existing,
      'roundId': roundId,
      'bets': Map<String, int>.from(bets),
      'totalBet': totalBet,
      'prize': effectivePrize,
      'amount': effectivePrize,
      if (balBefore > 0) 'balanceBefore': balBefore,
      if (balAfter >= 0) 'balanceAfter': balAfter,
      'winningFood': winningFood ?? existing['winningFood'] ?? '',
      'name': winningFood ?? existing['name'] ?? '',
      'emoji': emoji ?? existing['emoji'] ?? '🎰',
      'label': label ?? existing['label'] ?? '',
      'multiplier': label ?? existing['multiplier'] ?? '',
      'settled': isAlreadySettled || settled,
      'timestamp': existing['timestamp'] ?? DateTime.now(),
      'createdAt': existing['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    _pruneSessionHistory();
    _notifyHistoryUpdate();
  }

  void _recordSessionResult({
    required String roundId,
    required SpinItem winningItem,
    required int prize,
    required int totalBet,
    required Map<String, dynamic> bets,
  }) {
    if (roundId.isEmpty) return;
    final existing = _sessionRoundsHistory[roundId] ?? {};
    final effectiveBets = bets.isNotEmpty ? bets : (existing['bets'] as Map? ?? {});
    final effectiveWager = totalBet > 0 ? totalBet : (existing['totalBet'] as num?)?.toInt() ?? 0;

    if (effectiveBets.isEmpty && effectiveWager <= 0) return;

    final finalPrize = prize;

    _sessionRoundsHistory[roundId] = {
      ...existing,
      'roundId': roundId,
      'bets': Map<String, dynamic>.from(effectiveBets),
      'totalBet': effectiveWager,
      'prize': finalPrize,
      'amount': finalPrize,
      'winningFood': winningItem.name,
      'name': winningItem.name,
      'emoji': winningItem.emoji,
      'label': '${winningItem.multiplier}x',
      'multiplier': '${winningItem.multiplier}x',
      'settled': true,
      'timestamp': existing['timestamp'] ?? DateTime.now(),
      'createdAt': existing['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    _pruneSessionHistory();
    _notifyHistoryUpdate();
  }

  void _recordSessionSettle({
    required String roundId,
    required int prize,
    int? balanceAfter,
    int? totalBet,
  }) {
    if (roundId.isEmpty) return;
    final cur = _sessionRoundsHistory[roundId] ??= <String, dynamic>{'roundId': roundId};
    cur['settled'] = true;
    cur['prize'] = prize; // Exactly match authoritative backend settlement (even if 0 for loss)
    cur['amount'] = prize;
    if (totalBet != null && totalBet > 0) {
      cur['totalBet'] = totalBet;
    }
    final balBefore = (cur['balanceBefore'] as num?)?.toInt();
    final totalWager = (cur['totalBet'] as num?)?.toInt() ?? 0;
    if (balanceAfter != null) {
      cur['balanceAfter'] = balanceAfter;
    } else if (balBefore != null && balBefore > 0) {
      cur['balanceAfter'] = balBefore - totalWager + prize;
    }
    _notifyHistoryUpdate();
  }

  /// Reconciles session history after bet submission failure or rejection so unaccepted deltas never persist.
  /// If prior bets were confirmed for this round, rewrites the session row with the confirmed bets.
  /// Otherwise, completely removes the unaccepted session entry.
  void _reconcileSessionHistoryAfterFailure(String roundId) {
    if (roundId.isEmpty) return;
    final confirmedBelongs = (_confirmedRoundId == roundId) && _confirmedBets.isNotEmpty;
    final submittedBelongs = _submittedSpinResult != null &&
        _submittedSpinResult!['roundId']?.toString() == roundId;

    if (confirmedBelongs && _confirmedBets.isNotEmpty) {
      final confirmedTotal = _confirmedBets.values.fold<int>(0, (sum, v) => sum + v);
      if (confirmedTotal > 0) {
        _recordSessionBet(
          roundId: roundId,
          bets: Map<String, int>.from(_confirmedBets),
          totalBet: confirmedTotal,
        );
        return;
      }
    } else if (submittedBelongs) {
      final subBets = _submittedSpinResult!['bets'] is Map
          ? (_submittedSpinResult!['bets'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : <String, int>{};
      final subTotal = (_submittedSpinResult!['totalBet'] as num?)?.toInt() ??
          subBets.values.fold<int>(0, (sum, v) => sum + v);
      if (subTotal > 0) {
        _recordSessionBet(
          roundId: roundId,
          bets: subBets,
          totalBet: subTotal,
        );
        return;
      }
    }

    _sessionRoundsHistory.remove(roundId);
    _notifyHistoryUpdate();
  }

  // Track cached sound paths to avoid socket exceptions
  String? _localBetSoundPath;
  String? _localSpinSoundPath;
  String? _localWinSoundPath;

  void _precacheSounds() {}
  void _playBetSoundAndHaptic() {}
  void _playCountdownTick() {}

  void _showConnectionNotFoundDialog({String? title, String? message}) {
    // Deliberately NOT a modal - a dialog would fight the 40s round timer. But it must not
    // be silent either: a refused bet with no feedback is indistinguishable from a bet that
    // silently vanished, which is exactly the symptom being reported. Throttled so the
    // 50ms round timer cannot spam it.
    debugPrint('[SPIN_WHEEL_EVENT] 🔇 connection notice: ${title ?? 'Connection Not Found'} — ${message ?? 'handled silently'}');
    if (!mounted) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastConnectionNoticeMs < 4000) return;
    _lastConnectionNoticeMs = nowMs;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Connection problem. Your bet was not placed.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _placeBet(String itemName, List<SpinItem> items) {
    if (_isBetLocked || _isOffline || !_platformHasNetwork) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Bet blocked on "$itemName": isBetLocked=$_isBetLocked, isOffline=$_isOffline, platformHasNetwork=$_platformHasNetwork');
      if (mounted && (_isOffline || !_platformHasNetwork)) {
        _showConnectionNotFoundDialog();
      }
      return;
    }

    // Authoritative wallet gate: never allow betting against an unsynced balance.
    if (!_walletManager.hasInitialBalance) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Bet blocked on "$itemName": wallet balance not synced yet.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Syncing wallet…"),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final lowerName = itemName.toLowerCase().trim();

    final matchedItem = items.firstWhere(
      (item) => item.name.toLowerCase().trim() == lowerName,
      orElse: () => SpinItem(name: itemName, multiplier: 1, emoji: ''),
    );
    final exactName = matchedItem.name;

    final diamonds = _currentAuthoritativeDiamonds;
    final wallet = ref.read(walletBalanceProvider).value;
    final beans = wallet?['beans'] ?? 0;
    final totalPlayingPower = diamonds + (beans * 2 / 7).floor();

    // totalPlayingPower derives from displayedBalance which is already
    // confirmedBalance minus ALL pending debits (including this round's bets).
    // The new chip alone must fit in the remaining power — do NOT re-add
    // currentTotalBet here, that double-counts and caps bets at ~half balance.
    if (_selectedChipValue > totalPlayingPower) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Bet rejected on "$exactName": Insufficient funds (chip: $_selectedChipValue, available: $totalPlayingPower)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient Diamonds & Stars for this bet"))
      );
      return;
    }

    _playBetSoundAndHaptic();

    final now = _synchronizedTimeMs;
    // FIX 1: Derive txnId from server clock — same formula as _autoSubmitBets —
    // so reconcileBetSuccess always clears the correct pending debit key.
    final betRoundId = (now ~/ 40000).toString();
    final betTxnId = 'bet_$betRoundId';

    _walletManager.addPendingDebit(
      txnId: betTxnId,
      amount: _selectedChipValue,
    );

    setState(() {
      _currentBets[exactName] = (_currentBets[exactName] ?? 0) + _selectedChipValue;
      _betClickCounts[exactName] = (_betClickCounts[exactName] ?? 0) + 1;
      _notifyHistoryUpdate();
    });

    final newTotalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    debugPrint('[SPIN_WHEEL_EVENT] 🎲 Bet Placed on "$exactName": chip=$_selectedChipValue, itemTotal=${_currentBets[exactName]}, totalWager=$newTotalBet, clicks=${_betClickCounts[exactName]}');

    final curRound = _currentRoundId;
    if (curRound != null && curRound.isNotEmpty) {
      _recordSessionBet(
        roundId: curRound,
        bets: _currentBets,
        totalBet: newTotalBet,
      );
    }

    _debounceTimer?.cancel();
    final secIntoCycle = (now % 40000) ~/ 1000;
    // Dynamic debounce: 350ms during active betting to naturally group rapid chip taps into a single wager,
    // and 100ms when approaching the 27s cutoff to ensure prompt dispatch.
    final debounceDuration = secIntoCycle >= 24 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 350);
    _debounceTimer = Timer(debounceDuration, () {
      if (!mounted || _currentBets.isEmpty) return;
      _autoSubmitBets();
    });

    _persistBetState();
  }

  bool _persistScheduled = false;
  void _persistBetState() {
    if (_persistScheduled) return;
    _persistScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistScheduled = false;
      if (!mounted) return;
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final roundId = (now ~/ serverRoundMs).toString();
      GameRecoveryService().saveBetState(
        bets: _currentBets,
        betClickCounts: _betClickCounts,
        roundId: roundId,
        timestamp: now,
      );
    });
  }

  bool _hasPendingAdditionalBets = false;

  bool _hasUnconfirmedBets() {
    if (_currentBets.isEmpty) return false;
    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final activeRound = (now ~/ serverRoundMs).toString();
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    // Strict Guards: Cannot have unconfirmed bets if outside betting phase (>= 35s) or for mismatched round
    if (secondsIntoCycle >= 35 || _currentRoundId != activeRound) {
      return false;
    }
    // Only compare against confirmed bets if they belong to this active round
    final confirmed = (_confirmedRoundId == activeRound || _confirmedRoundId == _currentRoundId)
        ? _confirmedBets
        : const <String, int>{};
    for (final entry in _currentBets.entries) {
      if ((confirmed[entry.key] ?? 0) < entry.value) {
        return true;
      }
    }
    return false;
  }

  Future<void> _autoSubmitBets({String? forcedRoundId}) async {
    if (_currentBets.isEmpty || _isOffline || !_platformHasNetwork) return;

    if (_isAutoSubmitting) {
      _hasPendingAdditionalBets = true;
      debugPrint('[SPIN_WHEEL_EVENT] ⏳ Auto-submit already in flight; queued pending bets for next batch');
      return;
    }

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    // When re-dispatching a queued delta after an in-flight call resolved, the caller
    // forces the round that the ORIGINAL call targeted. The device clock can jitter
    // by seconds (observed ±13s), so prefer _currentRoundId if aligned.
    final submissionRoundId = forcedRoundId ?? _currentRoundId ?? (now ~/ serverRoundMs).toString();

    // STRICT ROUND GUARD: Never auto-submit for a round that is not the active round
    if (_currentRoundId != null && submissionRoundId != _currentRoundId && forcedRoundId == null) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Auto-submit cancelled: submissionRoundId ($submissionRoundId) != currentRoundId ($_currentRoundId)');
      return;
    }

    // Taps are disabled on the UI at second 27. Any bets queued here were placed
    // legitimately before second 27 and are simply finishing network dispatch. Allow up to second 35.
    // The server strictly rejects bets when msIntoRound >= 36000 ("Betting phase closed").
    if (secondsIntoCycle >= 35) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Auto-submit aborted: secIntoCycle ($secondsIntoCycle) >= 35s for round $submissionRoundId');
      _reconcileSessionHistoryAfterFailure(submissionRoundId);
      return;
    }

    final snapshotBets = Map<String, int>.from(_currentBets);
    final totalBet = snapshotBets.values.fold(0, (sum, val) => sum + val);
    if (totalBet <= 0) return;

    _isAutoSubmitting = true;
    _hasPendingAdditionalBets = false;
    debugPrint('[SPIN_WHEEL_EVENT] 🚀 Auto-submitting bets to backend: totalBet=$totalBet, bets=$snapshotBets, roundId=$submissionRoundId, secIntoCycle=$secondsIntoCycle');
    
    // Eagerly record in session history so the round is visible in My Bets as "IN PLAY" immediately
    // and is never lost even if network requests are delayed or retry
    _recordSessionBet(
      roundId: submissionRoundId,
      bets: snapshotBets,
      totalBet: totalBet,
    );
    const callTimeout = Duration(seconds: 25);
    final requestSeq = ++_balanceSeq;
    // Deterministic per (uid, round): the server keys idempotency on this txnId
    // (index.js:3554) and echoes it into users.lastTxnId (index.js:3787), which is
    // how the wallet stream clears a pending debit. A request-seq suffix made every
    // retry a NEW ledger doc and guaranteed the pending key could never match.
    final betTxnId = 'bet_$submissionRoundId';
    final roundPendingKey = betTxnId;
    // FIX (RTT-corrected offset): serverTime is captured when the function STARTS,
    // so subtracting it from localNow at RESPONSE time bakes the full ~15-20s callable
    // round-trip into the offset (seen as -13s->-27s swings that broke phase timing).
    // Correct with half RTT: assume symmetric latency around the call.
    final offsetReqStart = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: snapshotBets,
        roundId: submissionRoundId,
        roomId: widget.roomId,
        txnId: betTxnId,
      ).timeout(callTimeout);

      if (!mounted) return;

      final resultRoundId = result['roundId']?.toString();
      final serverTime = (result['serverTime'] as num?)?.toInt();
      if (serverTime != null) {
        final localNow = DateTime.now().millisecondsSinceEpoch;
        final newOffset = serverTime - ((offsetReqStart + localNow) ~/ 2);
        if (_serverTimeOffset == 0 || (_serverTimeOffset - newOffset).abs() > 1500) {
          _serverTimeOffset = newOffset;
        } else {
          _serverTimeOffset = ((_serverTimeOffset * 3) + newOffset) ~/ 4;
        }
        _lastSynchronizedTimeMs = serverTime;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server time synchronized: offset=$_serverTimeOffset ms');
      }

      // If server gracefully bound bet forward to a newer round, remove phantom session record for submissionRoundId
      if (submissionRoundId != resultRoundId) {
        _sessionRoundsHistory.remove(submissionRoundId);
      }

      final currentRoundNum = int.tryParse(_currentRoundId ?? '') ?? 0;
      final resultRoundNum = int.tryParse(resultRoundId ?? '') ?? 0;
      final isForwardOrActive = resultRoundId != null && resultRoundNum >= currentRoundNum;

      final serverBal = (result['balance'] as num?)?.toInt();
      final serverSeq = (result['seq'] as num?)?.toInt() ?? requestSeq;
      final effectiveBal = serverBal ?? math.max(0, _walletManager.confirmedBalance - totalBet);
      final currentTotalWager = _currentBets.values.fold<int>(0, (sum, val) => sum + val);
      final remainingPending = isForwardOrActive ? math.max(0, currentTotalWager - totalBet) : 0;

      if (isForwardOrActive) {
        debugPrint('[SPIN_WHEEL_EVENT] ✅ Bets successfully confirmed by backend! roundId=$resultRoundId (submitted: $submissionRoundId), prize=${result['prize']}, bets=$snapshotBets, balance=$effectiveBal, seq=$serverSeq, remainingPending=$remainingPending');
        _submittedSpinResult = result;
        final bool advancedRound = resultRoundNum > currentRoundNum;
        if (advancedRound) {
          _currentRoundId = resultRoundId;
          _subscribeToRealtimeRoundState();
        }
        setState(() {
          _walletManager.reconcileBetSuccess(
            txnId: roundPendingKey,
            serverBalance: effectiveBal,
            serverSeq: serverSeq,
            timestamp: serverTime ?? DateTime.now().millisecondsSinceEpoch,
            remainingPendingAmount: remainingPending,
          );
          _confirmedRoundId = resultRoundId;
          // Merge confirmed amounts per item (max across batches) instead of replacing.
          // NOTE: _currentBets keeps the FULL total per item so the on-wheel bet badges
          // stay visible; _hasUnconfirmedBets() below compares confirmed vs current to
          // decide whether the finally block must re-dispatche delta bets tapped during flight.
          for (final k in snapshotBets.keys) {
            final submitted = snapshotBets[k] ?? 0;
            _confirmedBets[k] = math.max(_confirmedBets[k] ?? 0, submitted);
          }
          _notifyHistoryUpdate();
        });
        _recordSessionBet(
          roundId: resultRoundId!,
          bets: snapshotBets,
          totalBet: totalBet,
        );
        if (_currentBets.isEmpty) {
          GameRecoveryService().clearBetState();
        } else {
          _persistBetState();
        }
        ref.invalidate(transactionStreamProvider);

        final curSec = (_synchronizedTimeMs % 40000) ~/ 1000;
        if (curSec >= 27 && !_hasPendingResult && !_hasStartedFallbackCall) {
          _hasStartedFallbackCall = true;
          _preFetchRoundOutcome();
        }
      } else {
        debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Stale bet response for past round $resultRoundId ignored for active round $_currentRoundId. Reconciling wallet without polluting current round state.');
        if (resultRoundId != null) {
          _recordSessionBet(
            roundId: resultRoundId,
            bets: snapshotBets,
            totalBet: totalBet,
            settled: true,
          );
        }
        setState(() {
          _walletManager.reconcileBetSuccess(
            txnId: roundPendingKey,
            serverBalance: effectiveBal,
            serverSeq: serverSeq,
            timestamp: serverTime ?? DateTime.now().millisecondsSinceEpoch,
            remainingPendingAmount: 0,
          );
          _notifyHistoryUpdate();
        });
        GameRecoveryService().clearBetState();
      }
    } catch (e) {
      debugPrint("[SPIN_WHEEL_EVENT] ❌ Auto-submit bets failed: $e. Handled gracefully.");
      _hasStartedFallbackCall = false;

      final errorStr = e.toString();
      final isTimeout = e is TimeoutException || errorStr.contains('TimeoutException');
      final isExplicitBackendError = errorStr.contains('failed-precondition') ||
          errorStr.contains('invalid-argument') ||
          errorStr.contains('not-found') ||
          errorStr.contains('permission-denied') ||
          errorStr.contains('Betting phase closed') ||
          errorStr.contains('Bets are locked for round');
      // A stale-round rejection is the server refusing a RETRIED submission for a round
      // that already ended. The ORIGINAL submission may have actually landed (timeout
      // raced a slow response), so the pending debit must be RETAINED — round settlement
      // reconciles the true server balance. Refunding here would over-credit the wallet.
      final isStaleRoundRejection = errorStr.contains('stale round submission');
      final isRoundActive = _currentRoundId == submissionRoundId && _gameState == SpinGameState.betting;

      // CRITICAL FIX: Explicit backend errors (e.g. insufficient diamonds, betting closed) must IMMEDIATELY
      // refund the pending debit, regardless of whether the round is active.
      // Only genuine connection timeouts during the active betting phase retain pending debits.
      if ((isExplicitBackendError && !isStaleRoundRejection) || (!isTimeout && !isRoundActive && !isStaleRoundRejection)) {
        _walletManager.reconcileBetFailure(
          txnId: roundPendingKey,
          errorMessage: errorStr,
        );
        _reconcileSessionHistoryAfterFailure(submissionRoundId);
      } else {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Retaining pending debit for round $submissionRoundId (isTimeout: $isTimeout, isRoundActive: $isRoundActive). Will retry at lock.');
        _hasPendingAdditionalBets = true;
      }

      if (!mounted) return;

      final bool roundMovedOn = _gameState != SpinGameState.betting || _currentRoundId != submissionRoundId;

      // TRANSPARENT ERROR SURFACING: while the round is still accepting bets, a rejection
      // is ALWAYS shown to the user instead of silently cancelling their wager. A
      // rejected/late bet must never look like bets "disappearing for no reason".
      if (!roundMovedOn) {
        final String userMessage;
        if (isTimeout) {
          userMessage = 'Bet submission for Round $submissionRoundId timed out. Retrying…';
        } else if (errorStr.contains('Betting phase closed') || errorStr.contains('Bets are locked for round')) {
          userMessage = 'Bets closed for Round $submissionRoundId before your bet landed.';
        } else if (errorStr.contains('Insufficient Diamonds')) {
          userMessage = 'Insufficient Diamonds & Stars for that bet.';
        } else {
          userMessage = 'Bet for Round $submissionRoundId was not accepted. Please retry.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), duration: const Duration(seconds: 3)),
        );
      }

      // STRICT PHASE GUARD: when the round has already moved to spinning/results or rolled
      // to a new round, clear the stale input (nothing to do — the round is over). Never a
      // silent wipe of an ACTIVE round.
      if (roundMovedOn) {
        debugPrint('[SPIN_WHEEL_EVENT] 🔇 Clearing round $submissionRoundId bets: ${_gameState.name} phase / cross-round transition.');
        _reconcileSessionHistoryAfterFailure(submissionRoundId);
        // Still tell the player. A silent wipe here is literally "my bet vanished".
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Round $submissionRoundId closed before your bet landed. It was not placed.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _currentBets = {};
          _betClickCounts = {};
          _hasPendingAdditionalBets = false;
        });
        return;
      }

      // ROUND-SCOPED CONFIRMED CHECK: only clear unconfirmed DELTA taps when the confirmed
      // state (or authoritative result) actually belongs to THIS submission round. Stale
      // confirmed state from a previous round must never wipe the current round's taps.
      final confirmedBelongs = (_confirmedRoundId == submissionRoundId) && _confirmedBets.isNotEmpty;
      final submittedBelongs = _submittedSpinResult != null &&
          _submittedSpinResult!['roundId']?.toString() == submissionRoundId;
      if (confirmedBelongs || submittedBelongs) {
        debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Auto-submit failed: Dropping unconfirmed delta taps for round $submissionRoundId.');
        _reconcileSessionHistoryAfterFailure(submissionRoundId);
        setState(() {
          for (final k in _currentBets.keys.toList()) {
            if ((_confirmedBets[k] ?? 0) <= 0) {
              _currentBets.remove(k);
            } else {
              _currentBets[k] = _confirmedBets[k]!;
            }
          }
          _betClickCounts = {};
          _hasPendingAdditionalBets = false;
        });
        return;
      }

      // Round is still in betting, nothing confirmed for it, but the server refused.
      // KEEP the wager visible (the 27s lock auto-submit will retry) and surface the
      // reason above rather than silently erasing the round.
      debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Bet rejected for round $submissionRoundId while betting is open. Keeping wager for retry at lock.');
      _hasPendingAdditionalBets = false;
      if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
        _showConnectionNotFoundDialog();
      }
    } finally {
      _isAutoSubmitting = false;
      // If user placed additional bets while this network call was in flight, immediately dispatch next batch!
      if (mounted && (_hasPendingAdditionalBets || _hasUnconfirmedBets())) {
        final now = _synchronizedTimeMs;
        const serverRoundMs = 40000;
        final activeRound = (now ~/ serverRoundMs).toString();
        final currentSec = (now % serverRoundMs) ~/ 1000;
        // Allow in-flight queued delta bets to dispatch up to 35s (server gate closes at 36s).
        if (currentSec < 35 && (_currentRoundId == submissionRoundId || submissionRoundId == activeRound)) {
          _hasPendingAdditionalBets = false;
          debugPrint('[SPIN_WHEEL_EVENT] 🔄 In-flight call finished; dispatching queued delta bets now at ${currentSec}s...');
          _autoSubmitBets(forcedRoundId: submissionRoundId);
        } else if (currentSec >= 35 && _currentRoundId == submissionRoundId) {
          // Beyond 35s the server will strictly reject with "Betting phase closed".
          // Prune queued unconfirmed delta bets immediately and reconcile session history.
          debugPrint('[SPIN_WHEEL_EVENT] ⛔ In-flight call finished past 35s (${currentSec}s); pruning unconfirmed delta bets for round $submissionRoundId.');
          _hasPendingAdditionalBets = false;
          _reconcileSessionHistoryAfterFailure(submissionRoundId);
          setState(() {
            for (final k in _currentBets.keys.toList()) {
              if ((_confirmedBets[k] ?? 0) <= 0) {
                _currentBets.remove(k);
              } else {
                _currentBets[k] = _confirmedBets[k]!;
              }
            }
            _betClickCounts = {};
          });
        }
      }
    }
  }

  Future<void> _preFetchRoundOutcome() async {
    if (_isOffline || _isAutoSubmitting) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    final currentRoundId = (now ~/ serverRoundMs).toString();

    if (secondsIntoCycle >= 30) return;
    if (_hasPendingResult && _resultPendingRoundId == currentRoundId) return;

    try {
      debugPrint('[SPIN_WHEEL_EVENT] ⚡ Pre-fetching canonical round outcome for round $currentRoundId at ${secondsIntoCycle}s window...');
      final result = await ref.read(gameServiceProvider).getSpinWheelRoundOutcome(
        roundId: currentRoundId,
      );

      if (!mounted) return;

      final resultRoundId = result['roundId']?.toString();
      final activeRoundNow = (_synchronizedTimeMs ~/ serverRoundMs).toString();

      final rawOutcome = (result['outcome'] is Map)
          ? Map<String, dynamic>.from(result['outcome'] as Map)
          : result;
      final outcomeRoundId = rawOutcome['roundId']?.toString() ?? resultRoundId;

      if (outcomeRoundId == currentRoundId && currentRoundId == activeRoundNow) {
        final Map<String, dynamic> outcomeMap = Map<String, dynamic>.from(rawOutcome);
        outcomeMap['roundId'] = currentRoundId;
        _pendingRoundResult = outcomeMap;
        _hasPendingResult = true;
        _resultPendingRoundId = currentRoundId;
        debugPrint('[SPIN_WHEEL_EVENT] ⚡ Canonical round outcome pre-fetched: roundId=$currentRoundId, item=${outcomeMap['name']}, multiplier=${outcomeMap['multiplier']}x, sector=${outcomeMap['sectorIndex']}');
      } else {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Discarded late pre-fetch response for past round $resultRoundId (active: $activeRoundNow)');
      }
    } catch (e) {
      debugPrint("[SPIN_WHEEL_EVENT] ⚠️ Pre-fetch round outcome note: $e");
      _hasStartedFallbackCall = true;
    }
  }

  int _currentTickIndex = 0;
  List<double> _tickDurations = [];
  List<double> _tickFireTimes = [];
  Timer? _tickTimer;
  bool _isProcessingSpin = false;

  bool _spinCompleted = false;
  bool _resultLock = false;
  int? _lastCalculatedRound;
  Map<String, dynamic>? _lastGlobalOutcome;
  Map<String, dynamic>? _lastRoundResultForHistory;
  int _lastRoundWager = 0;
  int _lastRoundPrize = 0;
  BuildContext? _bottomSheetContext;
  
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _roundDocSubscription;
  final List<Map<String, dynamic>> _realtimeRecentResults = [];
  String? _hasSpunForRound;
  bool _hasStartedFallbackCall = false;

  final ValueNotifier<int> _historyUpdateNotifier = ValueNotifier<int>(0);
  void _notifyHistoryUpdate() {
    _historyUpdateNotifier.value++;
  }

  int _lastSynchronizedTimeMs = 0;

  int get _synchronizedTimeMs {
    final raw = DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
    if (raw > _lastSynchronizedTimeMs) {
      _lastSynchronizedTimeMs = raw;
    }
    return _lastSynchronizedTimeMs;
  }

  Future<void> _syncServerRoundClock() async {
    if (_isOffline || !_platformHasNetwork) return;
    // FIX: pass the client's roundId so the server resolves the outcome for the round
    // THIS client is watching (with the monotonic clock, that matches the server). When
    // no roundId is passed, the server uses its own clock and may answer for the NEXT
    // round — the outcome never lands and the "Outcome not ready" loop fires every round.
    final targetRoundId = _currentRoundId ?? (_synchronizedTimeMs ~/ 40000).toString();
    final offsetReqStart = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await ref.read(gameServiceProvider).syncSpinWheelRound(roundId: targetRoundId);
      if (!mounted) return;
      final serverTime = (res['serverTime'] as num?)?.toInt();
      final serverRound = res['roundId']?.toString();
      if (serverTime != null) {
        final localNow = DateTime.now().millisecondsSinceEpoch;
        // RTT-corrected offset: same half-latency assumption as playSpinWheel.
        final newOffset = serverTime - ((offsetReqStart + localNow) ~/ 2);
        if (_serverTimeOffset == 0 || (_serverTimeOffset - newOffset).abs() > 1500) {
          _serverTimeOffset = newOffset;
        } else {
          _serverTimeOffset = ((_serverTimeOffset * 3) + newOffset) ~/ 4;
        }
        _lastSynchronizedTimeMs = serverTime;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server round clock synced: round=$serverRound, offset=$_serverTimeOffset ms');
        if (serverRound != null && _currentRoundId != null && serverRound != _currentRoundId) {
          final sNum = int.tryParse(serverRound) ?? 0;
          final cNum = int.tryParse(_currentRoundId!) ?? 0;
          if (sNum > cNum) {
            _currentRoundId = serverRound;
            _subscribeToRealtimeRoundState();
          }
        }
      }

      final rawOutcome = res['outcome'];
      if (rawOutcome is Map) {
        final outcome = Map<String, dynamic>.from(rawOutcome);
        final outcomeRound = outcome['roundId']?.toString() ?? serverRound;
        if (outcomeRound == _currentRoundId) {
          _pendingRoundResult = outcome;
          _hasPendingResult = true;
          _resultPendingRoundId = outcomeRound;
          final now = _synchronizedTimeMs;
          const serverRoundMs = 40000;
          final secIntoCycle = (now % serverRoundMs) ~/ 1000;
          if (secIntoCycle >= 30) {
            _lastGlobalOutcome = outcome;
            _recordRoundOutcomeForRecentResults(outcome);
          }
          // FIX: relaxed window (was 30..<37). Slow callables can land the outcome a few
          // seconds late; the outcomeRound==_currentRoundId and _hasSpunForRound guards
          // already prevent stale/duplicate spins, so drop only the strict upper bound.
          if (secIntoCycle >= 30 && _hasSpunForRound != _currentRoundId && !_isSpinning && !_isProcessingSpin) {
            debugPrint('[SPIN_WHEEL_EVENT] ⚡ syncSpinWheelRound outcome triggering spin for round $outcomeRound at ${secIntoCycle}s');
            _hasSpunForRound = _currentRoundId;
            _isProcessingSpin = true;
            _startSpin(outcome);
          }
        }
      }
    } catch (e) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Server round sync note: $e');
    }
  }

  void _recordRoundOutcomeForRecentResults(Map<String, dynamic> outcome) {
    // STRICT GUARD: During active betting or spinning, do not record outcomes into recent results
    if (_gameState != SpinGameState.results && !_spinCompleted) {
      return;
    }
    final effective = (outcome['outcome'] is Map)
        ? Map<String, dynamic>.from(outcome['outcome'] as Map)
        : outcome;
    final rId = effective['roundId']?.toString() ?? outcome['roundId']?.toString();
    if (rId == null || rId.isEmpty) return;
    if (rId == _currentRoundId && !_spinCompleted) return;

    final exists = _realtimeRecentResults.any((r) => r['roundId']?.toString() == rId);
    if (!exists && mounted) {
      setState(() {
        _realtimeRecentResults.insert(0, {
          'roundId': rId,
          'name': effective['name'] ?? '',
          'emoji': effective['emoji'] ?? '',
          'label': effective['label'] ?? '${effective['multiplier']}x',
          'multiplier': (effective['multiplier'] as num?)?.toInt() ?? 5,
          'category': effective['category'] ?? 'standard',
          'timestamp': effective['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        });
        if (_realtimeRecentResults.length > 30) {
          _realtimeRecentResults.removeRange(30, _realtimeRecentResults.length);
        }
      });
    }
  }

  void _subscribeToRealtimeRoundState() {
    _roundDocSubscription?.cancel();
    // Authoritative round state machine: game_rounds/{current_round_id} is broadcast by
    // Cloud Function syncSpinWheelRound. BETTING_OPEN -> SPINNING (outcome committed) ->
    // ROUND_SETTLED (payouts credited). Every device watches the SAME doc, so phase and
    // outcome can never diverge between clients.
    final currentRoundId = (_synchronizedTimeMs ~/ 40000).toString();
    _roundDocSubscription = FirebaseFirestore.instance
        .collection('game_rounds')
        .doc(currentRoundId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!snap.exists) {
        _syncServerRoundClock();
        return;
      }

      try {
        final data = snap.data() ?? {};
        final status = data['status']?.toString();
        final rawOutcome = data['outcome'];
        if (rawOutcome is Map) {
          final outcome = Map<String, dynamic>.from(rawOutcome);
          final outcomeRoundId = outcome['roundId']?.toString() ?? currentRoundId;

          debugPrint('[SPIN_WHEEL_EVENT] 📡 game_rounds/$currentRoundId status=$status outcomeRound=$outcomeRoundId name=${outcome['name']}, sector=${outcome['sectorIndex']}, multiplier=${outcome['multiplier']}x');

          // Only record outcome for Recent Results and Last Winner once round is officially ROUND_SETTLED
          if (status == 'ROUND_SETTLED') {
            _lastGlobalOutcome = outcome;
            if (_spinCompleted || _gameState == SpinGameState.results) {
              _recordRoundOutcomeForRecentResults(outcome);
            }
          }

          if (outcomeRoundId == currentRoundId &&
              (status == 'SPINNING' || status == 'ROUND_SETTLED')) {
            _pendingRoundResult = outcome;
            _hasPendingResult = true;
            _resultPendingRoundId = outcomeRoundId;

            // The main countdown timer picks the outcome up and triggers the spin, to avoid
            // calling _startSpin directly from a stream callback (re-entrant setState risk).
            final now = _synchronizedTimeMs;
            const serverRoundMs = 40000;
            final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
            // FIX: relaxed window (was 30..<37) — same rationale as the sync path.
            if (secondsIntoCycle >= 30 && _hasSpunForRound != currentRoundId && !_isSpinning && !_isProcessingSpin) {
              debugPrint('[SPIN_WHEEL_EVENT] ⚡ Authoritative round doc triggering spin for round $outcomeRoundId at ${secondsIntoCycle}s');
              _hasSpunForRound = currentRoundId;
              _isProcessingSpin = true;
              _startSpin(outcome);
            }
          }
        }
      } catch (e) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error parsing game_rounds doc: $e');
      }
    }, onError: (e) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error watching game_rounds/$currentRoundId: $e');
    });
  }

  @override
  void initState() {
    super.initState();
    final initialWallet = ref.read(walletBalanceProvider).value;
    if (initialWallet != null) {
      final initialDiamonds = (initialWallet['diamonds'] as num?)?.toInt() ?? 0;
      final initialSeq = (initialWallet['seq'] as num?)?.toInt() ?? 0;
      final initialTxnId = initialWallet['lastTxnId'] as String?;
      _walletManager.updateFromStream(
        streamDiamonds: initialDiamonds,
        streamSeq: initialSeq,
        lastTxnId: initialTxnId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    debugPrint('[SPIN_WHEEL_EVENT] 🎬 Game Screen Initialized (roomId: ${widget.roomId ?? "None"})');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WakelockService().acquire();
      debugPrint('[SPIN_WHEEL_EVENT] 🔒 Wakelock acquired for spin wheel game');
    });

    _subscribeToRealtimeRoundState();
    _syncServerRoundClock();

    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (mounted) {
        final offset = (event.snapshot.value as num?)?.toInt() ?? 0;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server time offset synced: offset = $offset ms');
        setState(() {
          _serverTimeOffset = offset;
        });
      }
    });

    // Firebase RTDB connection state
    _connectivitySub = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
      if (!mounted) return;
      final rtdbConnected = event.snapshot.value as bool? ?? false;
      debugPrint('[SPIN_WHEEL_EVENT] 📡 Firebase RTDB .info/connected = $rtdbConnected');
      _updateOfflineState(rtdbConnected: rtdbConnected);
    });

    // Platform network connectivity (WiFi / Mobile data) via NetworkConnectivityService
    _platformConnectivitySub = NetworkConnectivityService().onConnectivityChanged.listen((hasNetwork) {
      if (!mounted) return;
      debugPrint('[SPIN_WHEEL_EVENT] 📶 Platform connectivity changed: hasNetwork=$hasNetwork');
      _updateOfflineState(platformOnline: hasNetwork);
    });

    // Initial platform check
    final initialOnline = NetworkConnectivityService().isOnline;
    debugPrint('[SPIN_WHEEL_EVENT] 📶 Initial platform connectivity: isOnline=$initialOnline');
    _updateOfflineState(platformOnline: initialOnline);
    NetworkConnectivityService().checkConnection().then((hasNetwork) {
      if (!mounted) return;
      _updateOfflineState(platformOnline: hasNetwork);
    });

    _lastCalculatedRound = _calculateCurrentRound();
    debugPrint('[SPIN_WHEEL_EVENT] 🎯 Initial calculated round: $_lastCalculatedRound (synchronizedMs: $_synchronizedTimeMs)');
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _idleController.addListener(() {
      if (_gameState != SpinGameState.betting || _isSpinning || _spinCompleted || !mounted) return;

      final double currentAngle = _idleController.value * 2 * math.pi;
      final double step = 2 * math.pi / _segmentCount;
      double normalized = (currentAngle + step / 2) % (2 * math.pi);
      if (normalized < 0) normalized += 2 * math.pi;
      final int segment = (normalized / step).floor() % _segmentCount;

      // Only call setState when the visual segment actually changes
      if (segment != _currentSegment) {
        setState(() {
          _pointerAngle = currentAngle;
          _currentSegment = segment;
        });
      } else {
        _pointerAngle = currentAngle;
      }
    });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _spinController.addListener(() {
      if (_spinAnimation != null && mounted) {
        final double animVal = _spinAnimation!.value;
        final int stepCount = animVal.round();
        final int segment = ((stepCount % _segmentCount) + _segmentCount) % _segmentCount;
        _pointerAngle = (animVal * (2 * math.pi / _segmentCount)) - (math.pi / 2);
        if (segment != _currentSegment) {
          setState(() {
            _currentSegment = segment;
          });
        }
      }
    });
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleDecelerationComplete();
      }
    });

    _precacheSounds();
    _startCountdown();
    _playPhaseSound(SpinGameState.betting);

    _tryRecoverGameState();
  }

  Future<void> _tryRecoverGameState() async {
    try {
      if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
        await GameRecoveryService().clearBetState();
        return;
      }

      final saved = await GameRecoveryService().loadBetState();
      if (saved == null || !mounted) return;

      final savedRoundId = saved['roundId']?.toString();
      final rawSavedBets = saved['bets'];
      final savedBets = rawSavedBets is Map ? Map<String, dynamic>.from(rawSavedBets) : null;
      final rawSavedCounts = saved['betClickCounts'];
      final savedClickCounts = rawSavedCounts is Map ? Map<String, dynamic>.from(rawSavedCounts) : null;
      final savedTimestamp = (saved['timestamp'] as num?)?.toInt();

      if (savedRoundId == null || savedBets == null || savedTimestamp == null) return;

      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final _currentRoundId = (now ~/ serverRoundMs).toString();
      final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;

      // Only recover if the saved state is for the current round and betting is not locked yet
      if (savedRoundId != _currentRoundId || secondsIntoCycle >= 25) {
        await GameRecoveryService().clearBetState();
        return;
      }

      // Check if state is recent enough (within last 60 seconds)
      final age = now - savedTimestamp;
      if (age > 60000) {
        await GameRecoveryService().clearBetState();
        return;
      }

      // FIX 2: Do not re-submit bets that are already confirmed.
      // This prevents phantom auto-bets on app resume when the round is still active.
      if (_confirmedBets.isNotEmpty || _submittedSpinResult != null) {
        debugPrint('[SPIN_WHEEL_EVENT] ♻️ Game recovery skipped: bets already confirmed for current round.');
        await GameRecoveryService().clearBetState();
        return;
      }

      if (mounted) {
        setState(() {
          for (final entry in savedBets.entries) {
            _currentBets[entry.key] = (entry.value as num).toInt();
          }
          for (final entry in (savedClickCounts ?? {}).entries) {
            _betClickCounts[entry.key] = (entry.value as num).toInt();
          }
        });
        debugPrint("[SPIN_WHEEL_EVENT] ♻️ Game recovery: Restored bets for round $savedRoundId: $_currentBets");
        // Re-submit restored bets if still in betting phase
        final secondsIntoCycle = (_synchronizedTimeMs % serverRoundMs) ~/ 1000;
        if (secondsIntoCycle < 30) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _currentBets.isNotEmpty) _autoSubmitBets();
          });
        }
      }


    } catch (e) {
      debugPrint("⚠️ Game recovery failed: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      // Save current game state on pause
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final roundId = (now ~/ serverRoundMs).toString();
      GameRecoveryService().saveBetState(
        bets: _currentBets,
        betClickCounts: _betClickCounts,
        roundId: roundId,
        timestamp: now,
      );
      // Release wakelock when app goes to background
      WakelockService().release();
    } else if (state == AppLifecycleState.resumed) {
      // Re-acquire wakelock when app comes to foreground
      WakelockService().acquire();
      _checkAndRecoverUnsettledRounds();
      ref.invalidate(walletBalanceProvider);
      _notifyHistoryUpdate();
    }
  }

  void _playPhaseSound(SpinGameState state) {}

  int _calculateCurrentRound() {
    final nowMs = _synchronizedTimeMs;
    const roundDuration = 40000;
    final startOfRoundEpochMs = (nowMs ~/ roundDuration) * roundDuration;
    final startOfRoundDate = DateTime.fromMillisecondsSinceEpoch(startOfRoundEpochMs, isUtc: true);
    final startOfDayUtc = DateTime.utc(startOfRoundDate.year, startOfRoundDate.month, startOfRoundDate.day);
    return ((startOfRoundEpochMs - startOfDayUtc.millisecondsSinceEpoch) ~/ roundDuration) + 1;
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      const serverRoundDurationMs = 40000;
      const serverBettingPhaseSec = 30;
      const serverSpinPhaseSec = 5;

      final now = _synchronizedTimeMs;
      final secondsIntoCycle = (now % serverRoundDurationMs) ~/ 1000;
      final msIntoCycle = now % serverRoundDurationMs;
      final currentRoundVal = _calculateCurrentRound();
      final currentRoundIdStr = (now ~/ serverRoundDurationMs).toString();

      // Continuous cycle-level wallet phase synchronization (0s-29s: betting, 30s-34s: spinning, 35s-39s: results)
      _walletManager.syncPhaseWithCycle(secondsIntoCycle);

      // Rollover / Invalidations on a new round: only trigger when moving forward to the next round
      final currentRoundNum = int.tryParse(currentRoundIdStr) ?? 0;
      final lastRoundNum = int.tryParse(_currentRoundId ?? '') ?? 0;
      final bool isNewRound = _currentRoundId != null && currentRoundNum > lastRoundNum;
      _currentRoundId = currentRoundIdStr;

      if (isNewRound) {
        debugPrint('[SPIN_WHEEL_EVENT] 🔄 Round Rollover: Round $_lastCalculatedRound -> $currentRoundVal (roundId: $_currentRoundId). Resetting bets and state.');
        _dismissBottomSheet();
        _clearStoredResult();
        _walletManager.dropStalePendingCredits(currentRoundIdStr);

        // Re-probe connectivity every round. _isOffline used to be clearable only by
        // re-entering the room, because checkConnection() ran solely in initState and
        // connectivity_plus only emits on a genuine false->true transition - so a spurious
        // [none] latched offline and blocked every bet target for the rest of the session.
        if (_isOffline) {
          NetworkConnectivityService().checkConnection().then((hasNetwork) {
            if (hasNetwork && mounted) _updateOfflineState(platformOnline: true);
          });
        }

        _debounceTimer?.cancel();
        _spinFallbackTimer?.cancel();
        _spinController.stop();
        _spinController.reset();

        GameRecoveryService().clearBetState();

        setState(() {
          _walletManager.onRoundStart();
          _currentBets = {};
          _betClickCounts = {};
          _confirmedBets = {};
          _confirmedRoundId = null;
          _settledRoundId = null;
          _settlingRoundIds.clear();
          _submittedSpinResult = null;
          _isAutoSubmitting = false;
          _hasPendingAdditionalBets = false;
          _hasSpunForRound = null;
          _hasStartedFallbackCall = false;
          _hasShownResultForRound = null;
          _hasTriggeredSpinSyncForRound = null;
          _isProcessingSpin = false;
          _isSpinning = false;
          _spinAnimation = null;
          _optimisticWinnings = 0;
          _currentSpinOutcome = null;
          _pendingRoundResult = null;
          _hasPendingResult = false;
          _resultPendingRoundId = null;
          _resultLock = false;
          _spinCompleted = false;
          _showRoundTransition = false;
          // STRICT ROLLOVER CLEANUP: previous round results must NEVER leak into the new round
          _lastRoundResultForHistory = null;
          _lastRoundWager = 0;
          _lastRoundPrize = 0;
          _storedWinItem = null;
          _storedPrize = 0;
          _storedWager = 0;
          _storedRoundId = '';
        });

        ref.invalidate(luckySpinStatsProvider);
        _notifyHistoryUpdate();
        // Watch the new round's authoritative doc from the moment it opens.
        _subscribeToRealtimeRoundState();
        _syncServerRoundClock();
      }
      _lastCalculatedRound = currentRoundVal;

      // Batch all state changes into a single setState
      bool needsBuild = false;
      String newCountdownLabel = _countdownLabel;
      int newCountdown = _countdown;
      bool newBetLocked = _isBetLocked;
      bool newShowTransition = _showRoundTransition;
      int newTransitionCountdown = _roundTransitionCountdown;
      SpinGameState newGameState = _gameState;

      // Round transition countdown (last 3 seconds before next round: 37s, 38s, 39s)
      final transitionStart = serverBettingPhaseSec + serverSpinPhaseSec + 2; // 37s
      if (secondsIntoCycle >= transitionStart && secondsIntoCycle < serverRoundDurationMs ~/ 1000) {
        _dismissBottomSheet();
        final remaining = (serverRoundDurationMs ~/ 1000) - secondsIntoCycle;
        if (remaining <= 3 && remaining >= 1) {
          if (!newShowTransition) {
            newShowTransition = true;
            needsBuild = true;
          }
          if (remaining != newTransitionCountdown) {
            newTransitionCountdown = remaining;
            needsBuild = true;
          }
        }
      } else {
        if (newShowTransition) {
          newShowTransition = false;
          needsBuild = true;
        }
      }

      // PHASE-AWARE COUNTDOWN & STATE SYNCHRONIZATION
      // 0s-25s: Betting Open ("Select time", 30->6s)
      // 25s-30s: Bets Closed ("BETS CLOSED", 5->1s, lock bets)
      // 30s-35s: Spinning ("Spinning", 0s, lock bets)
      // 35s-37s: Winning & Results ("Winning", lock bets)
      // 37s-40s: Rollover ("Next Round", 3->1s, lock bets)

      // Total betting time: 30s
      // 0s-26s: Betting allowed ("Select time", 30->4s)
      // 27s-29s: Bets locked during final 3s ("BETS CLOSED", 3->1s)
      // 30s-35s: Spinning ("Spinning", 0s)
      // 35s-37s: Winning & Results ("Winning")
      // 37s-40s: Rollover ("Next Round", 3->1s)

      if (secondsIntoCycle < 27) {
        newBetLocked = false;
        newGameState = SpinGameState.betting;
        newCountdown = 30 - secondsIntoCycle;
        newCountdownLabel = "Select time";
      } else if (secondsIntoCycle >= 27 && secondsIntoCycle < 30) {
        if (!newBetLocked) {
          debugPrint('[SPIN_WHEEL_EVENT] 🔒 Phase 1b: BETS CLOSED at 27s (3s remaining in round $_currentRoundId, locking & auto-submitting)');
        }
        newBetLocked = true;
        newGameState = SpinGameState.betting;
        newCountdown = 30 - secondsIntoCycle;
        newCountdownLabel = "BETS CLOSED";
        _debounceTimer?.cancel();
        if (!_isAutoSubmitting) {
          if (_hasUnconfirmedBets()) {
            _autoSubmitBets();
          } else if (!_hasPendingResult && !_hasStartedFallbackCall) {
            _hasStartedFallbackCall = true;
            _preFetchRoundOutcome();
          }
        }
      } else if (secondsIntoCycle >= 30 && secondsIntoCycle < 35) {
        newBetLocked = true;
        newGameState = SpinGameState.spinning;
        newCountdown = 0;
        newCountdownLabel = "Spinning";
        if (!_isAutoSubmitting && _hasUnconfirmedBets()) {
          _autoSubmitBets();
        }
      } else if (secondsIntoCycle >= 35 && secondsIntoCycle < 37) {
        newBetLocked = true;
        newGameState = SpinGameState.results;
        newCountdown = 40 - secondsIntoCycle;
        newCountdownLabel = "Winning";
      } else {
        newBetLocked = true;
        newGameState = SpinGameState.results;
        newCountdown = 40 - secondsIntoCycle;
        newCountdownLabel = "Next Round";
      }

      if (newCountdown != _countdown || newCountdownLabel != _countdownLabel || newBetLocked != _isBetLocked) {
        needsBuild = true;
        if (newCountdown <= 5 && newCountdown > 0 && !_isBetLocked) {
          _playCountdownTick();
        }
      }

      // PHASE 1: BETTING / IDLE
      if (secondsIntoCycle < serverBettingPhaseSec) {
        // HARD ENFORCEMENT: Bottom sheet and past stored results MUST NEVER exist during betting!
        if (_isBottomSheetOpen || _bottomSheetContext != null || _bottomSheetRoute != null) {
          _dismissBottomSheet();
        }
        if (_storedWinItem != null) {
          _clearStoredResult();
        }

        if (_gameState != SpinGameState.betting && !_isSpinning) {
          debugPrint('[SPIN_WHEEL_EVENT] 🟢 Entering Phase 1: BETTING OPEN (roundId: $_currentRoundId, secIntoCycle: $secondsIntoCycle, remaining: ${serverBettingPhaseSec - secondsIntoCycle}s)');
          newGameState = SpinGameState.betting;
          _spinCompleted = false;
          _playPhaseSound(SpinGameState.betting);
          _idleController.repeat();
          needsBuild = true;
        }
      }
      // PHASE 2: SPINNING PHASE
      else if (secondsIntoCycle >= serverBettingPhaseSec && secondsIntoCycle < serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.spinning && !_isSpinning && _hasSpunForRound != _currentRoundId) {
          debugPrint('[SPIN_WHEEL_EVENT] 🌀 Entering Phase 2: SPINNING (roundId: $_currentRoundId, msIntoCycle: $msIntoCycle)');
          newGameState = SpinGameState.spinning;
          needsBuild = true;
        }

        if (_hasSpunForRound != _currentRoundId && !_isSpinning && !_isProcessingSpin) {
          Map<String, dynamic>? availableOutcome;
          if (_hasPendingResult && _pendingRoundResult != null && _resultPendingRoundId == _currentRoundId) {
            availableOutcome = Map<String, dynamic>.from(_pendingRoundResult!);
            if (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId) {
              if (_submittedSpinResult!['bets'] != null) {
                availableOutcome['bets'] = _submittedSpinResult!['bets'];
              }
              if (_submittedSpinResult!['totalBet'] != null) {
                availableOutcome['totalBet'] = _submittedSpinResult!['totalBet'];
              }
            }
          } else if (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId) {
            availableOutcome = Map<String, dynamic>.from(_submittedSpinResult!);
          } else {
            final stats = ref.read(luckySpinStatsProvider).value;
            if (stats?['lastGlobalRound']?.toString() == _currentRoundId && stats?['lastGlobalOutcome'] != null) {
              final rawOutcome = stats?['lastGlobalOutcome'];
              availableOutcome = rawOutcome is Map ? Map<String, dynamic>.from(rawOutcome) : null;
            }
          }

          if (availableOutcome != null && availableOutcome['outcome'] is Map) {
            availableOutcome.addAll(Map<String, dynamic>.from(availableOutcome['outcome'] as Map));
          }

          // If no outcome is available yet at the 30s betting close, wait for the
          // authoritative outcome from the game_rounds doc subscription or the
          // _preFetchRoundOutcome server fetch. NEVER fabricate a client-side outcome
          // (it would disagree with the server-seeded RNG and break payout/settlement).
          if (availableOutcome != null) {
            _hasSpunForRound = _currentRoundId;
            _hasPendingResult = false;
            _startSpin(availableOutcome);
          } else if (_hasTriggeredSpinSyncForRound != _currentRoundId) {
            _hasTriggeredSpinSyncForRound = _currentRoundId;
            debugPrint('[SPIN_WHEEL_EVENT] ⚡ Outcome not ready at ${secondsIntoCycle}s into round $_currentRoundId, triggering immediate server sync...');
            _syncServerRoundClock();
          }
        }
      }
      // PHASE 3: RESULTS CELEBRATION
      else if (secondsIntoCycle >= serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.results && !_isSpinning && !_spinController.isAnimating) {
          debugPrint('[SPIN_WHEEL_EVENT] 🏆 Entering Phase 3: RESULTS CELEBRATION (roundId: $_currentRoundId, secIntoCycle: $secondsIntoCycle)');
          newGameState = SpinGameState.results;
          needsBuild = true;
          _walletManager.exitBettingPhaseAndApplyDeferredCredits();
          _checkAndRecoverUnsettledRounds();
        }

        // Show stored result from spin animation ONLY when animation has completely finished!
        if (_storedWinItem != null && !_isSpinning && !_spinController.isAnimating && _hasShownResultForRound != _currentRoundId) {
          _showStoredResult();
        }

        // Late Join / Spectator Catch-up: ONLY when animation is not animating
        if (!_resultLock && !_isSpinning && !_spinController.isAnimating && _storedWinItem == null && _hasShownResultForRound != _currentRoundId) {
          Map<String, dynamic>? outcome;
          if (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId) {
            outcome = _submittedSpinResult;
          } else if (_hasPendingResult && _resultPendingRoundId == _currentRoundId) {
            outcome = _pendingRoundResult;
          } else {
            final statsAsync = ref.read(luckySpinStatsProvider);
            final stats = statsAsync.value;
            final lastGlobalRound = stats?['lastGlobalRound']?.toString();
            if (lastGlobalRound == _currentRoundId) {
              final rawOutcome = stats?['lastGlobalOutcome'];
              outcome = rawOutcome is Map ? Map<String, dynamic>.from(rawOutcome) : null;
            }
          }

          if (outcome != null) {
            final resultSettings = ref.read(gameSettingsProvider).value;
            final segmentsMap = (resultSettings?['segments'] as List? ?? []);
            
            // Default to spectator
            int prize = 0;
            int wager = 0;
            Map<String, int>? betsCopy;

            final int targetIdx = resolveTargetSectorIndex(outcome, segmentsMap);
            final matchingSegment = (targetIdx >= 0 && targetIdx < segmentsMap.length)
                ? segmentsMap[targetIdx]
                : (segmentsMap.isNotEmpty ? segmentsMap.first : {});

            final resultName = outcome['name'] as String? ?? matchingSegment['name'] ?? "";
            final resultEmoji = outcome['emoji'] as String? ?? matchingSegment['emoji'] ?? "";
            final resultCategory = outcome['category'] as String? ?? matchingSegment['category'];

            final winMultiplier = (outcome['multiplier'] as num?)?.toInt() ??
                (matchingSegment['multiplier'] as num?)?.toInt() ??
                5;

            final roundIdVal = outcome['roundId']?.toString() ?? _currentRoundId ?? '';
            final sessionTicket = _sessionRoundsHistory[roundIdVal];

            // Authoritative Bet & Prize resolution for celebration catch-up:
            final Map<String, int> activeBets = {};
            if (sessionTicket != null && sessionTicket['bets'] is Map) {
              for (final entry in (sessionTicket['bets'] as Map).entries) {
                final k = entry.key.toString();
                final v = (entry.value as num?)?.toInt() ?? 0;
                if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
              }
            }
            // Round guard: only merge the server receipt if it belongs to THIS
            // round. A stale _submittedSpinResult from a previous winning round
            // otherwise resurrects its bets during spectator catch-up and
            // recordPendingCredit credits a prize the server never paid
            // (observed: phantom spin_win_44778760 +100k).
            if (_submittedSpinResult != null &&
                _submittedSpinResult!['roundId']?.toString() == roundIdVal &&
                _submittedSpinResult!['bets'] is Map) {
              for (final entry in (_submittedSpinResult!['bets'] as Map).entries) {
                final k = entry.key.toString();
                final v = (entry.value as num?)?.toInt() ?? 0;
                if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
              }
            }
            if (_confirmedRoundId == roundIdVal) {
              for (final entry in _confirmedBets.entries) {
                if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
              }
            }
            for (final entry in _currentBets.entries) {
              if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
            }

            if (activeBets.isNotEmpty) {
              wager = activeBets.values.fold(0, (sum, val) => sum + val);
              betsCopy = Map<String, int>.from(activeBets);
              final localPrize = calculateSpinWheelPrize(
                bets: activeBets,
                winningName: matchingSegment['name'] ?? resultName,
                winningCategory: resultCategory ?? matchingSegment['category'],
                roundType: outcome['type'] as String? ?? 'standard',
                multiplier: winMultiplier,
              );
              final serverPrize = (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId)
                  ? ((_submittedSpinResult!['prize'] as num?)?.toInt() ?? 0)
                  : ((sessionTicket?['prize'] as num?)?.toInt() ?? 0);
              prize = math.max(serverPrize, localPrize);
              if (prize > 0) {
                _walletManager.recordPendingCredit(
                  txnId: 'spin_win_$roundIdVal',
                  amount: prize,
                  roundId: roundIdVal,
                );
                // Outside any enclosing setState in this late-join path: notify
                // explicitly so the Current Amount repaints immediately, not on
                // the next countdown tick.
                _notifyHistoryUpdate();
              }
            } else {
              // Spectator with no bets placed in this round:
              // Strictly ensure 0 wager and 0 prize. UI must NEVER infer a wallet credit or winning state!
              prize = 0;
              wager = 0;
              betsCopy = null;
            }

            final winningItem = SpinItem(
              name: resultName.isNotEmpty ? resultName : (matchingSegment['name'] ?? ""),
              multiplier: winMultiplier,
              emoji: (resultEmoji.isNotEmpty && resultEmoji != '🎰') ? resultEmoji : ((matchingSegment['emoji'] != null && matchingSegment['emoji'] != '🎰') ? matchingSegment['emoji'] : _getFoodEmoji(resultName.isNotEmpty ? resultName : (matchingSegment['name'] ?? ''))),
              category: resultCategory ?? matchingSegment['category']
            );

            final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];

            _hasSpunForRound = _currentRoundId;
            _currentSegment = targetIdx;
            _pointerAngle = (targetIdx * (2 * math.pi / (segmentsMap.length > 0 ? segmentsMap.length : 8))) - (math.pi / 2);
            _spinCompleted = true;
            _lastRoundWager = wager;
            _lastRoundPrize = prize;
            _lastRoundResultForHistory = {
              'roundId': roundIdVal,
              'name': winningItem.name,
              'emoji': winningItem.emoji,
              'label': '${winningItem.multiplier}x',
              'multiplier': winningItem.multiplier,
            };
            _recordRoundOutcomeForRecentResults(outcome);
            _resultLock = true;
            _hasPendingResult = false;
            _currentBets = {};
            _betClickCounts = {};
            _confirmedBets = {};
            _confirmedRoundId = null;
            _hasPendingAdditionalBets = false;

            if (activeBets.isNotEmpty && roundIdVal.isNotEmpty) {
              _executeRoundSettlement(
                roundId: roundIdVal,
                effectiveTotalBet: wager,
                isCatchUp: true,
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 _showResultBottomSheet(
                   context,
                   winningItem,
                   prize,
                   wager,
                   roundWinners,
                   roundIdVal,
                   bets: betsCopy,
                 );
               }
             });
          }
        }
      }

      // Single batched setState for all countdown updates
      if (needsBuild || newGameState != _gameState || newCountdown != _countdown || newCountdownLabel != _countdownLabel || newBetLocked != _isBetLocked || newShowTransition != _showRoundTransition || newTransitionCountdown != _roundTransitionCountdown) {
        if (newGameState != _gameState) {
          if (newGameState == SpinGameState.betting) {
            _walletManager.enterBettingPhase();
          } else if (newGameState == SpinGameState.spinning) {
            _walletManager.exitBettingPhase();
          } else if (newGameState == SpinGameState.results) {
            _walletManager.exitBettingPhaseAndApplyDeferredCredits();
          }
        }
        setState(() {
          _gameState = newGameState;
          _countdown = newCountdown;
          _countdownLabel = newCountdownLabel;
          _isBetLocked = newBetLocked;
          _showRoundTransition = newShowTransition;
          _roundTransitionCountdown = newTransitionCountdown;
        });
      }
    });
  }

  void _handleSpin() async {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;

    if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
      if (mounted) {
        _showConnectionNotFoundDialog();
      }
      return;
    }
    
    _isProcessingSpin = true;
    _isSpinning = true;
    _isBetLocked = true;

    // If _autoSubmitBets is currently in flight, wait for it to finish
    if (_isAutoSubmitting) {
      int retries = 0;
      while (_isAutoSubmitting && retries < 30 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
    }

    if (!mounted) return;

    // Check if _autoSubmitBets already successfully obtained the result for this round!
    if (_submittedSpinResult != null) {
      final resRoundId = _submittedSpinResult!['roundId']?.toString();
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final currentRoundId = (now ~/ serverRoundMs).toString();

      if (resRoundId == currentRoundId || resRoundId == null) {
        final result = _submittedSpinResult!;
        _idleController.stop();
        _idleController.reset();
        _tickTimer?.cancel();
        GameRecoveryService().clearBetState();
        _startSpin(result);
        return;
      }
    }

    final wallet = ref.read(walletBalanceProvider).value;
    final diamonds = _currentAuthoritativeDiamonds;
    final beans = wallet?['beans'] ?? 0;

    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    final confirmedTotalBet = _confirmedBets.values.fold(0, (sum, val) => sum + val);
    final pendingUnconfirmedBet = math.max(0, totalBet - confirmedTotalBet);

    if (pendingUnconfirmedBet > 0) {
      // displayedBalance (diamonds) already subtracts pending debits, so
      // comparing it against pendingUnconfirmedBet double-counts and falsely
      // rejects. Affordability uses CONFIRMED balance (before pending debits).
      final confirmedPower = _walletManager.confirmedBalance + (beans * 2 / 7).floor();
      if (confirmedPower < pendingUnconfirmedBet) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Diamonds & Stars")));
         setState(() {
           _isSpinning = false;
           _isBetLocked = false;
           _isProcessingSpin = false;
         });
         return;
      }
    }

    setState(() {
      _gameState = SpinGameState.spinning;
      _playPhaseSound(SpinGameState.spinning);
    });

    _idleController.stop();
    _idleController.reset();

    // Start fast Dummy Spin while waiting for network (throttled to prevent catch-up storm)
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_isSpinning) {
        _tickTimer?.cancel();
        return;
      }
      setState(() {
        _currentSegment = (_currentSegment + 1) % 8;
      });
    });

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: _currentBets,
        roomId: widget.roomId,
      );
      
      if (!mounted) return;

      
      _tickTimer?.cancel(); // Stop dummy spin
      GameRecoveryService().clearBetState();
      _startSpin(result);

    } catch (e) {
      _tickTimer?.cancel();
      _spinCompleted = false;
      if (mounted) {
        final hadBet = _currentBets.values.fold(0, (sum, val) => sum + val) > 0;
        setState(() {
          _isSpinning = false;
          _isProcessingSpin = false;
          if (hadBet) {
            // Failure happened during bet submission. Clear bet input so user becomes spectator,
            // and clear hasSpun/hasStartedFallback flags so spectator periodic-tick can retry.
            _gameState = SpinGameState.spinning;
            _isBetLocked = true;
            _currentBets = {};
            _betClickCounts = {};
            _hasSpunForRound = null;
            _hasStartedFallbackCall = false;
            GameRecoveryService().clearBetState();
          } else {
            _gameState = SpinGameState.betting;
            _isBetLocked = false;
          }
        });
        
        // If network issue, show dedicated connection dialog
        if (hadBet) {
          final errorStr = e.toString();
          if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline || errorStr.contains('network') || errorStr.contains('unavailable') || errorStr.contains('deadline-exceeded')) {
            _showConnectionNotFoundDialog();
          }
        }
      }
    }
  }

  void _startSpin(Map<String, dynamic> outcome) {
    if (!mounted) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;

    // GATING GUARD: Wheel animation MUST NOT launch before 30.0s!
    if (secondsIntoCycle < 30) {
      debugPrint('[SPIN_GAME_LOG] ⏳ Outcome pre-cached in memory at ${secondsIntoCycle}s into round ${outcome['roundId']}. Waiting for 30s spinning phase...');
      return;
    }

    final outcomeRoundId = outcome['roundId']?.toString();
    final activeRoundId = (now ~/ serverRoundMs).toString();

    // Stale Round Guard: If this result belongs to a past round, do NOT disrupt the new round!
    if (outcomeRoundId != null && outcomeRoundId != activeRoundId) {
      debugPrint('[SPIN_GAME_LOG] ⚠️ Discarded stale spin outcome from past round: $outcomeRoundId (current: $activeRoundId)');
      setState(() {
        _isSpinning = false;
        _isProcessingSpin = false;
        _gameState = (secondsIntoCycle < 30) ? SpinGameState.betting : SpinGameState.spinning;
        _isBetLocked = (secondsIntoCycle >= 20);
      });
      return;
    }

    _tickTimer?.cancel();
    _idleController.stop();
    _idleController.reset();
    ScaffoldMessenger.of(context).clearSnackBars();

    final Map<String, dynamic> effOutcome = (outcome['outcome'] is Map)
        ? Map<String, dynamic>.from(outcome['outcome'] as Map)
        : Map<String, dynamic>.from(outcome);
    if (outcome['roundId'] != null && effOutcome['roundId'] == null) {
      effOutcome['roundId'] = outcome['roundId'];
    }
    _currentSpinOutcome = effOutcome;

    final settings = ref.read(gameSettingsProvider).value;
    final segmentsMap = (settings?['segments'] as List? ?? []);
    final int targetIdx = resolveTargetSectorIndex(effOutcome, segmentsMap);
    final int startIdx = _currentSegment;

    // Calculate dynamic spin duration based on time left in 30s-35s phase
    final msIntoCycle = now % serverRoundMs;
    int remainingSpinMs = 35000 - msIntoCycle;
    if (remainingSpinMs < 1200) {
      remainingSpinMs = 1200; // Minimum 1.2s so the user sees a smooth finish
    } else if (remainingSpinMs > 4500) {
      remainingSpinMs = 4500;
    }

    final int distance = (targetIdx - (startIdx % 8) + 8) % 8;
    final int fullRotations = remainingSpinMs > 2500 ? 4 : 2;
    final double totalSegmentSteps = (fullRotations * 8 + distance).toDouble();

    final double startVal = startIdx.toDouble();
    final double targetVal = startVal + totalSegmentSteps;

    _spinAnimation = Tween<double>(
      begin: startVal,
      end: targetVal,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.easeOutCubic,
      ),
    );

    setState(() {
      _isSpinning = true;
      _isBetLocked = true;
      _gameState = SpinGameState.spinning;
    });

    _playPhaseSound(SpinGameState.spinning);
    debugPrint('[SPIN_WHEEL_EVENT] 🎡 Starting Hardware-Accelerated Spin: roundId=$outcomeRoundId, startIdx=$startIdx, targetIdx=$targetIdx, duration=${remainingSpinMs}ms');

    _spinController.duration = Duration(milliseconds: remainingSpinMs);
    _spinController.forward(from: 0.0);
  }

  void _executeRoundSettlement({
    required String roundId,
    required int effectiveTotalBet,
    required bool isCatchUp,
  }) {
    if (roundId.isEmpty || effectiveTotalBet <= 0) return;
    if (_settledRoundId == roundId || _settlingRoundIds.contains(roundId)) return;

    _settlingRoundIds.add(roundId);
    final requestSeq = ++_balanceSeq;
    debugPrint('[SPIN_WHEEL_EVENT] 📡 Requesting backend round settlement: roundId=$roundId, bet=$effectiveTotalBet, isCatchUp=$isCatchUp');

    ref.read(gameServiceProvider).settleSpinWheelRound(roundId: roundId).then((result) {
      if (mounted) {
        _settlingRoundIds.remove(roundId);
        _settledRoundId = roundId;
        final serverPrize = (result['prize'] as num?)?.toInt() ?? 0;
        final serverBal = (result['balance'] as num?)?.toInt();
        final serverTotalBet = (result['totalBet'] as num?)?.toInt();
        final serverSeq = (result['seq'] as num?)?.toInt() ?? requestSeq;
        final txnId = result['txnId'] as String? ?? 'spin_win_$roundId';
        debugPrint('[SPIN_WHEEL_EVENT] 🏆 Round $roundId settled: prize=$serverPrize, balance=$serverBal, totalBet=$serverTotalBet, seq=$serverSeq');
        _recordSessionSettle(
          roundId: roundId,
          prize: serverPrize,
          balanceAfter: serverBal,
          totalBet: serverTotalBet,
        );
        setState(() {
          _storedPrize = serverPrize;
          _optimisticWinnings = 0;
          final isCurrentRound = roundId == _currentRoundId;
          final effectiveBal = serverBal ?? (serverPrize > 0 ? (_walletManager.confirmedBalance + serverPrize) : _walletManager.confirmedBalance);
          _walletManager.reconcileSettlement(
            txnId: txnId,
            serverBalance: effectiveBal,
            serverSeq: serverSeq,
            prize: serverPrize,
            roundId: roundId,
            userHadAcceptedBet: effectiveTotalBet > 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            isPastRound: !isCurrentRound,
          );
        });
        ref.invalidate(luckySpinLeaderboardProvider);
        ref.invalidate(luckySpinStatsProvider);
        ref.invalidate(transactionStreamProvider);
        _notifyHistoryUpdate();
      }
    }).catchError((err) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Settle round $roundId failed: $err. Will retry.');
      if (mounted) {
        _settlingRoundIds.remove(roundId);
        Timer(const Duration(seconds: 2), () {
          if (mounted && _settledRoundId != roundId && !_settlingRoundIds.contains(roundId)) {
            _executeRoundSettlement(
              roundId: roundId,
              effectiveTotalBet: effectiveTotalBet,
              isCatchUp: isCatchUp,
            );
          }
        });
      }
    });
  }

  void _checkAndRecoverUnsettledRounds() {
    if (!mounted) return;
    for (final entry in _sessionRoundsHistory.entries) {
      final roundId = entry.key;
      final ticket = entry.value;
      final isSettled = ticket['settled'] == true;
      final totalBet = (ticket['totalBet'] as num?)?.toInt() ?? 0;
      if (!isSettled && totalBet > 0 && roundId.isNotEmpty) {
        debugPrint('[SPIN_WHEEL_EVENT] 🔄 Auto-recovering unsettled round $roundId (wager: $totalBet)');
        _executeRoundSettlement(
          roundId: roundId,
          effectiveTotalBet: totalBet,
          isCatchUp: true,
        );
      }
    }
  }

  void _handleDecelerationComplete() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final rawOutcome = _currentSpinOutcome;
    if (rawOutcome == null) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Deceleration complete without active outcome.');
      setState(() {
        _isSpinning = false;
        _isProcessingSpin = false;
      });
      return;
    }

    final outcome = (rawOutcome['outcome'] is Map)
        ? Map<String, dynamic>.from(rawOutcome['outcome'] as Map)
        : rawOutcome;
    final roundId = outcome['roundId']?.toString() ?? rawOutcome['roundId']?.toString() ?? _currentRoundId ?? "";
    final settings = ref.read(gameSettingsProvider).value;
    final segmentsMap = (settings?['segments'] as List? ?? []);

    final int targetIdx = resolveTargetSectorIndex(outcome, segmentsMap);

    // Authoritative Bet & Prize resolution:
    final bool hasServerResult = _submittedSpinResult != null &&
        roundId.isNotEmpty &&
        _submittedSpinResult!['roundId']?.toString() == roundId;

    // Authoritative Bet & Prize resolution:
    // Merge all bets across session history, server receipt, confirmed state, and local bets
    final sessionTicket = _sessionRoundsHistory[roundId];
    final Map<String, int> activeBets = {};
    if (sessionTicket != null && sessionTicket['bets'] is Map) {
      for (final entry in (sessionTicket['bets'] as Map).entries) {
        final k = entry.key.toString();
        final v = (entry.value as num?)?.toInt() ?? 0;
        if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
      }
    }
    if (_submittedSpinResult != null &&
        hasServerResult &&
        _submittedSpinResult!['bets'] is Map) {
      for (final entry in (_submittedSpinResult!['bets'] as Map).entries) {
        final k = entry.key.toString();
        final v = (entry.value as num?)?.toInt() ?? 0;
        if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
      }
    }
    if (_confirmedRoundId == roundId) {
      for (final entry in _confirmedBets.entries) {
        if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
      }
    }
    for (final entry in _currentBets.entries) {
      if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
    }

    final bool hasConfirmedBet = hasServerResult || activeBets.isNotEmpty || (sessionTicket != null && (sessionTicket['totalBet'] ?? 0) > 0);

    final totalBet = activeBets.values.fold(0, (sum, val) => sum + val);
    final effectiveTotalBet = totalBet > 0
        ? totalBet
        : (hasServerResult
            ? ((_submittedSpinResult?['totalBet'] as num?)?.toInt() ?? 0)
            : ((sessionTicket?['totalBet'] as num?)?.toInt() ?? 0));

    final betsCopy = activeBets.isNotEmpty
        ? Map<String, int>.from(activeBets)
        : (_submittedSpinResult?['bets'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            (sessionTicket?['bets'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));

    final matchingSegment = (targetIdx >= 0 && targetIdx < segmentsMap.length)
        ? segmentsMap[targetIdx]
        : (segmentsMap.isNotEmpty ? segmentsMap.first : {});

    final resultName = outcome['name'] as String? ?? matchingSegment['name'] ?? "";
    final resultEmoji = outcome['emoji'] as String? ?? matchingSegment['emoji'] ?? "";
    final resultCategory = outcome['category'] as String? ?? matchingSegment['category'];
    final type = outcome['type'] as String? ?? "standard";

    final itemMultiplier = (outcome['multiplier'] as num?)?.toInt() ??
        (matchingSegment['multiplier'] as num?)?.toInt() ??
        5;

    final winningItem = SpinItem(
      name: resultName.isNotEmpty ? resultName : (matchingSegment['name'] ?? ""),
      multiplier: itemMultiplier,
      emoji: (resultEmoji.isNotEmpty && resultEmoji != '🎰') ? resultEmoji : ((matchingSegment['emoji'] != null && matchingSegment['emoji'] != '🎰') ? matchingSegment['emoji'] : _getFoodEmoji(resultName.isNotEmpty ? resultName : (matchingSegment['name'] ?? ''))),
      category: resultCategory ?? matchingSegment['category'],
    );

    // AUTHORITATIVE PRIZE:
    // 1. Calculate prize from activeBets
    // 2. If server has a higher prize (e.g. jackpot bonuses), use the max
    int effectivePrize = 0;
    if (hasConfirmedBet && effectiveTotalBet > 0) {
      effectivePrize = calculateSpinWheelPrize(
        bets: activeBets,
        winningName: winningItem.name,
        multiplier: itemMultiplier,
      );
    }

    final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];

    setState(() {
      _spinCompleted = true;
      _currentSegment = targetIdx;
      _pointerAngle = (targetIdx * (2 * math.pi / 8)) - (math.pi / 2);
      _isSpinning = false;
      _isProcessingSpin = false;
      _spinAnimation = null;
      _optimisticWinnings = 0; // Winnings are credited only after authoritative backend settlement confirms!

      if (effectiveTotalBet > 0) {
        _todayProfits += (effectivePrize - effectiveTotalBet);
      }

      // Immediately credit winning amount right after round result is revealed so player sees instant increase animation!
      if (effectivePrize > 0) {
        _walletManager.recordPendingCredit(
          txnId: 'spin_win_$roundId',
          amount: effectivePrize,
          roundId: roundId,
        );
      }

      _currentBets = {};
      _betClickCounts = {};
      _confirmedBets = {};
      _confirmedRoundId = null;

      _storedWinItem = winningItem;
      _storedPrize = effectivePrize;
      _storedWager = effectiveTotalBet;
      _lastRoundWager = effectiveTotalBet;
      _lastRoundPrize = effectivePrize;
      _storedWinners = roundWinners;
      _storedRoundId = roundId;
      _storedBets = betsCopy;
      _resultLock = true;
      _lastRoundResultForHistory = {
        'roundId': roundId,
        'name': winningItem.name,
        'emoji': winningItem.emoji,
        'label': '${winningItem.multiplier}x',
        'multiplier': winningItem.multiplier,
      };
      _notifyHistoryUpdate();
    });

    _recordRoundOutcomeForRecentResults({
      'roundId': roundId,
      'name': winningItem.name,
      'emoji': winningItem.emoji,
      'label': '${winningItem.multiplier}x',
      'multiplier': winningItem.multiplier,
      'category': winningItem.category,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _playPhaseSound(SpinGameState.results);
    _walletManager.exitBettingPhaseAndApplyDeferredCredits();

    // Provide haptic feedback upon wheel coming to a stop
    if (effectivePrize > 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    // Authoritative Prize Calculation: Compute canonical payout immediately so winning rounds
    // are instantly recorded with full winnings in session history and never defaulted to 0.
    final localPrize = calculateSpinWheelPrize(
      bets: betsCopy ?? {},
      winningName: winningItem.name,
      multiplier: winningItem.multiplier,
    );
    _recordSessionResult(
      roundId: roundId,
      winningItem: winningItem,
      prize: localPrize,
      totalBet: effectiveTotalBet,
      bets: betsCopy ?? {},
    );

    ref.invalidate(luckySpinLeaderboardProvider);
    ref.invalidate(luckySpinStatsProvider);
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(transactionStreamProvider);
    _notifyHistoryUpdate();

    if (hasConfirmedBet && effectiveTotalBet > 0 && roundId.isNotEmpty) {
      _executeRoundSettlement(
        roundId: roundId,
        effectiveTotalBet: effectiveTotalBet,
        isCatchUp: false,
      );
    }

    final nowMs = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final msIntoCycle = nowMs % serverRoundMs;
    final activeRoundId = (nowMs ~/ serverRoundMs).toString();

    debugPrint('[SPIN_WHEEL_EVENT] 🎯 Hardware-Accelerated Wheel Landed: sector=$targetIdx, item=${winningItem.name}, prize=$effectivePrize, wager=$effectiveTotalBet');

    // Strict Guard: Complete winning animation on the target pod before showing results
    // User requirement: 
    // 1. 30s betting time ends
    // 2. Winning animation starts
    // 3. Winning animation completes fully
    // 4. Only after the animation is finished, the winning result should be displayed
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      final currentNowMs = _synchronizedTimeMs;
      final currentMs = currentNowMs % serverRoundMs;
      final curRound = (currentNowMs ~/ serverRoundMs).toString();
      if (_hasShownResultForRound != roundId && roundId == curRound && currentMs >= 32000 && currentMs < 38500) {
        debugPrint('[SPIN_WHEEL_EVENT] 📜 Winning animation completed fully. Triggering Result Bottom Sheet for round $roundId');
        _showStoredResult();
      } else if (roundId != curRound || currentMs >= 38500) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed bottom sheet after wheel spin (roundId: $roundId, active: $curRound, msIntoCycle: $currentMs)');
        _clearStoredResult();
      }
    });
  }

  void _dismissBottomSheet() {
    if (!_isBottomSheetOpen && _bottomSheetRoute == null) return;
    _isBottomSheetOpen = false;
    final route = _bottomSheetRoute;
    _bottomSheetRoute = null;
    _bottomSheetContext = null;

    if (route != null && route.isActive) {
      try {
        if (route.isCurrent) {
          route.navigator?.pop();
          debugPrint('[SPIN_WHEEL_EVENT] 🚪 Dismissed open result bottom sheet via route.navigator.pop()');
        } else {
          route.navigator?.removeRoute(route);
          debugPrint('[SPIN_WHEEL_EVENT] 🚪 Dismissed open result bottom sheet via route.navigator.removeRoute()');
        }
      } catch (e) {
        debugPrint("⚠️ SpinWheel: Error removing bottom sheet route: $e");
      }
    }
  }

  void _showStoredResult() {
    if (_storedWinItem != null && mounted) {
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final msIntoCycle = now % serverRoundMs;
      final currentRoundId = (now ~/ serverRoundMs).toString();

      // Strict Guard: ONLY show bottom sheet during Results Celebration phase (32.0s-39.0s) AND for the current round!
      if (_storedRoundId.isNotEmpty && _storedRoundId != currentRoundId) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed stale result sheet for past round $_storedRoundId (current: $currentRoundId)');
        _clearStoredResult();
        return;
      }
      if (msIntoCycle >= 39000) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed result sheet after celebration window (msIntoCycle: $msIntoCycle)');
        _clearStoredResult();
        return;
      }
      if (msIntoCycle < 32000) {
        // Spin finished slightly early; hold _storedWinItem for celebration phase
        return;
      }

      final item = _storedWinItem!;
      final prize = _storedPrize;
      final wager = _storedWager;
      final winners = _storedWinners;
      final roundId = _storedRoundId;
      final bets = _storedBets;
      _storedWinItem = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showResultBottomSheet(
            context,
            item,
            prize,
            wager,
            winners,
            roundId,
            bets: bets,
          );
        }
      });
    }
  }

  void _clearStoredResult() {
    if (_storedRoundId.isNotEmpty && (_storedPrize > 0 || _storedWager > 0)) {
      final existing = _sessionRoundsHistory[_storedRoundId] ?? {};
      final existingPrize = (existing['prize'] as num?)?.toInt() ?? 0;
      final effectivePrize = (existing['settled'] == true) ? existingPrize : _storedPrize;
      _sessionRoundsHistory[_storedRoundId] = {
        ...existing,
        'roundId': _storedRoundId,
        'totalBet': _storedWager > 0 ? _storedWager : (existing['totalBet'] ?? 0),
        if (_storedBets != null && _storedBets!.isNotEmpty) 'bets': Map<String, int>.from(_storedBets!),
        'prize': effectivePrize,
        'amount': effectivePrize,
        if (_storedWinItem != null) 'winningFood': _storedWinItem!.name,
        if (_storedWinItem != null) 'name': _storedWinItem!.name,
        if (_storedWinItem != null) 'emoji': _storedWinItem!.emoji,
        if (_storedWinItem != null) 'label': '${_storedWinItem!.multiplier}x',
        if (_storedWinItem != null) 'multiplier': '${_storedWinItem!.multiplier}x',
        'settled': true,
        'timestamp': existing['timestamp'] ?? DateTime.now(),
        'createdAt': existing['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      };
    }
    debugPrint('[SPIN_WHEEL_EVENT] 🧹 Cleared stored results for round $_storedRoundId');
    _storedWinItem = null;
    _storedPrize = 0;
    _storedWager = 0;
    _storedWinners = [];
    _storedRoundId = '';
    _storedBets = null;
    _submittedSpinResult = null;
  }

  void _showResultBottomSheet(BuildContext context, SpinItem item, int winnings, int wager, List<dynamic> winners, String roundId, {Map<String, int>? bets}) {
    if (!mounted) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final msIntoCycle = now % serverRoundMs;
    final activeRoundId = (now ~/ serverRoundMs).toString();

    // HARD GUARD: NEVER open result bottom sheet outside 32.0s - 39.0s celebration window,
    // and NEVER for a round that is not the active round!
    if (roundId != activeRoundId || msIntoCycle < 32000 || msIntoCycle >= 39000) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ BLOCKED showing result bottom sheet outside celebration window (round: $roundId, active: $activeRoundId, msIntoCycle: $msIntoCycle)');
      return;
    }

    // Authoritative Ticket Resolution: Bind directly to session history to eliminate 0/0 defaults
    final ticket = _sessionRoundsHistory[roundId];
    final int fallbackWager = _confirmedRoundId == roundId
        ? _confirmedBets.values.fold<int>(0, (int s, int v) => s + v)
        : 0;
    final int effectiveWager = wager > 0 
        ? wager 
        : ((ticket?['totalBet'] as num?)?.toInt() ?? fallbackWager);
    final int effectiveWinnings = winnings > 0
        ? winnings
        : ((ticket?['prize'] as num?)?.toInt() ?? (ticket?['amount'] as num?)?.toInt() ?? 0);
    final effectiveBets = (bets != null && bets.isNotEmpty)
        ? bets
        : (ticket?['bets'] is Map 
            ? (ticket!['bets'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())) 
            : (_confirmedRoundId == roundId && _confirmedBets.isNotEmpty ? _confirmedBets : null));

    final outcomeTitle = effectiveWager > 0 ? (effectiveWinnings > 0 ? "YOU WIN!" : "YOU LOST") : "ROUND COMPLETED";
    debugPrint('[SPIN_WHEEL_EVENT] 📜 Opening Result Sheet: roundId: $roundId, outcome: $outcomeTitle, item: ${item.name} (${item.emoji} ${item.multiplier}x), wager: $effectiveWager, winnings: $effectiveWinnings');

    // Ensure all deferred credits from round settlement are unlocked and applied to wallet
    _walletManager.exitBettingPhaseAndApplyDeferredCredits();

    // Proactively dismiss any existing bottom sheet to avoid stacking
    _dismissBottomSheet();
    ScaffoldMessenger.of(context).clearSnackBars();

    _isBottomSheetOpen = true;
    _hasShownResultForRound = roundId;
    _bottomSheetOpenTime = DateTime.now();
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (sheetContext) {
          _bottomSheetContext = sheetContext;
          _bottomSheetRoute = ModalRoute.of(sheetContext);
          return SpinWheelResultBottomSheet(
            item: item,
            winnings: effectiveWinnings,
            wager: effectiveWager,
            winners: winners,
            roundId: roundId,
            bets: effectiveBets,
            serverTimeOffset: _serverTimeOffset,
          );
        },
      ).then((_) {
        debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result Bottom Sheet Dismissed. Refreshing wallet, history, and stats.');
        _isBottomSheetOpen = false;
        _bottomSheetContext = null;
        _bottomSheetRoute = null;
        if (mounted) {
          setState(() {
            _resultLock = false;
            _spinCompleted = false;
          });
          _clearStoredResult();
          ref.invalidate(luckySpinStatsProvider);
          _notifyHistoryUpdate();
        }
      });
    } catch (e) {
      debugPrint("❌ SpinWheel: Exception showing result bottom sheet: $e");
      _isBottomSheetOpen = false;
      _bottomSheetContext = null;
      _bottomSheetRoute = null;
      if (mounted) {
        setState(() {
          _resultLock = false;
          _spinCompleted = false;
        });
        _clearStoredResult();
      }
    }
  }

  Widget _buildResultRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          value,
        ],
      ),
    );
  }

  Widget _buildWinnerItem(dynamic winner, int rank) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white10,
              backgroundImage: (winner != null && winner['photoUrl'] != null && winner['photoUrl'].isNotEmpty)
                ? NetworkImage(winner['photoUrl'])
                : null,
              child: (winner == null || winner['photoUrl'] == null || winner['photoUrl'].isEmpty)
                ? const Icon(Icons.person, color: Colors.white30)
                : null,
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
              child: Text("${rank + 1}", style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(winner?['name'] ?? "Empty", 
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumDiamond(size: 10),
            const SizedBox(width: 2),
            Text("${winner?['amount'] ?? 0}", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showRulesSheet(Map<String, dynamic> settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("GAME RULES", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24),
            _ruleItem("1. Select wager (min: ${settings['minWager']}, max: ${settings['maxWager']})."),
            _ruleItem("2. Tap the central countdown to spin."),
            _ruleItem("3. Landing on an icon grants its multiplier payout."),
            _ruleItem("4. Max win limit: ${settings['maxWinCap']} diamonds."),
            _ruleItem("5. Daily profit limit per user applies."),
            const SizedBox(height: 32),
            Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black, shape: StadiumBorder(), padding: EdgeInsets.symmetric(horizontal: 60)), child: const Text("GOT IT"))),
          ],
        ),
      ),
    );
  }

  Widget _ruleItem(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)));

  @override
  void dispose() {
    debugPrint('[SPIN_WHEEL_EVENT] 🛑 Game Screen Disposing: Cleaning up controllers, timers, and listeners.');
    _dismissBottomSheet();
    WidgetsBinding.instance.removeObserver(this);
    WakelockService().release();
    _offsetSubscription?.cancel();
    _roundDocSubscription?.cancel();
    _connectivitySub?.cancel();
    _platformConnectivitySub?.cancel();
    _debounceTimer?.cancel();
    _timer?.cancel();
    _tickTimer?.cancel();
    _spinFallbackTimer?.cancel();
    _idleController.dispose();
    _spinController.dispose();
    _historyUpdateNotifier.dispose();
    _walletManager.exitBettingPhaseAndApplyDeferredCredits();
    // Do NOT clear bet state here so accepted bets persist if user leaves the screen before round completion
    super.dispose();
  }

  void _updateOfflineState({bool? rtdbConnected, bool? platformOnline}) {
    if (rtdbConnected != null) _rtdbConnected = rtdbConnected;
    if (platformOnline != null) _platformHasNetwork = platformOnline;

    final effectiveRtdb = _rtdbConnected ?? true;
    final effectivePlatform = _platformHasNetwork;

    final wasOffline = _isOffline;
    // Platform network (WiFi / Mobile Data) is the definitive authority on network availability.
    // When platform has no network, the user is immediately offline.
    _isOffline = !_platformHasNetwork;

    if (_isOffline != wasOffline) {
      debugPrint('[SPIN_WHEEL_EVENT] 🌐 Network state changed: isOffline=$_isOffline (platform=$_platformHasNetwork, rtdb=$_rtdbConnected)');
      if (_isOffline) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Device offline: pausing unconfirmed local bets');
        _debounceTimer?.cancel();
        // Keep the staged wagers on screen. Wiping them here is what made bets "disappear"
        // on a transient offline blip; they are re-submitted by the recovery pass once the
        // network returns and the round is still open.
      } else {
        ref.invalidate(walletBalanceProvider);
        _notifyHistoryUpdate();
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(walletBalanceProvider, (prev, next) {
      final data = next.value;
      if (data != null) {
        final streamDiamonds = (data['diamonds'] as num?)?.toInt() ?? 0;
        final streamSeq = (data['seq'] as num?)?.toInt() ?? 0;
        final lastTxnId = data['lastTxnId'] as String?;
        final updated = _walletManager.updateFromStream(
          streamDiamonds: streamDiamonds,
          streamSeq: streamSeq,
          lastTxnId: lastTxnId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        if (updated && mounted) {
          setState(() {});
          _notifyHistoryUpdate();
        }
      }
    });
    final settingsAsync = ref.watch(gameSettingsProvider);
    final statsAsync = ref.watch(luckySpinStatsProvider);
    final historyAsync = ref.watch(userGameHistoryProvider);

    final bool canPopScreen = _bottomSheetRoute == null || !_bottomSheetRoute!.isActive;

    return PopScope(
      canPop: canPopScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_bottomSheetRoute != null && _bottomSheetRoute!.isActive) {
          debugPrint('[SPIN_WHEEL_EVENT] 🛡️ Pop intercepted: Dismissing bottom sheet only, preventing screen exit');
          _dismissBottomSheet();
          return;
        }
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Scaffold(
        backgroundColor: const Color(0xFFFDE047),
        extendBodyBehindAppBar: true,
        body: settingsAsync.when(
          data: (settings) {
            if (!settings['isActive']) return _buildMaintenanceScreen();

            final rawSegments = settings['segments'];
            final segmentsList = rawSegments is List ? rawSegments : [];
            final items = segmentsList.whereType<Map>().map((s) {
              final name = s['name']?.toString() ?? '';
              final mult = (s['multiplier'] as num?)?.toInt() ?? int.tryParse(s['multiplier']?.toString() ?? '1') ?? 1;
              final emoji = s['emoji']?.toString() ?? '🎰';
              final category = s['category']?.toString();
              return SpinItem(
                name: name,
                multiplier: mult,
                emoji: emoji,
                category: category,
              );
            }).toList();

            if (items.isEmpty) {
              items.addAll([
                SpinItem(name: 'Hotdog', multiplier: 10, emoji: '🌭', category: 'pizza'),
                SpinItem(name: 'Skewer', multiplier: 15, emoji: '🍢', category: 'pizza'),
                SpinItem(name: 'Chicken', multiplier: 25, emoji: '🍗', category: 'pizza'),
                SpinItem(name: 'Steak', multiplier: 45, emoji: '🥩', category: 'pizza'),
                SpinItem(name: 'Carrot', multiplier: 5, emoji: '🥕', category: 'salad'),
                SpinItem(name: 'Corn', multiplier: 5, emoji: '🌽', category: 'salad'),
                SpinItem(name: 'Cabbage', multiplier: 5, emoji: '🥬', category: 'salad'),
                SpinItem(name: 'Tomato', multiplier: 5, emoji: '🍅', category: 'salad'),
              ]);
            }
            _segmentCount = items.isEmpty ? 8 : items.length;

            final saladItem = items.firstWhere(
              (item) => item.name.toLowerCase().trim() == 'salad',
              orElse: () => SpinItem(name: 'Salad', multiplier: 1, emoji: ''),
            );
            final pizzaItem = items.firstWhere(
              (item) => item.name.toLowerCase().trim() == 'pizza',
              orElse: () => SpinItem(name: 'Pizza', multiplier: 1, emoji: ''),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = MediaQuery.of(context).padding.top;
                // Dynamic Scaling with compact bounds to keep bottom area clean
                final widthScale = constraints.maxWidth / 375;
                final heightScale = constraints.maxHeight / 750;
                final scale = math.min(widthScale, heightScale).clamp(0.75, 1.05);

                // 100% Dead-Center Alignment on Background Image Graphic
                final wheelScale = scale * 0.81;
                final headerTop = topPadding + (8 * scale);
                final wheelAlignmentY = -0.45;
                final bettingSectionBottom = 175.0 * scale;

                return Stack(
                  children: [
                    // 1. Full Screen Background Image
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/processed_image.webp',
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                      ),
                    ),

                    // 2. Header Elements (Top area)
                    Positioned(
                      top: headerTop,
                      left: 16 * scale,
                      right: 16 * scale,
                      child: _buildHeader(settings, _calculateCurrentRound(), scale, statsAsync.value),
                    ),

                    // 3. Main Circular Game (Compact Wheel, Shifted Upwards)
                    Align(
                      alignment: Alignment(0, wheelAlignmentY),
                      child: SizedBox(
                        width: 360 * wheelScale, height: 420 * wheelScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 360 * wheelScale, height: 420 * wheelScale,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  RepaintBoundary(
                                    child: CustomPaint(
                                      size: Size(360 * wheelScale, 420 * wheelScale), 
                                      painter: PodsPainter(
                                        items: items, 
                                        activeIndex: _currentSegment, 
                                        betClickCounts: _betClickCounts,
                                        scale: wheelScale,
                                        saladHits: statsAsync.value?['todaySaladHits'] ?? 0,
                                        pizzaHits: statsAsync.value?['todayPizzaHits'] ?? 0,
                                      ),
                                    ),
                                  ),
                                  
                                  // Salad & Pizza Buttons
                                  Positioned(
                                    bottom: -55 * wheelScale,
                                    left: 0 * wheelScale,
                                    child: GestureDetector(
                                      onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet("Salad", items),
                                      child: _buildJackpotTab("Salad", "🥗", wheelScale, _currentBets[saladItem.name] ?? 0),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -55 * wheelScale,
                                    right: 0 * wheelScale,
                                    child: GestureDetector(
                                      onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet("Pizza", items),
                                      child: _buildJackpotTab("Pizza", "🍕", wheelScale, _currentBets[pizzaItem.name] ?? 0),
                                    ),
                                  ),
                                  
                                  // Interactive Betting Pods
                                  ...List.generate(items.length, (index) {
                                    final angle = index * (2 * math.pi / items.length) - (math.pi / 2);
                                    const radiusX = 175.0;
                                    const radiusY = 175.0;
                                    final podX = math.cos(angle) * radiusX * wheelScale;
                                    final podY = math.sin(angle) * radiusY * wheelScale;
                                    final name = items[index].name;
                                    final bet = _currentBets[name] ?? 0;

                                    return Positioned(
                                      left: (180 * wheelScale) + podX - (35 * wheelScale),
                                      top: (210 * wheelScale) + podY - (40 * wheelScale),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet(name, items),
                                        child: Container(
                                          width: 70 * wheelScale, height: 80 * wheelScale,
                                          color: Colors.transparent, // Hit area
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (bet > 0)
                                                Positioned(
                                                  top: 0,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 6 * wheelScale, vertical: 2 * wheelScale),
                                                        decoration: BoxDecoration(
                                                          color: _confirmedBets[name] == bet ? Colors.green : Colors.amber,
                                                          borderRadius: BorderRadius.circular(10 * wheelScale),
                                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                                                              style: TextStyle(color: Colors.black, fontSize: 10 * wheelScale, fontWeight: FontWeight.w900),
                                                            ),
                                                            if (_confirmedBets[name] == bet) ...[
                                                              SizedBox(width: 3 * wheelScale),
                                                              Icon(Icons.check_circle, color: Colors.white, size: 12 * wheelScale),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  IgnorePointer(
                                    child: CustomPaint(
                                      size: Size(360 * wheelScale, 420 * wheelScale), 
                                      painter: GlowPointerPainter(activeIndex: _currentSegment, scale: wheelScale, segmentCount: _segmentCount)
                                    ),
                                  ),
                                  Positioned(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // White Hub
                                        Container(
                                          width: 120 * wheelScale, height: 120 * wheelScale,
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.transparent),
                                            boxShadow: const [],
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.only(bottom: 25 * wheelScale),
                                              child: Text("🐼", style: TextStyle(fontSize: 65 * wheelScale)),
                                            ),
                                          ),
                                        ),
                                        // Select Time Banner
                                        Positioned(
                                          bottom: 0,
                                          child: Container(
                                            width: 90 * wheelScale,
                                            padding: EdgeInsets.symmetric(vertical: 2 * wheelScale),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(10 * wheelScale),
                                              border: Border.all(color: Colors.transparent),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(_countdownLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9 * wheelScale)),
                                                  Text("${_countdown}s", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * wheelScale)),
                                                ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. Betting Section Chips
                    Positioned(
                      bottom: bettingSectionBottom,
                      left: 16 * scale,
                      right: 16 * scale,
                      child: _buildBettingSection(settings, scale, statsAsync.value),
                    ),

                    if (_isBetLocked && _countdownLabel == "BETS CLOSED")
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                            child: const Text("BETS CLOSED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                          ),
                        ),
                      ),

                    // 5. Bottom Stats Panel
                    ValueListenableBuilder<int>(
                      valueListenable: _historyUpdateNotifier,
                      builder: (context, _, __) {
                        return Consumer(
                          builder: (context, ref, child) {
                            final int displayedBalance = _walletManager.displayedBalance;

                            final rawHistory = ref.watch(userGameHistoryProvider).value ?? [];
                            final history = _getRealtimeMergedHistory(rawHistory);
                            final stats = ref.watch(luckySpinStatsProvider).value;

                            // Watch Daily Leaderboard & resolve top player immediately
                            final serverLeaderboard = ref.watch(luckySpinLeaderboardProvider).value ?? [];
                            final activeLeaderboard = _getRealtimeLeaderboard(
                              serverLeaderboard: serverLeaderboard,
                              stats: stats,
                            );
                            final topPlayer = activeLeaderboard.isNotEmpty ? activeLeaderboard.first : null;

                            return _buildBottomPanel(
                              displayedBalance, 
                              history,
                              stats,
                              scale,
                              topPlayer,
                            );
                          },
                        );
                      },
                    ),
                    
                    if (_isOffline && _gameState == SpinGameState.betting && !_isSpinning && !_isBottomSheetOpen)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black26,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  "Reconnecting…",
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Back Button
                    Positioned(
                      top: topPadding + 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22), 
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Round transition countdown overlay
                    if (_showRoundTransition)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Next Round",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18 * scale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${_roundTransitionCountdown}",
                                    style: TextStyle(
                                      color: const Color(0xFFFACC15),
                                      fontSize: 72 * scale,
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(Map<String, dynamic> settings, int currentRound, double scale, Map<String, dynamic>? stats) {
    String? lastWinnerLabel;
    String? lastWinnerEmoji;
    if (_spinCompleted && _storedWinItem != null) {
      lastWinnerLabel = '${_storedWinItem!.multiplier}x';
      lastWinnerEmoji = _storedWinItem!.emoji;
    } else if (_lastRoundResultForHistory != null) {
      lastWinnerLabel = _lastRoundResultForHistory!['label'] ?? '${_lastRoundResultForHistory!['multiplier']}x';
      lastWinnerEmoji = _lastRoundResultForHistory!['emoji'];
    } else if (_lastGlobalOutcome != null && _lastGlobalOutcome!['roundId']?.toString() != _currentRoundId) {
      lastWinnerLabel = _lastGlobalOutcome!['label'] ?? '${_lastGlobalOutcome!['multiplier']}x';
      lastWinnerEmoji = _lastGlobalOutcome!['emoji'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's $currentRound Round", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            GestureDetector(
              onTap: () => _showRulesSheet(settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text("Rules >", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
        if (lastWinnerLabel != null)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12 * scale),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Last Winner: ", style: TextStyle(color: Colors.white70, fontSize: 12 * scale)),
                  Text(lastWinnerEmoji ?? "🎰", style: TextStyle(fontSize: 14 * scale)),
                  SizedBox(width: 4 * scale),
                  Text(lastWinnerLabel, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12 * scale)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Atomically reverts staged bets for the current round via revertSpinWheelBets.
  /// Only allowed while the server round is still in BETTING_OPEN (server enforces too).
  Future<void> _revertCurrentBets() async {
    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    if (totalBet <= 0 || _isBetLocked) return;

    if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
      _showConnectionNotFoundDialog();
      return;
    }

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final currentRoundId = (now ~/ serverRoundMs).toString();
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    if (secondsIntoCycle >= 30) return; // bets locked; server rejects anyway

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revert Bets?"),
        content: Text("Refund the full wager of $totalBet diamonds and clear your bets for this round?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Revert")),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final result = await ref.read(gameServiceProvider).revertSpinWheelBets(roundId: currentRoundId);
      if (!mounted) return;
      setState(() {
        _currentBets = {};
        _betClickCounts = {};
        _confirmedBets = {};
        _confirmedRoundId = null;
        _hasSpunForRound = null;
        _hasPendingAdditionalBets = false;
        _walletManager.reconcileBetRevert(txnId: 'bet_$currentRoundId', roundId: currentRoundId);
      });
      _notifyHistoryUpdate();
      final refunded = (result['totalBet'] as num?)?.toInt();
      debugPrint('[SPIN_WHEEL_EVENT] ↩️ Bets reverted for round $currentRoundId: refunded=${refunded ?? totalBet}');
    } catch (e) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Revert failed for round $currentRoundId: $e. Bets preserved; next tick reconciles.');
    }
  }

  Widget _buildBettingSection(Map<String, dynamic> settings, double scale, Map<String, dynamic>? stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildChip(100, const Color(0xFFFFD700), scale),
        _buildChip(1000, const Color(0xFFFFD700), scale),
        _buildChip(10000, const Color(0xFFFFD700), scale),
        _buildChip(100000, const Color(0xFFFFD700), scale),
      ],
    );
  }

  Widget _buildJackpotTab(String label, String emoji, double scale, int bet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56 * scale, height: 56 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 3 * scale),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8 * scale, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 32 * scale))),
            ),
            if (bet > 0)
              Positioned(
                top: -8 * scale,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10 * scale),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                    style: TextStyle(color: Colors.black, fontSize: 9 * scale, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
        Transform.translate(
          offset: Offset(0, -3 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4 * scale),
              border: Border.all(color: Colors.transparent),
              boxShadow: const [],
            ),
            child: Text("$label >", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10 * scale, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(int value, Color color, double scale) {
    bool isSelected = _selectedChipValue == value;

    return GestureDetector(
      onTap: _isOffline ? null : () {
        debugPrint('[SPIN_WHEEL_EVENT] 🪙 Chip selected: ${_selectedChipValue} -> $value');
        setState(() => _selectedChipValue = value);
      },
      child: Container(
        width: 62 * scale,
        height: 62 * scale,
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : (_isOffline ? color.withOpacity(0.4) : color),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black26,
            width: isSelected ? 2.2 * scale : 1 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6 * scale,
              offset: Offset(0, 3 * scale),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.stars, color: Colors.amber, size: 15 * scale),
              Text(
                value >= 1000 ? "${(value / 1000).floor()}k" : value.toString(),
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12 * scale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBar(List<dynamic> history, double scale) {
    final bool isSpinningPhase = _gameState == SpinGameState.spinning || _isSpinning;
    final bool isResultCelebration = _gameState == SpinGameState.results && _spinCompleted;

    // 1. NEUTRAL THROUGHOUT ACTIVE BETTING & SPINNING
    // Players must never see live winning or losing outcomes before the round finishes!
    if (!isResultCelebration) {
      final String neutralStatusText = isSpinningPhase
          ? "Wheel spinning • Awaiting official result..."
          : "Round in play • Outcomes revealed after spin";
      final String neutralEmoji = isSpinningPhase ? "🎰" : "⏳";

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 3 * scale),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15),
        ),
        child: Row(
          children: [
            SizedBox(width: 16 * scale),
            Text(
              "Result",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: 16 * scale),
                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(neutralEmoji, style: TextStyle(fontSize: 13 * scale)),
                    SizedBox(width: 6 * scale),
                    Flexible(
                      child: Text(
                        neutralStatusText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. OFFICIAL CONFIRMED RESULT (AFTER BETTING CLOSES & ROUND COMPLETES)
    final Map<String, Map<String, dynamic>> mergedByRoundId = {};

    for (final item in _realtimeRecentResults) {
      final rId = item['roundId']?.toString();
      if (rId != null && rId.isNotEmpty && rId != _currentRoundId) {
        mergedByRoundId[rId] = Map<String, dynamic>.from(item);
      }
    }

    for (final item in history) {
      if (item is Map) {
        final rId = item['roundId']?.toString();
        if (rId != null && rId.isNotEmpty && rId != _currentRoundId) {
          mergedByRoundId[rId] = Map<String, dynamic>.from(item);
        }
      }
    }

    for (final entry in _sessionRoundsHistory.entries) {
      final rId = entry.key;
      if (rId == _currentRoundId) continue;
      final sessionItem = entry.value;
      final food = sessionItem['winningFood']?.toString() ?? sessionItem['name']?.toString() ?? '';
      if (food.isNotEmpty && !mergedByRoundId.containsKey(rId)) {
        mergedByRoundId[rId] = {
          'roundId': rId,
          'name': food,
          'emoji': sessionItem['emoji'] ?? _getFoodEmoji(food),
          'label': sessionItem['label'] ?? '${sessionItem['multiplier'] ?? 5}x',
          'multiplier': sessionItem['multiplier'] ?? 5,
          'timestamp': sessionItem['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        };
      }
    }

    // Past history sorted newest-to-oldest, strictly excluding current round
    final visiblePastHistory = mergedByRoundId.values.where((rec) {
      final roundIdStr = rec['roundId']?.toString();
      if (roundIdStr == null || roundIdStr.isEmpty) return false;
      if (_currentRoundId != null && roundIdStr == _currentRoundId.toString()) return false;
      final aRound = int.tryParse(roundIdStr) ?? 0;
      final cRound = int.tryParse(_currentRoundId ?? '0') ?? 0;
      if (aRound > 0 && cRound > 0 && aRound >= cRound) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final aRound = int.tryParse(a['roundId']?.toString() ?? '0') ?? 0;
        final bRound = int.tryParse(b['roundId']?.toString() ?? '0') ?? 0;
        return bRound.compareTo(aRound);
      });

    // Winning item details for the highlighted result area
    final winningName = _storedWinItem?.name ??
        _lastRoundResultForHistory?['name']?.toString() ??
        '';
    final winningEmoji = (_storedWinItem?.emoji != null && _storedWinItem!.emoji.isNotEmpty && _storedWinItem!.emoji != '🎰')
        ? _storedWinItem!.emoji
        : ((_lastRoundResultForHistory?['emoji'] != null && _lastRoundResultForHistory!['emoji'] != '🎰')
            ? _lastRoundResultForHistory!['emoji'].toString()
            : _getFoodEmoji(winningName));
    final winningMultiplier = _storedWinItem?.multiplier ??
        (int.tryParse(_lastRoundResultForHistory?['multiplier']?.toString() ?? '5') ?? 5);
    final winningLabel = _storedWinItem != null
        ? '${_storedWinItem!.multiplier}x'
        : (_lastRoundResultForHistory?['label']?.toString() ?? '${winningMultiplier}x');

    final effectiveWager = _storedWager > 0 ? _storedWager : _lastRoundWager;
    final effectivePrize = _storedPrize > 0 ? _storedPrize : _lastRoundPrize;
    final bool hasPlayerBet = effectiveWager > 0;
    final bool isPlayerWin = hasPlayerBet && effectivePrize > 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
      ),
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          Text(
            "Result",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // ── HIGHLIGHTED RESULT AREA (OFFICIAL OUTCOME OF COMPLETED ROUND) ──
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20 * scale),
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.5 * scale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Winning circle with "New" badge
                        Container(
                          width: 34 * scale,
                          height: 34 * scale,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD700), width: 2 * scale),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Text(winningEmoji, style: TextStyle(fontSize: 18 * scale)),
                              Positioned(
                                bottom: -4 * scale,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    borderRadius: BorderRadius.circular(4 * scale),
                                    border: Border.all(color: Colors.black87, width: 1),
                                  ),
                                  child: Text(
                                    "New",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 7 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6 * scale),
                        // Winning Option Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(8 * scale),
                            border: Border.all(color: Colors.black87, width: 1),
                          ),
                          child: Text(
                            "$winningName $winningLabel",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10 * scale,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        // Final Win / Loss Status (where appropriate)
                        if (hasPlayerBet) ...[
                          SizedBox(width: 5 * scale),
                          if (isPlayerWin)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8 * scale),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                              ),
                              child: Text(
                                "🏆 WON +${_formatNumber(effectivePrize)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10 * scale,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8 * scale),
                              ),
                              child: Text(
                                "NO WIN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9 * scale,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                        SizedBox(width: 4 * scale),
                      ],
                    ),
                  ),

                  // Divider between highlighted current result and past rounds
                  if (visiblePastHistory.isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                      width: 1.5 * scale,
                      height: 24 * scale,
                      color: Colors.black26,
                    ),

                  // ── PAST SETTLED ROUNDS HISTORY (WITHOUT ANY "NEW" BADGE) ──
                  ...visiblePastHistory.map((rec) {
                    final e = rec['emoji']?.toString();
                    final l = rec['label']?.toString() ?? rec['name']?.toString() ?? '';
                    final emoji = (e != null && e.isNotEmpty && e != '🎰') ? e : _getFoodEmoji(l);

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 3 * scale),
                      width: 32 * scale,
                      height: 32 * scale,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                      child: Center(
                        child: Text(emoji, style: TextStyle(fontSize: 16 * scale)),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(int balance, List<dynamic> history, Map<String, dynamic>? stats, double scale, Map<String, dynamic>? topPlayer) {
    // Robust data extraction with fallbacks
    final todayWinners = (stats?['todayWinners'] as List?) ?? [];
    final rawTop = todayWinners.isNotEmpty ? todayWinners.first : null;
    final topFromList = rawTop is Map ? Map<String, dynamic>.from(rawTop) : null;
    final rawLastRound = stats?['lastRound'];
    final lastRound = rawLastRound is Map ? Map<String, dynamic>.from(rawLastRound) : null;

    final topWinnerName = stats?['topWinnerName'] ?? topFromList?['name'] ?? "No data";
    final topWinnerAmount = stats?['topWinnerAmount'] ?? topFromList?['amount'] ?? 0;
    
    final lastWinnerName = stats?['lastWinnerName'] ?? lastRound?['winnerName'] ?? "None";
    final lastWinnerAmount = stats?['lastWinnerAmount'] ?? lastRound?['winnerAmount'] ?? 0;

    // Calculate Today's Stats from local history
    final now = DateTime.now();
    final todayHistory = history.where((h) {
      if (h is! Map) return false;
      try {
        DateTime? ts;
        if (h['timestamp'] is Timestamp) {
          ts = (h['timestamp'] as Timestamp).toDate();
        } else if (h['timestamp'] is DateTime) {
          ts = h['timestamp'] as DateTime;
        } else if (h['timestamp'] != null) {
          ts = DateTime.tryParse(h['timestamp'].toString());
        } else if (h['createdAt'] is num) {
          ts = DateTime.fromMillisecondsSinceEpoch((h['createdAt'] as num).toInt());
        }
        if (ts == null) return true; // Default to today for active round/session
        return ts.year == now.year && ts.month == now.month && ts.day == now.day;
      } catch (_) {
        return false;
      }
    }).toList();
    
    final gamesPlayed = todayHistory.length;
    final wins = todayHistory.where((h) => (h['prize'] ?? 0) > 0).length;

    // Calculate Daily Top Player display text
    final topPlayerName = topPlayer?['name'] ?? "None";
    final topScore = (topPlayer?['amount'] as num?)?.toInt() 
        ?? (topPlayer?['totalWinnings'] as num?)?.toInt() 
        ?? (topPlayer?['totalBets'] as num?)?.toInt() 
        ?? 0;
    final displayText = topPlayer != null ? "1st: $topPlayerName: $topScore" : "None: 0";

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(top: 12 * scale, bottom: 14 * scale),
          decoration: const BoxDecoration(
            color: Color(0xFFE52E2E),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(walletBalanceProvider);
                      ref.invalidate(currentUserProfileProvider);
                      ref.invalidate(luckySpinStatsProvider);
                      ref.invalidate(luckySpinLeaderboardProvider);
                      _notifyHistoryUpdate();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
_buildSwapButton(isRefresh: true, scale: scale),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Align(
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: (_currentBets.isEmpty || _isBetLocked) ? null : _revertCurrentBets,
                              child: Container(
                                padding: EdgeInsets.all(8 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5 * scale),
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                ),
                                child: Text(
                                  "↩️",
                                  style: TextStyle(fontSize: 16 * scale, color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      null, // Use custom icon
                      Colors.orange, 
                      "Current Amount", 
                      balance.toString(), 
                      false,
                      scale,
                      customIcon: const PremiumDiamond(size: 12),
                      valueContent: _AnimatedBalance(value: balance, scale: scale),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20 * scale),
                        onTap: () {
                          _showGameHistorySheet();
                        },
                        child: _buildBalanceBox(
                          Icons.insights, 
                          Colors.green, 
                          "My Play History", 
                          "Games: $gamesPlayed | Win: $wins", 
                          true, // Show arrow to indicate it's clickable
                          scale
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            _buildResultBar(stats?['recentResults'] as List<dynamic>? ?? [], scale),
            SizedBox(height: 8 * scale),
            
            // New Shifted Stats Row (Minimum Border Radius)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showLeaderboardSheet(),
                      child: _buildBalanceBox(
                        Icons.emoji_events, 
                        Colors.amber, 
                        "Daily Top Players", 
                        displayText, 
                        true,
                        scale,
                        borderRadius: 4 * scale
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      Icons.history, 
                      Colors.cyan, 
                      "Prev Winner", 
                      "$lastWinnerName: $lastWinnerAmount", 
                      false,
                      scale,
                      borderRadius: 4 * scale
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showCurrentRoundPlayersSheet(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 12 * scale, color: Colors.black87),
                        SizedBox(width: 4 * scale),
                        Text(
                          "Round Players >",
                          style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 14 * scale),
                GestureDetector(
                  onTap: () => _showGameHistorySheet(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 12 * scale, color: Colors.black87),
                        SizedBox(width: 4 * scale),
                        Text(
                          "Game Records >",
                          style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showCurrentRoundPlayersSheet() {
    final roundId = _currentRoundId ?? (_synchronizedTimeMs ~/ 40000).toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final playersAsync = ref.watch(luckySpinRoundPlayersProvider(roundId));

          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ROUND #${_getRelativeRoundNumber(roundId)} PLAYERS",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "All participating players in this round",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: playersAsync.when(
                    data: (players) {
                      if (players.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_esports_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text(
                                "No players placed bets yet this round",
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Be the first to place a bet!",
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final p = players[index];
                          final name = (p['name'] ?? p['username'] ?? "User").toString();
                          final avatarUrl = (p['avatar'] ?? p['photoUrl'] ?? "").toString();
                          final totalBet = (p['totalBet'] as num?)?.toInt() ?? 0;
                          final winnings = (p['winnings'] as num?)?.toInt() ?? (p['prize'] as num?)?.toInt() ?? 0;
                          final betsMap = Map<String, dynamic>.from(p['bets'] ?? {});

                          final rankColors = [
                            const Color(0xFFFFD700),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ];
                          final rankColor = index < 3 ? rankColors[index] : Colors.white70;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: index < 3 ? rankColor.withOpacity(0.4) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      color: rankColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, color: Colors.white54, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: betsMap.entries.where((e) => (e.value as num? ?? 0) > 0).map((e) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "${_getFoodEmoji(e.key)} ${_formatNumber((e.value as num).toInt())}",
                                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const PremiumDiamond(size: 13),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatNumber(totalBet),
                                          style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (winnings > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Won: +${_formatNumber(winnings)}",
                                        style: const TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwapButton({bool isRefresh = false, required double scale}) {
    return Container(
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 1.5 * scale),
      ),
      child: Icon(
        isRefresh ? Icons.refresh : Icons.swap_horizontal_circle_outlined, 
        color: Colors.amber, 
        size: 24 * scale
      ),
    );
  }

  List<Map<String, dynamic>> _getRealtimeLeaderboard({
    required List<Map<String, dynamic>> serverLeaderboard,
    required Map<String, dynamic>? stats,
  }) {
    final todayWinners = (stats?['todayWinners'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ?? [];

    final merged = <Map<String, dynamic>>[];
    final seenUids = <String>{};

    for (final p in serverLeaderboard) {
      final uid = p['uid']?.toString() ?? '';
      final copy = Map<String, dynamic>.from(p);
      if (uid.isNotEmpty) {
        if (!seenUids.contains(uid)) {
          seenUids.add(uid);
          merged.add(copy);
        }
      } else {
        merged.add(copy);
      }
    }

    for (final w in todayWinners) {
      final uid = w['uid']?.toString() ?? '';
      final copy = Map<String, dynamic>.from(w);
      if (uid.isNotEmpty) {
        if (!seenUids.contains(uid)) {
          seenUids.add(uid);
          merged.add(copy);
        }
      } else {
        merged.add(copy);
      }
    }

    if (stats != null) {
      final topName = stats['topWinnerName']?.toString().trim();
      final topAmt = (stats['topWinnerAmount'] as num?)?.toInt() ?? 0;
      if (topName != null && topName.isNotEmpty && topName != 'None' && topAmt > 0) {
        final already = merged.any((m) => m['name'] == topName);
        if (!already) {
          merged.add({
            'name': topName,
            'avatar': stats['topWinnerAvatar'] ?? '',
            'amount': topAmt,
            'totalWinnings': topAmt,
            'totalBets': topAmt,
          });
        }
      }
      final lastWinner = stats['lastWinnerName']?.toString().trim();
      final lastAmt = (stats['lastWinnerAmount'] as num?)?.toInt() ?? 0;
      if (lastWinner != null && lastWinner.isNotEmpty && lastWinner != 'None' && lastAmt > 0) {
        final already = merged.any((m) => m['name'] == lastWinner);
        if (!already) {
          merged.add({
            'name': lastWinner,
            'avatar': stats['lastWinnerAvatar'] ?? '',
            'amount': lastAmt,
            'totalWinnings': lastAmt,
            'totalBets': lastAmt,
          });
        }
      }
    }

    // Merge current user's session standing so their latest win/loss reflects immediately
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && currentUid.isNotEmpty) {
      int sessionWinnings = 0;
      int sessionBets = 0;
      for (final r in _sessionRoundsHistory.values) {
        sessionWinnings += (r['prize'] as num?)?.toInt() ?? 0;
        sessionBets += (r['totalBet'] as num?)?.toInt() ?? 0;
      }
      final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
      final currentUserName = userProfile?.displayName ?? userProfile?.username ?? FirebaseAuth.instance.currentUser?.displayName ?? 'You';
      final currentUserAvatar = userProfile?.profilePhotoUrl ?? FirebaseAuth.instance.currentUser?.photoURL ?? '';

      final idx = merged.indexWhere((m) => m['uid']?.toString() == currentUid);
      if (idx != -1) {
        final existing = merged[idx];
        final curW = (existing['amount'] as num?)?.toInt() ?? (existing['totalWinnings'] as num?)?.toInt() ?? 0;
        final curB = (existing['totalBets'] as num?)?.toInt() ?? 0;
        if (sessionWinnings > curW || sessionBets > curB) {
          existing['amount'] = math.max(curW, sessionWinnings);
          existing['totalWinnings'] = math.max(curW, sessionWinnings);
          existing['totalBets'] = math.max(curB, sessionBets);
          existing['name'] = currentUserName;
          existing['avatar'] = currentUserAvatar;
        }
      } else if (sessionWinnings > 0 || sessionBets > 0) {
        merged.add({
          'uid': currentUid,
          'name': currentUserName,
          'avatar': currentUserAvatar,
          'amount': sessionWinnings,
          'totalWinnings': sessionWinnings,
          'totalBets': sessionBets,
        });
      }
    }

    // Fallback champions so rankings list is never blank
    if (merged.isEmpty) {
      merged.addAll([
        {'name': 'Top Winner', 'avatar': '', 'amount': 100000, 'totalBets': 50000},
        {'name': 'Lucky Player', 'avatar': '', 'amount': 50000, 'totalBets': 25000},
        {'name': 'Diamond Spinner', 'avatar': '', 'amount': 20000, 'totalBets': 10000},
      ]);
    }

    merged.sort((a, b) {
      final aVal = (a['amount'] as num?)?.toInt() ?? (a['totalWinnings'] as num?)?.toInt() ?? (a['totalBets'] as num?)?.toInt() ?? 0;
      final bVal = (b['amount'] as num?)?.toInt() ?? (b['totalWinnings'] as num?)?.toInt() ?? (b['totalBets'] as num?)?.toInt() ?? 0;
      if (bVal != aVal) return bVal.compareTo(aVal);
      final aBets = (a['totalBets'] as num?)?.toInt() ?? 0;
      final bBets = (b['totalBets'] as num?)?.toInt() ?? 0;
      return bBets.compareTo(aBets);
    });

    return merged;
  }

  void _showLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final dailyList = ref.watch(luckySpinLeaderboardProvider).value ?? [];
          final stats = ref.watch(luckySpinStatsProvider).value ?? {};
          final leaderboard = _getRealtimeLeaderboard(
            serverLeaderboard: dailyList,
            stats: stats,
          );
          
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("DAILY TOP PLAYERS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final p = leaderboard[index];
                      final name = p['name'] ?? p['username'] ?? "Unknown";
                      final displayScore = (p['amount'] as num?)?.toInt() 
                          ?? (p['totalWinnings'] as num?)?.toInt() 
                          ?? (p['totalBets'] as num?)?.toInt() 
                          ?? 0;
                      final avatarUrl = (p['avatar'] ?? p['photoUrl'])?.toString() ?? "";
                      
                      // Custom colors for Top 3 Ranks
                      final rankColors = [
                        const Color(0xFFFFD700), // 1st: Gold
                        const Color(0xFFC0C0C0), // 2nd: Silver
                        const Color(0xFFCD7F32), // 3rd: Bronze
                      ];
                      final rankColor = index < 3 ? rankColors[index] : Colors.white70;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            // Rank Badge with custom color
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: rankColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: rankColor, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Circle Avatar for Player
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white10,
                              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _formatNumber(displayScore),
                                  style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber, 
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder()
                    ),
                    child: const Text("CLOSE"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getFoodEmoji(String name) => getSpinWheelFoodEmoji(name);

  String _getFoodNameFromEmoji(String emoji) => getSpinWheelFoodNameFromEmoji(emoji);

  String _formatNumber(int number) {
    if (number >= 1000000000) {
      return "${(number / 1000000000).toStringAsFixed(1)}B";
    } else if (number >= 1000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}K";
    }
    return number.toString();
  }

  String _formatBalance(dynamic val) {
    if (val == null) return "0";
    final numVal = num.tryParse(val.toString())?.toInt() ?? 0;
    return _formatNumber(numVal);
  }

  String _formatCommas(dynamic val) {
    if (val == null) return "0";
    final n = num.tryParse(val.toString())?.toInt() ?? 0;
    final isNegative = n < 0;
    final str = n.abs().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return isNegative ? "-$formatted" : formatted;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dt = DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
    }
    
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}.${pad(dt.month)}.${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}";
  }

  int _getRelativeRoundNumber(dynamic roundIdValue) {
    if (roundIdValue == null) return 0;
    int roundId;
    if (roundIdValue is int) {
      roundId = roundIdValue;
    } else {
      roundId = int.tryParse(roundIdValue.toString()) ?? 0;
    }
    if (roundId == 0) return 0;

    final nowMs = roundId * 40000;
    const roundDuration = 40000;
    final startOfRoundEpochMs = (nowMs ~/ roundDuration) * roundDuration;
    final startOfRoundDate = DateTime.fromMillisecondsSinceEpoch(startOfRoundEpochMs, isUtc: true);
    final startOfDayUtc = DateTime.utc(startOfRoundDate.year, startOfRoundDate.month, startOfRoundDate.day);
    return ((startOfRoundEpochMs - startOfDayUtc.millisecondsSinceEpoch) ~/ roundDuration) + 1;
  }

  List<Map<String, dynamic>> _getRealtimeMergedHistory(List<dynamic> remoteHistory) {
    final Map<String, Map<String, dynamic>> merged = {};

    // 1. Add all remote history items safely with outcome verification
    for (final item in remoteHistory) {
      if (item is Map) {
        final rId = item['roundId']?.toString();
        final map = Map<String, dynamic>.from(item);
        final rPrize = (map['prize'] as num?)?.toInt() ?? (map['amount'] as num?)?.toInt() ?? 0;
        final rBets = map['bets'] is Map ? map['bets'] as Map : {};
        final rFood = map['winningFood']?.toString() ?? map['name']?.toString() ?? '';
        final rSettled = map['settled'] == true;

        // IMMUTABILITY: once the server has committed a settled row, its prize IS the
        // record. Recomputing it here is what let a settled round display a different
        // Win Coins on every re-fetch. Only pre-settlement rows may be derived locally.
        if (rSettled) {
          map['prize'] = rPrize;
          map['amount'] = rPrize;
        } else if (rBets.isNotEmpty && rFood.isNotEmpty) {
          final multVal = int.tryParse((map['multiplier'] ?? map['label'] ?? '5').toString().replaceAll('x', '')) ?? 5;
          final calculated = calculateSpinWheelPrize(
            bets: positiveSpinBets(rBets),
            winningName: rFood,
            multiplier: multVal,
            roundType: map['resultType']?.toString(),
          );
          map['prize'] = calculated;
          map['amount'] = calculated;
        }

        if (rId != null && rId.isNotEmpty) {
          merged[rId] = map;
        } else {
          final uniqueKey = item['docId']?.toString() ?? item['orderId']?.toString() ?? 'doc_${item.hashCode}';
          merged[uniqueKey] = map;
        }
      }
    }

    // 2. Merge all persistent session rounds so rounds played in this session NEVER disappear on rollover
    for (final entry in _sessionRoundsHistory.entries) {
      final rId = entry.key;
      final sessionItem = entry.value;
      final existing = merged[rId];

      if (existing != null) {
        merged[rId] = mergeHistoryRow(
          remoteRow: existing,
          sessionItem: sessionItem,
        );
      } else {
        final rNum = int.tryParse(rId) ?? 0;
        final isPast = rNum > 0 && rNum < (_synchronizedTimeMs ~/ 40000);
        merged[rId] = {
          ...sessionItem,
          if (isPast) 'settled': true,
        };
      }
    }

    // 3. Merge the round that just settled / finished (at the exact moment results are known, if not already captured)
    final settledRoundId = _storedRoundId.isNotEmpty
        ? _storedRoundId
        : _lastRoundResultForHistory?['roundId']?.toString();

    if (settledRoundId != null && settledRoundId.isNotEmpty) {
      final existing = merged[settledRoundId];
      final effectiveBets = (existing != null && existing['bets'] is Map && (existing['bets'] as Map).isNotEmpty)
          ? existing['bets'] as Map
          : (_storedBets != null && _storedBets!.isNotEmpty
              ? Map<String, dynamic>.from(_storedBets!)
              : ((_confirmedRoundId == settledRoundId && _confirmedBets.isNotEmpty)
                  ? Map<String, dynamic>.from(_confirmedBets)
                  : (_currentBets.isNotEmpty ? Map<String, dynamic>.from(_currentBets) : <String, dynamic>{})));

      final effectiveTotalBet = _storedWager > 0
          ? _storedWager
          : (existing?['totalBet'] as num?)?.toInt() ??
              effectiveBets.values.fold<int>(0, (sum, val) => sum + ((val as num?)?.toInt() ?? 0));

      if (effectiveBets.isNotEmpty || effectiveTotalBet > 0) {
        // AUTHORITATIVE: when the remote record is ALREADY settled, the animation outcome
        // (_storedWinItem) must NOT override the server's committed winner. The animation
        // may have been driven by a distinct/older outcome body; the server's settled row
        // is the permanent truth.
        final existingSettledName = (existing != null && existing['settled'] == true)
            ? (existing['winningFood']?.toString().isNotEmpty == true
                ? existing['winningFood'].toString()
                : (existing['name']?.toString() ?? ''))
            : '';
        final winName = existingSettledName.isNotEmpty
            ? existingSettledName
            : (_storedWinItem?.name ??
                _lastRoundResultForHistory?['name']?.toString() ??
                existing?['winningFood']?.toString() ??
                existing?['name']?.toString() ??
                '');
        final winEmoji = existingSettledName.isNotEmpty && existing?['emoji']?.toString().isNotEmpty == true
            ? existing!['emoji'].toString()
            : (_storedWinItem?.emoji ??
                _lastRoundResultForHistory?['emoji']?.toString() ??
                existing?['emoji']?.toString() ??
                '🎰');
        final winMult = existingSettledName.isNotEmpty && existing?['label']?.toString().isNotEmpty == true
            ? existing!['label'].toString()
            : (_storedWinItem != null
                ? '${_storedWinItem!.multiplier}x'
                : (_lastRoundResultForHistory?['label']?.toString() ??
                    existing?['multiplier']?.toString() ??
                    existing?['label']?.toString() ??
                    '5x'));
        final int prize = (existing?['settled'] == true)
            ? ((existing?['prize'] as num?)?.toInt() ?? (existing?['amount'] as num?)?.toInt() ?? 0)
            : (_sessionRoundsHistory[settledRoundId]?['settled'] == true
                ? ((_sessionRoundsHistory[settledRoundId]?['prize'] as num?)?.toInt() ?? 0)
                : _storedPrize);

        merged[settledRoundId] = {
          ...?existing,
          'roundId': settledRoundId,
          'bets': effectiveBets,
          'totalBet': effectiveTotalBet,
          'prize': prize,
          'amount': prize,
          'winningFood': winName,
          'name': winName,
          'emoji': winEmoji,
          'label': winMult,
          'multiplier': winMult,
          'settled': true,
          'timestamp': existing?['timestamp'] ?? DateTime.now(),
          'createdAt': existing?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        };
      }
    }

    // 4. Merge the current active round if user placed bets in it
    final activeRoundId = _currentRoundId;
    final currentSyncRound = (_synchronizedTimeMs ~/ 40000).toString();
    final activeBets = (_confirmedRoundId == activeRoundId && _confirmedBets.isNotEmpty)
        ? _confirmedBets
        : _currentBets;
    if (activeRoundId != null &&
        activeRoundId.isNotEmpty &&
        activeRoundId == currentSyncRound &&
        activeBets.isNotEmpty &&
        activeRoundId != settledRoundId) {
      final existing = merged[activeRoundId];
      final totalWager = activeBets.values.fold<int>(0, (sum, val) => sum + val);

      if (existing == null || existing['settled'] != true) {
        merged[activeRoundId] = {
          ...?existing,
          'roundId': activeRoundId,
          'bets': Map<String, int>.from(activeBets),
          'totalBet': totalWager,
          'prize': 0,
          'amount': 0,
          'winningFood': '',
          'name': '',
          'emoji': '🎰',
          'label': '',
          'multiplier': '',
          'settled': false,
          'timestamp': existing?['timestamp'] ?? DateTime.now(),
          'createdAt': existing?['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        };
      }
    }

    // 4b. Authoritative winner overlay:
    // Only overlay outcomes onto completed/settled rounds missing their winner.
    // In-play / active betting rounds MUST NEVER have premature outcomes attached.
    // Already-settled server rows are immutable records and must never be overwritten.
    final _outcomes = _authoritativeRoundOutcomes();
    for (final key in merged.keys.toList()) {
      final row = merged[key]!;

      // 1. In-play or unsettled rounds must NEVER leak premature outcome or win fields
      final isRowUnsettled = (row['settled'] != true) || (key == activeRoundId);
      if (isRowUnsettled) {
        row['winningFood'] = '';
        row['name'] = '';
        row['emoji'] = '🎰';
        row['label'] = '';
        row['multiplier'] = '';
        row['prize'] = 0;
        row['amount'] = 0;
        continue;
      }

      // 2. Authoritative settled rows with existing winningFood must NOT be overwritten
      if (row['settled'] == true &&
          ((row['winningFood']?.toString().isNotEmpty == true) || (row['name']?.toString().isNotEmpty == true))) {
        continue;
      }

      final outcome = _outcomes[key];
      if (outcome == null) continue;
      final oName = outcome['name']?.toString() ?? '';
      if (oName.isEmpty) continue;
      row['winningFood'] = oName;
      row['name'] = oName;
      final oEmoji = outcome['emoji']?.toString() ?? '';
      if (oEmoji.isNotEmpty) row['emoji'] = oEmoji;
      final oLabel = outcome['label']?.toString() ?? '';
      if (oLabel.isNotEmpty) row['label'] = oLabel;
      final oMult = outcome['multiplier']?.toString() ?? '';
      if (oMult.isNotEmpty) row['multiplier'] = oMult;
      final oCat = outcome['category']?.toString() ?? '';
      if (oCat.isNotEmpty) row['resultType'] = oCat;
    }

    // 5. Sort descending: highest roundId first, then newest timestamp / createdAt
    final list = merged.values.toList()
      ..sort((a, b) {
        final rA = int.tryParse(a['roundId']?.toString() ?? '') ?? 0;
        final rB = int.tryParse(b['roundId']?.toString() ?? '') ?? 0;
        if (rA > 0 && rB > 0 && rA != rB) return rB.compareTo(rA);

        final tA = a['timestamp'];
        final tB = b['timestamp'];
        if (tA is Timestamp && tB is Timestamp) {
          final cmp = tB.compareTo(tA);
          if (cmp != 0) return cmp;
        }
        if (tA is DateTime && tB is DateTime) {
          final cmp = tB.compareTo(tA);
          if (cmp != 0) return cmp;
        }

        final cA = (a['createdAt'] as num?)?.toInt() ?? 0;
        final cB = (b['createdAt'] as num?)?.toInt() ?? 0;
        if (cA != cB) return cB.compareTo(cA);

        final sA = int.tryParse(a['serialNumber']?.toString() ?? '') ?? 0;
        final sB = int.tryParse(b['serialNumber']?.toString() ?? '') ?? 0;
        return sB.compareTo(sA);
      });

    // Filter out spectator rounds where user placed NO bets so My Bets strictly displays actual bets
    return list.where((item) {
      final bets = item['bets'] is Map ? item['bets'] as Map : {};
      final wager = (item['totalBet'] as num?)?.toInt() ?? 
          (bets.isNotEmpty ? bets.values.fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0)) : 0);
      return wager > 0 || bets.isNotEmpty;
    }).toList();
  }

  void _showGameHistorySheet() {
    int activeTab = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Styled Gold "Game Records" Title Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Text(
                        "Game Records",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab Selector: [ My Bets ] [ All Rounds ]
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setSheetState(() => activeTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 0 ? const Color(0xFFF59E0B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "My Bets",
                                style: TextStyle(
                                  color: activeTab == 0 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() => activeTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "All Rounds",
                                style: TextStyle(
                                  color: activeTab == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Flexible(
                      child: activeTab == 0
                          ? ValueListenableBuilder<int>(
                              valueListenable: _historyUpdateNotifier,
                              builder: (context, _, __) {
                                return Consumer(
                                  builder: (context, ref, child) {
                                    final historyAsync = ref.watch(userGameHistoryProvider);
                                    final rawHistory = historyAsync.value ?? [];
                                    final mergedHistory = _getRealtimeMergedHistory(rawHistory);

                                    if (mergedHistory.isEmpty && historyAsync.isLoading) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 40),
                                          child: CircularProgressIndicator(color: Colors.amber),
                                        ),
                                      );
                                    }

                                    if (mergedHistory.isEmpty) {
                                      return _buildHistoryEmptyState();
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: mergedHistory.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return _buildHistorySummaryHeader(mergedHistory);
                                        }
                                        final recordIndex = index - 1;
                                        final h = mergedHistory[recordIndex];
                                        // Key by the stable record id. Without a Key the
                                        // builder reuses elements by position, so prepending a
                                        // new round re-renders old rows under new data.
                                        final rowKey = h['orderId'] ?? h['docId'] ?? h['roundId'] ?? recordIndex;
                                        return KeyedSubtree(
                                          key: ValueKey(rowKey),
                                          child: _buildMyBetCard(context, h, recordIndex, mergedHistory.length),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : _buildAllRoundsList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              
              // Absolute Positioned Close Button at the top right
              Positioned(
                top: 16, right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistorySummaryHeader(List<Map<String, dynamic>> history) {
    final totalRounds = history.length;
    final totalWins = history.where((h) {
      final prize = (h['prize'] as num?)?.toInt() ?? (h['amount'] as num?)?.toInt() ?? 0;
      return prize > 0;
    }).length;
    final totalWonCoins = history.fold(0, (sum, h) {
      final prize = (h['prize'] as num?)?.toInt() ?? (h['amount'] as num?)?.toInt() ?? 0;
      return sum + prize;
    });
    final winRate = totalRounds > 0 ? ((totalWins / totalRounds) * 100).toStringAsFixed(0) : "0";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total Games", "$totalRounds", Icons.sports_esports_outlined, const Color(0xFF60A5FA)),
          Container(width: 1, height: 26, color: Colors.white12),
          _buildStatItem("Total Won", "+${_formatNumber(totalWonCoins)}", Icons.stars_rounded, const Color(0xFFFBBF24)),
          Container(width: 1, height: 26, color: Colors.white12),
          _buildStatItem("Win Rate", "$winRate%", Icons.trending_up_rounded, const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildHistoryEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 40, color: Colors.amber),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Bet Records Yet",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Place bets on food items during the round to see your live betting history and win records here!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBetCard(BuildContext context, Map<String, dynamic> h, int index, int totalCount) {
    final betsMap = Map<String, dynamic>.from(h['bets'] ?? {});
    int prize = (h['prize'] as num?)?.toInt() ?? (h['amount'] as num?)?.toInt() ?? 0;
    final totalWager = (h['totalBet'] as num?)?.toInt() ?? betsMap.values.fold<int>(0, (sum, val) => sum + ((val as num?)?.toInt() ?? 0));
    final relativeRound = _getRelativeRoundNumber(h['roundId']);
    final serialNo = h['serialNumber'] ?? relativeRound;
    final roundNum = int.tryParse(h['roundId']?.toString() ?? '') ?? 0;
    final currentSyncRound = _synchronizedTimeMs ~/ 40000;
    final isPastRound = roundNum > 0 && roundNum < currentSyncRound;
    final isCurrentRound = (h['roundId']?.toString() == _currentRoundId) || (!isPastRound && roundNum == currentSyncRound);
    final bool isRowSettled = h['settled'] == true ||
        (isPastRound && (h['status'] == 'ROUND_SETTLED' || h['status'] == 'SETTLED' || (h['prize'] as num? ?? 0) > 0));
    final bool isPendingInPlay = !isRowSettled || (isCurrentRound && _gameState != SpinGameState.results);

    final String foodName;
    final String winningEmoji;
    final String cleanMult;
    final bool isWin;
    final bool isPendingCard;
    final Color stampColor;
    final String stampText;

    if (isPendingInPlay) {
      prize = 0;
      isWin = false;
      isPendingCard = true;
      foodName = "PENDING";
      winningEmoji = "🎰";
      cleanMult = "";
      stampColor = const Color(0xFFF59E0B);
      stampText = "PENDING";
    } else {
      isPendingCard = false;
      final rawName = h['winningFood']?.toString() ?? h['name']?.toString() ?? '';
      final rawLabel = h['label']?.toString() ?? '';

      // Authoritative Win Evaluation: For settled rows or rows with server prize present,
      // display h['prize'] as-is; do NOT recompute.
      final bool hasServerPrize = h['prize'] != null || h['amount'] != null;
      final effectiveWinnerName = rawName.isNotEmpty ? rawName : rawLabel;
      final multVal = int.tryParse(h['multiplier']?.toString().replaceAll('x', '') ?? '') ?? resolveFoodMultiplier(effectiveWinnerName);
      prize = resolveCardDisplayPrize(
        isSettled: isRowSettled,
        hasServerPrize: hasServerPrize,
        existingPrize: prize,
        betsMap: betsMap,
        winningFood: effectiveWinnerName,
        multiplier: multVal,
        roundType: h['resultType']?.toString(),
      );

      // CRITICAL: Deduce winning food and icon from winning bet when prize > 0
      final resolvedFood = deduceWinningFoodFromWinningBet(
        betsMap: betsMap,
        prize: prize,
        existingFood: rawName.isNotEmpty ? rawName : rawLabel,
        roundType: h['resultType']?.toString(),
      );

      foodName = resolvedFood.isNotEmpty
          ? resolvedFood.toUpperCase()
          : (rawName.isNotEmpty
              ? rawName.toUpperCase()
              : ((rawLabel.isNotEmpty && !rawLabel.contains('x'))
                  ? rawLabel.toUpperCase()
                  : _getFoodNameFromEmoji(h['emoji']?.toString() ?? '')));

      winningEmoji = _getFoodEmoji(foodName);

      final mult = resolveFoodMultiplier(foodName, int.tryParse(h['multiplier']?.toString().replaceAll('x', '') ?? ''));
      cleanMult = mult.toString();

      isWin = prize > 0;
      stampColor = isWin ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
      stampText = isWin ? "WIN" : "LOSE";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWin
              ? [const Color(0xFF23163A), const Color(0xFF151026)]
              : [const Color(0xFF1E2138), const Color(0xFF131525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWin
              ? const Color(0xFFF59E0B).withOpacity(0.55)
              : Colors.white.withOpacity(0.12),
          width: isWin ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isWin
                ? const Color(0xFFF59E0B).withOpacity(0.12)
                : Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Watermark Stamp in Background (Bottom Right)
            if (!isCurrentRound)
              Positioned(
                bottom: 8,
                right: 12,
                child: Opacity(
                  opacity: 0.18,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: stampColor, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("★ ★ ★", style: TextStyle(color: stampColor, fontSize: 8, letterSpacing: 2)),
                          Text(
                            stampText,
                            style: TextStyle(
                              color: stampColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: S/N & Round & Date + WIN/LOSE Badge
                  Row(
                    children: [
                      // S/N Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
                        ),
                        child: Text(
                          "S/N: #$serialNo",
                          style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Round Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Text(
                          "Round #$relativeRound",
                          style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Timestamp wrapped in Expanded to prevent any right overflow on narrow displays
                      Expanded(
                        child: Text(
                          _formatTimestamp(h['timestamp']),
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Win/Lose Pill
                      if (isPendingInPlay)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("⏳ IN PLAY", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: isWin
                                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                : const LinearGradient(colors: [Color(0xFF475569), Color(0xFF334155)]),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              if (isWin)
                                BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 6),
                            ],
                          ),
                          child: Text(
                            isWin ? "WIN" : "LOSE",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Selected Food Bets Header + Total Wager Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Selected Food & Stakes:",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Total Bet: ", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const PremiumDiamond(size: 11),
                            const SizedBox(width: 3),
                            Text(
                              _formatCommas(totalWager),
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Selected Food Chips Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: betsMap.entries.map((entry) {
                      final itemEmoji = _getFoodEmoji(entry.key);
                      final itemName = entry.key.toString().toUpperCase();
                      final normEntryKey = normalizeFoodKey(entry.key.toString());
                      final normFoodName = normalizeFoodKey(foodName);
                      final isAliasMatch = normEntryKey == normFoodName ||
                          (normEntryKey == 'burger' && normFoodName == 'hotdog') ||
                          (normEntryKey == 'hotdog' && normFoodName == 'burger') ||
                          (normEntryKey == 'kebab' && normFoodName == 'skewer') ||
                          (normEntryKey == 'skewer' && normFoodName == 'kebab') ||
                          (normEntryKey == 'steak' && normFoodName == 'meat') ||
                          (normEntryKey == 'meat' && normFoodName == 'steak') ||
                          (normEntryKey == 'cabbage' && (normFoodName == 'leaf' || normFoodName == 'veg'));
                      final isMatch = !isPendingInPlay && isWin && (
                          isAliasMatch ||
                          entry.key.toString().toLowerCase().trim() == (h['resultType'] ?? '').toString().toLowerCase().trim()
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMatch
                              ? const Color(0xFFF59E0B).withOpacity(0.25)
                              : Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMatch
                                ? const Color(0xFFFBBF24)
                                : Colors.white12,
                            width: isMatch ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(itemEmoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              "$itemName ",
                              style: TextStyle(
                                color: isMatch ? const Color(0xFFFDE68A) : Colors.white70,
                                fontSize: 11,
                                fontWeight: isMatch ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatCommas(entry.value),
                              style: TextStyle(
                                color: isMatch ? Colors.white : const Color(0xFFDDD6FE),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isMatch) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 12),

                  // 3. Winning Food & Payout Row
                  Row(
                    children: [
                      // Winning Food Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Winning Food", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(winningEmoji.isNotEmpty ? winningEmoji : '🎰', style: const TextStyle(fontSize: 14)),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    foodName.isNotEmpty ? foodName : "SETTLED",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isPendingInPlay && cleanMult.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.6), width: 0.8),
                                    ),
                                    child: Text(
                                      "${cleanMult}x",
                                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Win Coins Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Win Coins", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PremiumDiamond(size: 14),
                              const SizedBox(width: 4),
                              Text(
                                (!isPendingInPlay && isWin) ? "+${_formatCommas(prize)}" : "0",
                                style: TextStyle(
                                  color: (!isPendingInPlay && isWin) ? const Color(0xFFFBBF24) : Colors.white60,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 4. Coin Balance Row: Final Balance = Starting Balance - Total Stake + Gross Winnings
                  if (h['balanceBefore'] != null) ...[
                    Builder(
                      builder: (context) {
                        final startBal = (h['balanceBefore'] as num).toInt();
                        final calculatedFinalBal = isRowSettled
                            ? math.max(0, startBal - totalWager + prize)
                            : math.max(0, startBal - totalWager);
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white54),
                              const SizedBox(width: 6),
                              const Text("Balance: ", style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Text(
                                  "${_formatCommas(startBal)} → ${_formatCommas(calculatedFinalBal)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const PremiumDiamond(size: 11),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // 5. Order ID Row with Copy
                  if (h['orderId'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Order ID: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Expanded(
                          child: Text(
                            "${h['orderId']}",
                            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: h['orderId'].toString()));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Order ID copied to clipboard"),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, color: Colors.white70, size: 11),
                                SizedBox(width: 3),
                                Text("COPY", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single authoritative map of roundId -> winning outcome, shared by BOTH
  /// the "All Rounds" tab and the "My Bets" tab. Server `recentResults` is the
  /// source of truth and overrides the client-side realtime cache, so every
  /// round shows an identical winner/emoji/label/multiplier in both sections.
  Map<String, Map<String, dynamic>> _authoritativeRoundOutcomes() {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final item in _realtimeRecentResults) {
      final rId = item['roundId']?.toString();
      if (rId != null && rId.isNotEmpty) merged[rId] = Map<String, dynamic>.from(item);
    }
    final stats = ref.read(luckySpinStatsProvider).value;
    final serverRecents = stats?['recentResults'] as List? ?? [];
    for (final item in serverRecents) {
      if (item is Map) {
        final rId = item['roundId']?.toString();
        if (rId != null && rId.isNotEmpty) merged[rId] = Map<String, dynamic>.from(item);
      }
    }
    return merged;
  }

  Widget _buildAllRoundsList() {
    return Consumer(
      builder: (context, ref, child) {
        final merged = _authoritativeRoundOutcomes();

        final sortedRounds = merged.values.toList()
          ..sort((a, b) {
            final aRound = int.tryParse(a['roundId']?.toString() ?? '0') ?? 0;
            final bRound = int.tryParse(b['roundId']?.toString() ?? '0') ?? 0;
            return bRound.compareTo(aRound);
          });

        if (sortedRounds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text("Waiting for round outcomes...", style: TextStyle(color: Colors.white70, fontSize: 14)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: sortedRounds.length,
          itemBuilder: (context, index) {
            final rec = sortedRounds[index];
            final emoji = rec['emoji']?.toString() ?? _getFoodEmoji(rec['name']?.toString() ?? '');
            final name = rec['name']?.toString() ?? 'Unknown';
            final mult = rec['multiplier'] ?? 5;
            final rId = rec['roundId']?.toString() ?? '';
            final roundNum = _getRelativeRoundNumber(rId);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF334155), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji.isNotEmpty ? emoji : '🎰', style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Round: #$roundNum", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text("${mult}x", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceBox(IconData? icon, Color iconColor, String label, String value, bool hasArrow, double scale, {double? borderRadius, Widget? customIcon, Widget? valueContent}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 20 * scale),
        border: Border.all(color: Colors.black87, width: 1.2 * scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.black87, fontSize: 8 * scale, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null) customIcon,
              if (customIcon == null && icon != null) Icon(icon, color: iconColor, size: 12 * scale),
              SizedBox(width: 4 * scale),
              Flexible(
                child: valueContent ??
                    Text(
                      value,
                      style: TextStyle(color: Colors.black, fontSize: 10 * scale, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              if (hasArrow) Icon(Icons.chevron_right, color: Colors.black54, size: 12 * scale),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMaintenanceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle, color: Colors.brown, size: 80),
          const SizedBox(height: 16),
          const Text("GAME UNAVAILABLE", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w900, fontSize: 24)),
        ],
      ),
    );
  }
}

class _AnimatedBalance extends StatefulWidget {
  final int value;
  final double scale;
  const _AnimatedBalance({required this.value, required this.scale});

  @override
  State<_AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends State<_AnimatedBalance> {
  late Color _flashColor;
  Timer? _flashTimer;
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _flashColor = Colors.black;
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(_AnimatedBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _flashColor = widget.value > oldWidget.value
          ? const Color(0xFF16A34A)
          : const Color(0xFFDC2626);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _flashColor = Colors.black;
            _previousValue = widget.value;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previousValue.toDouble(), end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Text(
          anim.round().toString(),
          style: TextStyle(
            color: _flashColor,
            fontSize: 10 * widget.scale,
            fontWeight: FontWeight.w900,
          ),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

int resolveTargetSectorIndex(Map<String, dynamic>? outcome, List<dynamic> segmentsMap) {
  if (outcome == null) return 0;

  final Map<String, dynamic> eff = (outcome['outcome'] is Map)
      ? Map<String, dynamic>.from(outcome['outcome'] as Map)
      : outcome;

  final effectiveSegments = segmentsMap.isNotEmpty
      ? segmentsMap
      : const [
          {'name': 'Hotdog', 'multiplier': 10, 'category': 'pizza'},
          {'name': 'Skewer', 'multiplier': 15, 'category': 'pizza'},
          {'name': 'Chicken', 'multiplier': 25, 'category': 'pizza'},
          {'name': 'Steak', 'multiplier': 45, 'category': 'pizza'},
          {'name': 'Carrot', 'multiplier': 5, 'category': 'salad'},
          {'name': 'Corn', 'multiplier': 5, 'category': 'salad'},
          {'name': 'Cabbage', 'multiplier': 5, 'category': 'salad'},
          {'name': 'Tomato', 'multiplier': 5, 'category': 'salad'},
        ];

  final outcomeName = normalizeFoodKey((eff['name'] as String? ?? '').toLowerCase().trim());

  // 1. Direct match on segment name
  if (outcomeName.isNotEmpty) {
    final idx = effectiveSegments.indexWhere((s) {
      final sName = normalizeFoodKey(s['name']?.toString() ?? '');
      return sName == outcomeName;
    });
    if (idx != -1) return idx;
  }

  // 2. Direct sectorIndex from outcome, clamped within segments length
  final rawSector = (eff['sectorIndex'] as num?)?.toInt();
  if (rawSector != null && rawSector >= 0) {
    return rawSector % effectiveSegments.length;
  }

  // 3. Category match fallback (e.g. outcome is 'pizza' or 'salad' celebration)
  final cat = (eff['type'] as String? ?? eff['category'] as String? ?? (outcomeName == 'pizza' || outcomeName == 'salad' ? outcomeName : '')).toLowerCase().trim();
  if (cat.isNotEmpty) {
    final catIdx = effectiveSegments.indexWhere((s) {
      final sCat = (s['category']?.toString() ?? '').toLowerCase().trim();
      return sCat == cat;
    });
    if (catIdx != -1) return catIdx;
  }

  return 0;
}

String normalizeFoodKey(String raw) {
  var s = raw.toLowerCase().trim();
  // Strip '5x', '10x', '15x', '25x', '45x' or any '\d+x'
  s = s.replaceAll(RegExp(r'\b\d+x\b', caseSensitive: false), '').trim();
  s = s.replaceAll(RegExp(r'\d+x', caseSensitive: false), '').trim();
  // Strip common emojis
  s = s.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
  s = s.trim();
  // Canonical food alias mappings
  if (s == 'skewer' || s == 'kebab') return 'kebab';
  if (s == 'steak' || s == 'meat') return 'steak';
  if (s == 'cabbage' || s == 'veg' || s == 'leaf') return 'cabbage';
  if (s == 'burger') return 'burger';
  if (s == 'hotdog') return 'hotdog';
  if (s == 'tomato') return 'tomato';
  if (s == 'corn') return 'corn';
  if (s == 'carrot') return 'carrot';
  if (s == 'chicken') return 'chicken';
  if (s == 'salad') return 'salad';
  if (s == 'pizza') return 'pizza';
  return s;
}

int resolveFoodMultiplier(String foodName, [int? fallbackMult]) {
  final norm = normalizeFoodKey(foodName);
  switch (norm) {
    case 'tomato':
    case 'carrot':
    case 'corn':
    case 'cabbage':
      return 5;
    case 'hotdog':
    case 'burger':
      return 10;
    case 'kebab':
      return 15;
    case 'chicken':
      return 25;
    case 'steak':
      return 45;
    case 'salad':
      return 5;
    case 'pizza':
      return 45;
    default:
      return (fallbackMult != null && fallbackMult > 0) ? fallbackMult : 5;
  }
}

String getSpinWheelFoodEmoji(String name) {
  final norm = name.toLowerCase().trim();
  if (norm.contains('burger')) return '🍔';
  if (norm.contains('hotdog')) return '🌭';
  if (norm.contains('carrot')) return '🥕';
  if (norm.contains('corn')) return '🌽';
  if (norm.contains('cabbage') || norm.contains('leaf') || norm.contains('veg')) return '🥬';
  if (norm.contains('tomato')) return '🍅';
  if (norm.contains('kebab') || norm.contains('skewer')) return '🍢';
  if (norm.contains('chicken')) return '🍗';
  if (norm.contains('steak') || norm.contains('meat')) return '🥩';
  if (norm.contains('salad')) return '🥗';
  if (norm.contains('pizza')) return '🍕';
  return '🎰';
}

String getSpinWheelFoodNameFromEmoji(String emoji) {
  switch (emoji) {
    case '🥕': return 'CARROT';
    case '🌽': return 'CORN';
    case '🥬': return 'CABBAGE';
    case '🍅': return 'TOMATO';
    case '🍔': return 'BURGER';
    case '🌭': return 'HOTDOG';
    case '🍢': return 'KEBAB';
    case '🍗': return 'CHICKEN';
    case '🥩': return 'STEAK';
    case '🥗': return 'SALAD';
    case '🍕': return 'PIZZA';
    default: return '';
  }
}

int calculateSpinWheelPrize({
  required Map<String, int> bets,
  required String winningName,
  String? winningCategory,
  String? roundType,
  required int multiplier,
}) {
  if (bets.isEmpty) return 0;

  final normalizedBets = <String, int>{};
  bets.forEach((key, val) {
    final normKey = normalizeFoodKey(key);
    if (normKey.isNotEmpty && val > 0) {
      normalizedBets[normKey] = (normalizedBets[normKey] ?? 0) + val;
    }
  });

  final normWinner = normalizeFoodKey(winningName);
  if (normWinner.isEmpty) return 0;

  final effRoundType = (roundType ?? winningCategory ?? '').toLowerCase().trim();

  // Special celebration round handling (e.g. roundType == 'salad' or 'pizza')
  if (effRoundType == 'salad' || normWinner == 'salad') {
    const saladItems = ['tomato', 'cabbage', 'corn', 'carrot'];
    int prize = 0;
    for (final item in saladItems) {
      final bet = normalizedBets[item] ?? 0;
      if (bet > 0) prize += bet * (multiplier > 0 ? multiplier : 5);
    }
    final tabBet = normalizedBets['salad'] ?? 0;
    if (tabBet > 0) prize += tabBet * (multiplier > 0 ? multiplier : 5);
    return prize;
  } else if (effRoundType == 'pizza' || normWinner == 'pizza') {
    const pizzaItems = ['hotdog', 'skewer', 'kebab', 'chicken', 'steak'];
    int prize = 0;
    for (final item in pizzaItems) {
      final bet = normalizedBets[item] ?? 0;
      if (bet > 0) prize += bet * (multiplier > 0 ? multiplier : 45);
    }
    final tabBet = normalizedBets['pizza'] ?? 0;
    if (tabBet > 0) prize += tabBet * (multiplier > 0 ? multiplier : 45);
    return prize;
  }

  final effectiveMult = (multiplier > 0) ? multiplier : resolveFoodMultiplier(normWinner);

  int totalPrize = 0;

  // 1. Direct stake on the winning food item
  final betOnWinner = normalizedBets[normWinner] ?? 0;
  if (betOnWinner > 0) {
    totalPrize += betOnWinner * effectiveMult;
  }

  // 2. Direct stake on category jackpot tabs (if player explicitly bet on the category tab)
  const saladItems = ['tomato', 'cabbage', 'corn', 'carrot'];
  const pizzaItems = ['hotdog', 'skewer', 'kebab', 'chicken', 'steak'];

  if (saladItems.contains(normWinner)) {
    final betOnSalad = normalizedBets['salad'] ?? 0;
    if (betOnSalad > 0) {
      totalPrize += betOnSalad * 5;
    }
  } else if (pizzaItems.contains(normWinner)) {
    final betOnPizza = normalizedBets['pizza'] ?? 0;
    if (betOnPizza > 0) {
      totalPrize += betOnPizza * 45;
    }
  }

  return totalPrize;
}

class SpinItem {
  final String name; final int multiplier; final String emoji; final String? category;
  SpinItem({required this.name, required this.multiplier, required this.emoji, this.category});
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int? activeIndex; final double scale;
  final int saladHits; final int pizzaHits;
  final Map<String, int> betClickCounts;

  static final Paint _podPaint = Paint()
    ..color = Colors.transparent
    ..style = PaintingStyle.fill;

  static final Paint _pulsePaint = Paint()
    ..color = Colors.amber.withOpacity(0.3)
    ..style = PaintingStyle.stroke;

  static final Paint _glowPaint = Paint()
    ..color = Colors.white.withOpacity(0.15)
    ..style = PaintingStyle.fill;

  PodsPainter({required this.items, required this.activeIndex, required this.betClickCounts, this.scale = 1.0, this.saladHits = 0, this.pizzaHits = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 175.0 * scale;
    final radiusY = 175.0 * scale;

    _pulsePaint.strokeWidth = 3 * scale;

    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / (items.length > 0 ? items.length : 8)) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radiusX, center.dy + math.sin(angle) * radiusY);
        
        // 1. Transparent Pod (No Border)
        canvas.drawCircle(podCenter, 70 * scale, _podPaint);

        // 2. Pulse Highlight for Winning Segment
        final isHighlighted = activeIndex != null && i == activeIndex;
        if (isHighlighted) {
          canvas.drawCircle(podCenter, 65 * scale, _pulsePaint);
          canvas.drawCircle(podCenter, 60 * scale, _glowPaint);
        }

        // 4. Draw Emoji (Top)
        final emojiPainter = TextPainter(text: TextSpan(text: items[i].emoji, style: TextStyle(fontSize: 32 * scale)), textDirection: TextDirection.ltr)..layout();
        emojiPainter.paint(canvas, podCenter - Offset(emojiPainter.width / 2, 25 * scale));

        // 5. Draw Win Label (Bottom)
        final labelPainter = TextPainter(
          text: TextSpan(
            text: "win ${items[i].multiplier} times", 
            style: TextStyle(
              color: isHighlighted ? Colors.black : Colors.black87, 
              fontSize: 9 * scale, 
              fontWeight: FontWeight.w900,
              shadows: isHighlighted ? [
                const Shadow(color: Colors.white, blurRadius: 6),
                const Shadow(color: Colors.amber, blurRadius: 2),
              ] : null
            )
          ), 
          textDirection: TextDirection.ltr
        )..layout();
        labelPainter.paint(canvas, podCenter - Offset(labelPainter.width / 2, -15 * scale));

        // 6. Draw Coin Icons (Dynamic based on Clicks)
        final clickCount = betClickCounts[items[i].name] ?? 0;
        if (clickCount > 0) {
          final coinsPainter = TextPainter(
            text: TextSpan(
              text: "🪙" * clickCount.clamp(1, 3), // Max 3 coins
              style: TextStyle(fontSize: 10 * scale)
            ), 
            textDirection: TextDirection.ltr
          )..layout();
          coinsPainter.paint(canvas, podCenter - Offset(coinsPainter.width / 2, -25 * scale));
        }

        // Sold Out Overlay
    }
  }
  @override
  bool shouldRepaint(covariant PodsPainter oldDelegate) {
    if (oldDelegate.activeIndex != activeIndex) return true;
    if (oldDelegate.scale != scale) return true;
    if (oldDelegate.saladHits != saladHits) return true;
    if (oldDelegate.pizzaHits != pizzaHits) return true;
    if (oldDelegate.items.length != items.length) return true;
    if (oldDelegate.betClickCounts.length != betClickCounts.length) return true;
    for (final key in betClickCounts.keys) {
      if (oldDelegate.betClickCounts[key] != betClickCounts[key]) return true;
    }
    for (int i = 0; i < items.length; i++) {
      if (oldDelegate.items[i].name != items[i].name ||
          oldDelegate.items[i].multiplier != items[i].multiplier ||
          oldDelegate.items[i].emoji != items[i].emoji) {
        return true;
      }
    }
    return false;
  }
}

class GlowPointerPainter extends CustomPainter {
  final int? activeIndex;
  final double scale;
  final int segmentCount;
  GlowPointerPainter({required this.activeIndex, this.scale = 1.0, this.segmentCount = 8});
  @override
  void paint(Canvas canvas, Size size) {
    if (activeIndex == null) return;

    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 130.0 * scale;
    final radiusY = 148.0 * scale;
    
    final double lightAngle = (activeIndex! * (2 * math.pi / (segmentCount > 0 ? segmentCount : 8))) - (math.pi / 2);
    final lightPos = Offset(center.dx + math.cos(lightAngle) * radiusX, center.dy + math.sin(lightAngle) * radiusY);
    
    canvas.drawCircle(lightPos, 50 * scale, Paint()..color = const Color(0xFFFFD700).withOpacity(0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale));
    canvas.drawCircle(lightPos, 40 * scale, Paint()..color = Colors.white.withOpacity(0.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale));
    canvas.drawCircle(lightPos, 4 * scale, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(covariant GlowPointerPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex || oldDelegate.scale != scale;
  }
}

class SpinWheelResultBottomSheet extends ConsumerStatefulWidget {
  final SpinItem item;
  final int winnings;
  final int wager;
  final List<dynamic> winners;
  final String? roundId;
  final Map<String, int>? bets;
  final int? serverTimeOffset;

  const SpinWheelResultBottomSheet({
    super.key,
    required this.item,
    required this.winnings,
    required this.wager,
    required this.winners,
    this.roundId,
    this.bets,
    this.serverTimeOffset,
  });

  @override
  ConsumerState<SpinWheelResultBottomSheet> createState() => _SpinWheelResultBottomSheetState();
}

class _SpinWheelResultBottomSheetState extends ConsumerState<SpinWheelResultBottomSheet> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoCloseTimer;
  Timer? _safetyTimer;
  bool _isDismissingOrDismissed = false;

  void _safeDismiss() {
    if (_isDismissingOrDismissed) return;
    _isDismissingOrDismissed = true;
    _autoCloseTimer?.cancel();
    _safetyTimer?.cancel();

    if (!mounted) return;
    try {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive && route.isCurrent) {
        route.navigator?.pop();
        debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result bottom sheet safely dismissed itself');
      } else {
        debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Result bottom sheet dismiss skipped (route is not current/active)');
      }
    } catch (e) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error dismissing result bottom sheet: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final outcomeTitle = widget.wager > 0 ? (widget.winnings > 0 ? "YOU WIN!" : "YOU LOST") : "ROUND COMPLETED";
    debugPrint('[SPIN_WHEEL_EVENT] 🌟 Result Bottom Sheet Initialized: title="$outcomeTitle", item="${widget.item.name}" (${widget.item.emoji} ${widget.item.multiplier}x), wager=${widget.wager}, winnings=${widget.winnings}');

    if (widget.serverTimeOffset != null) {
      final syncMs = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
      const serverRoundMs = 40000;
      final msIntoCycle = syncMs % serverRoundMs;
      final activeRoundId = (syncMs ~/ serverRoundMs).toString();

      // Guard: If sheet opens outside the 32s - 38.5s results window, dismiss immediately!
      if ((widget.roundId != null && widget.roundId != activeRoundId) || msIntoCycle < 32000 || msIntoCycle >= 38500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDismissingOrDismissed) {
            _safeDismiss();
          }
        });
        return;
      }
    }

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _mainController.forward();

    // Automatically close before 38.5s of cycle (maximum 2.5s display)
    int remainingMsInPhase = 2500;
    if (widget.serverTimeOffset != null) {
      final syncMs = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
      final msIntoCycle = syncMs % 40000;
      if (msIntoCycle < 38500) {
        remainingMsInPhase = (38500 - msIntoCycle).clamp(800, 2500);
      } else {
        remainingMsInPhase = 600;
      }
    }
    debugPrint('[SPIN_WHEEL_EVENT] ⏱️ Result Bottom Sheet auto-close scheduled in ${remainingMsInPhase}ms');

    _autoCloseTimer = Timer(Duration(milliseconds: remainingMsInPhase), () {
      if (mounted && !_isDismissingOrDismissed) {
        debugPrint('[SPIN_WHEEL_EVENT] ⏱️ Result Bottom Sheet auto-closing on timer expiration');
        _safeDismiss();
      }
    });

    // Proactive safety watcher: checks every 100ms to guarantee sheet NEVER lingers into betting phase
    if (widget.serverTimeOffset != null) {
      _safetyTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _isDismissingOrDismissed) {
          _safetyTimer?.cancel();
          return;
        }
        final curSync = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
        final curMs = curSync % 40000;
        final curRound = (curSync ~/ 40000).toString();
        if (curMs < 32000 || curMs >= 38200 || (widget.roundId != null && widget.roundId != curRound)) {
          _safetyTimer?.cancel();
          debugPrint('[SPIN_WHEEL_EVENT] 🚨 Safety watcher closed result sheet before betting phase');
          _safeDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result Bottom Sheet Disposed');
    _isDismissingOrDismissed = true;
    _autoCloseTimer?.cancel();
    _safetyTimer?.cancel();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final nameLower = widget.item.name.toLowerCase().trim();
    final categoryLower = (widget.item.category ?? '').toLowerCase().trim();
    final isSalad = nameLower == 'salad' || categoryLower == 'salad';

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, screenHeight * 0.2 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFB0B0B13), // Ultra-premium semi-transparent deep navy
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 25,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Wavy Streamers + Fork + Knife Custom Painter
            Positioned(
              top: -30,
              left: 0,
              right: 0,
              height: 100,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ForkKnifeStreamerPainter(),
                ),
              ),
            ),

            // 2. High-Contrast White-Border Sticker in Center
            Positioned(
              top: -38,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: StickerEmojiWidget(
                    emoji: widget.item.emoji,
                    size: 46,
                  ),
                ),
              ),
            ),

            // 3. Main Body Column
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 32),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOutcomeHeader(),
                  const SizedBox(height: 20),
                  // RESULTS ROW (Panda Mascot + Dynamic Backend Data Column)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cute White 🐼 Circle Mascot matching the Wheel Hub
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E293B), width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "🐼",
                          style: TextStyle(
                            fontSize: 50,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      // Dynamic Backend Data
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "This round's results: ",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "${widget.item.emoji} ${widget.item.name}",
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700), // Highly prominent Gold result name
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    "Gross Payout: ",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  "${widget.winnings}",
                                  style: TextStyle(
                                    color: widget.winnings > 0 ? const Color(0xFF4ADE80) : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    "Total Stake: ",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  "${widget.wager}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.wager > 0) ...[
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final netProfit = widget.winnings - widget.wager;
                                  final isPositive = netProfit > 0;
                                  final isNegative = netProfit < 0;
                                  final netColor = isPositive 
                                      ? const Color(0xFF4ADE80) 
                                      : (isNegative ? const Color(0xFFF87171) : Colors.white70);
                                  final sign = isPositive ? "+" : "";
                                  return Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          "Net Profit: ",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const PremiumDiamond(size: 14),
                                      const SizedBox(width: 5),
                                      Text(
                                        "$sign$netProfit",
                                        style: TextStyle(
                                          color: netColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isSalad) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text("🥗", style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                "Salad System Breakdown (5x)",
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildSaladItemRow("🍅 Tomato", widget.bets?['tomato'] ?? 0),
                          _buildSaladItemRow("🥬 Lettuce", widget.bets?['cabbage'] ?? 0),
                          _buildSaladItemRow("🌽 Corn", widget.bets?['corn'] ?? 0),
                          _buildSaladItemRow("🥕 Carrot", widget.bets?['carrot'] ?? 0),
                        ],
                      ),
                    ),
                  ],

                  // TOP 3 WINNERS OF COMPLETED ROUND
                  Consumer(
                    builder: (context, ref, child) {
                      final roundId = widget.roundId ?? '';
                      final liveWinners = ref.watch(luckySpinCurrentRoundWinnersProvider(roundId)).valueOrNull ?? [];
                      final roundWinners = List<Map<String, dynamic>>.from(
                        liveWinners.isNotEmpty 
                            ? liveWinners 
                            : widget.winners.whereType<Map<String, dynamic>>().toList()
                      );

                      // Include current user if they placed bets in this round
                      if (widget.wager > 0) {
                        String currentUid = '';
                        try {
                          currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        } catch (_) {}
                        final hasMe = currentUid.isNotEmpty && roundWinners.any((w) => (w['uid'] ?? w['userId'] ?? '').toString() == currentUid);
                        if (!hasMe && currentUid.isNotEmpty) {
                          dynamic profile;
                          try {
                            profile = ref.watch(currentUserProfileProvider).valueOrNull;
                          } catch (_) {}
                          roundWinners.add({
                            'uid': currentUid,
                            'name': profile?.displayName.isNotEmpty == true 
                                ? profile!.displayName 
                                : (profile?.username.isNotEmpty == true ? profile!.username : 'You'),
                            'avatar': profile?.profilePhotoUrl ?? '',
                            'totalBet': widget.wager,
                            'winnings': widget.winnings,
                          });
                        }
                      }

                      // Deduplicate strictly by uid or name so no user is ever duplicated
                      final seen = <String>{};
                      final uniqueList = <Map<String, dynamic>>[];
                      for (final w in roundWinners) {
                        final uid = (w['uid'] ?? w['userId'] ?? '').toString().trim();
                        final name = (w['name'] ?? w['username'] ?? '').toString().trim().toLowerCase();
                        final key = uid.isNotEmpty ? uid : name;
                        if (key.isNotEmpty && seen.contains(key)) continue;
                        if (key.isNotEmpty) seen.add(key);
                        uniqueList.add(w);
                      }

                      // Sort by totalBet descending, then winnings descending
                      uniqueList.sort((a, b) {
                        final aBet = (a['totalBet'] as num?)?.toInt() ?? 0;
                        final bBet = (b['totalBet'] as num?)?.toInt() ?? 0;
                        if (bBet != aBet) return bBet.compareTo(aBet);
                        final aWin = (a['winnings'] as num?)?.toInt() ?? (a['prize'] as num?)?.toInt() ?? 0;
                        final bWin = (b['winnings'] as num?)?.toInt() ?? (b['prize'] as num?)?.toInt() ?? 0;
                        return bWin.compareTo(aWin);
                      });

                      if (uniqueList.isEmpty) return const SizedBox.shrink();

                      return _buildTop3WinnersPodium(uniqueList.take(3).toList());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTop3WinnersPodium(List<Map<String, dynamic>> winners) {
    // Deduplicate strictly by uid and by name
    final seen = <String>{};
    final uniqueWinners = <Map<String, dynamic>>[];
    for (final w in winners) {
      final uid = (w['uid'] ?? w['userId'] ?? '').toString().trim();
      final name = (w['name'] ?? w['username'] ?? '').toString().trim().toLowerCase();
      final key = uid.isNotEmpty ? uid : name;
      if (key.isNotEmpty && seen.contains(key)) continue;
      if (key.isNotEmpty) seen.add(key);
      uniqueWinners.add(w);
    }

    if (uniqueWinners.isEmpty) return const SizedBox.shrink();

    final count = uniqueWinners.length;
    final headerTitle = count == 1 
        ? "ROUND WINNER" 
        : count == 2 
            ? "TOP 2 WINNERS" 
            : "TOP 3 WINNERS";

    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: CustomDashedDivider(color: Color(0xFFFFD700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                headerTitle,
                style: TextStyle(
                  color: const Color(0xFFFFD700).withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Expanded(
              child: CustomDashedDivider(color: Color(0xFFFFD700)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (count == 1)
          // 1 user only: show single centered user
          Center(
            child: _buildTopWinnerSlot(uniqueWinners[0], 0),
          )
        else if (count == 2)
          // 2 users only: show exactly 2 users
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTopWinnerSlot(uniqueWinners[1], 1), // Rank 2 (Silver)
              const SizedBox(width: 40),
              _buildTopWinnerSlot(uniqueWinners[0], 0), // Rank 1 (Gold)
            ],
          )
        else
          // 3 or more users: show Top 3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTopWinnerSlot(uniqueWinners[1], 1), // Rank 2 (Silver, Left)
              _buildTopWinnerSlot(uniqueWinners[0], 0), // Rank 1 (Gold, Center, Tallest)
              _buildTopWinnerSlot(uniqueWinners[2], 2), // Rank 3 (Bronze, Right)
            ],
          ),
      ],
    );
  }

  Widget _buildTopWinnerSlot(Map<String, dynamic> winner, int rankIndex) {
    final rankColors = [
      const Color(0xFFFFD700), // Gold for Rank 1
      const Color(0xFFC0C0C0), // Silver for Rank 2
      const Color(0xFFCD7F32), // Bronze for Rank 3
    ];
    final rankLabels = ["#1", "#2", "#3"];
    final rankColor = rankColors[rankIndex];

    final name = (winner['name'] ?? winner['username'] ?? "User").toString();
    final avatarUrl = (winner['avatar'] ?? winner['photoUrl'] ?? "").toString();
    final totalBet = (winner['totalBet'] as num?)?.toInt() ?? 0;
    final winnings = (winner['winnings'] as num?)?.toInt() ?? (winner['prize'] as num?)?.toInt() ?? 0;
    final isCenter = rankIndex == 0;
    final avatarRadius = isCenter ? 24.0 : 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white10,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person, color: rankColor, size: isCenter ? 26 : 22)
                    : null,
              ),
            ),
            Transform.translate(
              offset: const Offset(3, 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rankLabels[rankIndex],
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumDiamond(size: 10),
            const SizedBox(width: 2.5),
            Text(
              winnings > 0 ? _formatNumber(winnings) : _formatNumber(totalBet),
              style: TextStyle(
                color: rankColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaladItemRow(String label, int bet) {
    final win = bet * 5;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(
                win >= 1000 ? "${(win / 1000).toStringAsFixed(1)}k" : win.toString(),
                style: TextStyle(
                  color: win > 0 ? Colors.amber : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const PremiumDiamond(size: 11),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}M";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(1)}K";
    return number.toString();
  }

  Widget _buildOutcomeHeader() {
    final winnings = widget.winnings;
    final wager = widget.wager;

    final String title;
    final Color textColor;
    final Color glowColor;
    final String icon;

    if (wager > 0) {
      if (winnings > 0) {
        title = "YOU WIN!";
        textColor = const Color(0xFF4ADE80); // Bright emerald green
        glowColor = const Color(0xFF4ADE80).withOpacity(0.3);
        icon = "🎉";
      } else {
        title = "YOU LOST";
        textColor = const Color(0xFFF87171); // Soft red
        glowColor = const Color(0xFFF87171).withOpacity(0.2);
        icon = "💸";
      }
    } else {
      title = "ROUND COMPLETED";
      textColor = const Color(0xFF60A5FA); // Soft blue
      glowColor = const Color(0xFF60A5FA).withOpacity(0.2);
      icon = "🎰";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 12,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(icon, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ── CUSTOM VECTOR PAINTERS & SUPPORTING WIDGETS ──────────────────────────────

class ForkKnifeStreamerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;

    final paintStreamerOrange = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paintStreamerBlue = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // 1. Draw Wavy Streamers in the background
    // Left Streamer
    final pathLeft = Path()
      ..moveTo(w * 0.28, h * 0.55)
      ..quadraticBezierTo(w * 0.23, h * 0.22, w * 0.14, h * 0.44)
      ..quadraticBezierTo(w * 0.08, h * 0.65, 0, h * 0.45);
    canvas.drawPath(pathLeft, paintStreamerOrange);

    // Right Streamer
    final pathRight = Path()
      ..moveTo(w * 0.72, h * 0.55)
      ..quadraticBezierTo(w * 0.77, h * 0.22, w * 0.86, h * 0.44)
      ..quadraticBezierTo(w * 0.92, h * 0.65, w, h * 0.45);
    canvas.drawPath(pathRight, paintStreamerBlue);

    // 2. Draw Fork Silhouette (Left of center, around w * 0.33)
    final forkX = w * 0.33;
    final forkY = h * 0.48;
    // Base prongs block
    canvas.drawRect(Rect.fromLTWH(forkX - 4.5, forkY - 11, 9, 5), paintWhite);
    // 3 prongs going up
    canvas.drawRect(Rect.fromLTWH(forkX - 4.5, forkY - 21, 1.6, 11), paintWhite);
    canvas.drawRect(Rect.fromLTWH(forkX - 0.8, forkY - 21, 1.6, 11), paintWhite);
    canvas.drawRect(Rect.fromLTWH(forkX + 2.9, forkY - 21, 1.6, 11), paintWhite);
    // Neck and solid handle
    canvas.drawRect(Rect.fromLTWH(forkX - 1.2, forkY - 6, 2.4, 4), paintWhite);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(forkX - 1.6, forkY - 2, 3.2, 23), const Radius.circular(1.2)),
      paintWhite,
    );

    // 3. Draw Knife Silhouette (Right of center, around w * 0.67)
    final knifeX = w * 0.67;
    final knifeY = h * 0.48;
    // Knife blade path
    final knifeBladePath = Path()
      ..moveTo(knifeX - 2.2, knifeY - 21)
      ..lineTo(knifeX + 2.2, knifeY - 21)
      ..quadraticBezierTo(knifeX + 3.2, knifeY - 11, knifeX + 2.2, knifeY - 5)
      ..lineTo(knifeX - 2.2, knifeY - 5)
      ..close();
    canvas.drawPath(knifeBladePath, paintWhite);
    // Connector neck
    canvas.drawRect(Rect.fromLTWH(knifeX - 1.2, knifeY - 5, 2.4, 4), paintWhite);
    // Knife handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(knifeX - 1.6, knifeY - 1, 3.2, 22), const Radius.circular(1.2)),
      paintWhite,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StickerEmojiWidget extends StatelessWidget {
  final String emoji;
  final double size;
  const StickerEmojiWidget({super.key, required this.emoji, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Deep slate background for sticker backing
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.45),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          height: 1.1,
        ),
      ),
    );
  }
}

class CustomDashedDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashSpace;

  const CustomDashedDivider({
    super.key,
    this.color = Colors.white,
    this.height = 1.0,
    this.dashWidth = 3.5,
    this.dashSpace = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height == 0 ? 1 : size.height
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}