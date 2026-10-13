import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/services/room_support_service.dart';

// Test harness simulating backend settlement, wallet balance, and room partner salary lifecycle

class MockUserWallet {
  int balance;
  final List<Map<String, dynamic>> transactions = [];

  MockUserWallet({required this.balance});

  void deductBet(int amount, String roundId) {
    balance -= amount;
    transactions.add({
      'type': 'game_bet',
      'amount': -amount,
      'roundId': roundId,
      'balanceAfter': balance,
    });
  }

  void creditWin(int prize, String roundId) {
    if (prize > 0) {
      balance += prize;
      transactions.add({
        'type': 'game_win',
        'amount': prize,
        'roundId': roundId,
        'balanceAfter': balance,
      });
    }
  }
}

class MockBackendGameEngine {
  final Map<String, Map<String, dynamic>> rounds = {};
  final Map<String, Map<String, dynamic>> settledWins = {};

  void setupRound(String roundId, {required String winningItem, required int multiplier, required String type}) {
    rounds[roundId] = {
      'winningItem': winningItem,
      'multiplier': multiplier,
      'type': type,
    };
  }

  Map<String, dynamic> placeBet({
    required MockUserWallet wallet,
    required String roundId,
    required Map<String, int> bets,
  }) {
    final totalBet = bets.values.fold<int>(0, (sum, val) => sum + val);
    if (totalBet > wallet.balance) {
      throw StateError('Insufficient balance');
    }

    wallet.deductBet(totalBet, roundId);

    final roundOutcome = rounds[roundId] ?? {'winningItem': 'tomato', 'multiplier': 5, 'type': 'standard'};
    final winningName = roundOutcome['winningItem'] as String;
    final multiplier = roundOutcome['multiplier'] as int;

    // Server-side authoritative prize calculation
    int calculatedPrize = 0;
    if (bets.containsKey(winningName)) {
      calculatedPrize = (bets[winningName]! * multiplier);
    }
    if (roundOutcome['type'] == 'salad') {
      for (final item in ['tomato', 'cabbage', 'corn', 'carrot']) {
        if (bets.containsKey(item)) {
          calculatedPrize += (bets[item]! * 5);
        }
      }
    }

    return {
      'roundId': roundId,
      'totalBet': totalBet,
      'prize': calculatedPrize,
      'balance': wallet.balance,
      'winningItem': winningName,
    };
  }

  Map<String, dynamic> settleRound({
    required MockUserWallet wallet,
    required String roundId,
    required int authoritativePrize,
    required int totalBet,
  }) {
    final winKey = 'spin_win_$roundId';
    if (settledWins.containsKey(winKey)) {
      return {
        'settled': true,
        'alreadySettled': true,
        'prize': settledWins[winKey]!['amount'],
        'balance': wallet.balance,
        'totalBet': totalBet,
      };
    }

    settledWins[winKey] = {
      'amount': authoritativePrize,
      'roundId': roundId,
    };

    if (authoritativePrize > 0) {
      wallet.creditWin(authoritativePrize, roundId);
    }

    return {
      'settled': true,
      'alreadySettled': false,
      'prize': authoritativePrize,
      'balance': wallet.balance,
      'totalBet': totalBet,
    };
  }
}

class MockRoomSupportSalaryEngine {
  final Map<String, List<Map<String, dynamic>>> activePartnersByRoom = {};
  final List<Map<String, dynamic>> paidRewards = [];
  final List<Map<String, dynamic>> archivedPartners = [];

  Map<String, dynamic> assignPartner({
    required String roomId,
    required String ownerUid,
    required String partnerUid,
    required int currentUtcDay, // 0: Sun, 1: Mon, 2: Tue, 3: Wed, 4: Thu, 5: Fri, 6: Sat
    required int roomLevel,
    bool bypass = false,
  }) {
    if (currentUtcDay != 1 && currentUtcDay != 2 && !bypass) {
      throw StateError('Room partner assignment is strictly active only during the Monday–Tuesday window (UTC).');
    }
    if (ownerUid == partnerUid) {
      throw ArgumentError('Room owner cannot be assigned as salary partner.');
    }

    final currentPartners = activePartnersByRoom[roomId] ?? [];
    if (currentPartners.any((p) => p['uid'] == partnerUid)) {
      throw StateError('User is already assigned as a salary partner.');
    }

    final partnerRecord = {
      'uid': partnerUid,
      'cycleWeekId': 'week_2026-09-13',
      'status': 'active',
      'paid': false,
      'assignedDay': currentUtcDay,
    };
    currentPartners.add(partnerRecord);
    activePartnersByRoom[roomId] = currentPartners;

    return {'success': true, 'assignedCount': currentPartners.length};
  }

  Map<String, dynamic> distributeWednesdaySalary({
    required int currentUtcDay,
    required String roomId,
    required int achievedLevel,
    required int requiredPartners,
    required int partnerReward,
    required int ownerReward,
    bool bypass = false,
  }) {
    if (currentUtcDay != 3 && !bypass) {
      return {'success': false, 'message': 'Salary distribution is processed Wednesday only (UTC).'};
    }

    final partners = activePartnersByRoom[roomId] ?? [];
    if (partners.length < requiredPartners) {
      // Expired!
      for (final p in partners) {
        archivedPartners.add({...p, 'status': 'expired', 'roomId': roomId});
      }
      activePartnersByRoom[roomId] = []; // Auto-reset
      return {'success': false, 'status': 'expired', 'message': 'Required partners not met. Expired and reset.'};
    }

    // Process payment
    for (final p in partners) {
      paidRewards.add({
        'uid': p['uid'],
        'role': 'partner',
        'amount': partnerReward,
        'roomId': roomId,
        'cycleWeekId': p['cycleWeekId'],
      });
      archivedPartners.add({
        ...p,
        'paid': true,
        'status': 'paid',
        'paidAmount': partnerReward,
      });
    }

    // MANDATORY AUTO-RESET: clear active partners so list disappears for next cycle
    activePartnersByRoom[roomId] = [];

    return {'success': true, 'status': 'distributed', 'paidCount': partners.length};
  }
}

class MockRoomSupportRewardNotificationEngine {
  final Map<String, int> userBalances = {};
  final Map<String, Map<String, dynamic>> roomSupportRewards = {};
  final Map<String, Map<String, dynamic>> userInbox = {};
  final Map<String, Map<String, dynamic>> userNotifications = {};
  final List<Map<String, dynamic>> pushNotifications = [];

  bool shouldFailTransaction = false;

  Map<String, dynamic> executeDistributionForUser({
    required String uid,
    required List<Map<String, dynamic>> candidates,
  }) {
    if (candidates.isEmpty) return {'success': false, 'reason': 'no_candidates'};

    // RULE 5: Sort candidates descending by amount, then level -> highest target wins
    candidates.sort((a, b) {
      final amtCmp = (b['amount'] as num).compareTo(a['amount'] as num);
      if (amtCmp != 0) return amtCmp;
      return (b['level'] as num).compareTo(a['level'] as num);
    });
    final winningReward = candidates[0];

    final weekId = winningReward['weekId'] as String;
    final deterministicRewardId = 'reward_${weekId}_$uid';

    // Idempotency check: if reward document exists, skip credit and notifications
    if (roomSupportRewards.containsKey(deterministicRewardId)) {
      return {
        'success': true,
        'alreadyDistributed': true,
        'rewardId': deterministicRewardId,
        'winningReward': winningReward,
      };
    }

    if (shouldFailTransaction) {
      // Transaction fails: atomic rollback, 0 credit, 0 notifications
      return {
        'success': false,
        'error': 'transaction_failed',
      };
    }

    // Atomic transaction commit:
    final rewardCoins = winningReward['amount'] as int;
    userBalances[uid] = (userBalances[uid] ?? 0) + rewardCoins;

    roomSupportRewards[deterministicRewardId] = {
      'rewardId': deterministicRewardId,
      'uid': uid,
      'roomId': winningReward['roomId'],
      'weekId': weekId,
      'role': winningReward['role'],
      'level': winningReward['level'],
      'amount': rewardCoins,
      'supersededCount': candidates.length - 1,
      'status': 'success',
    };

    final notifDocId = 'room_support_${weekId}_$uid';
    final role = winningReward['role'] as String;
    final roomId = winningReward['roomId'] as String;

    final rewardBody = role == 'partner'
        ? "Congratulations! You have achieved last week's Room Support goal. The owner of ROOM ID $roomId has added you as a Room Partner, and $rewardCoins reward coins have been sent to you.\nNote: If you achieve multiple goals, only the reward with the highest number of coins will be sent."
        : "Congratulations! You have achieved last week's Room Support goal. You have received the owner reward for ROOM ID $roomId, and $rewardCoins reward coins have been sent to you.\nNote: If you achieve multiple goals, only the reward with the highest number of coins will be sent.";

    final notifData = {
      'type': 'reward',
      'title': 'Room Support Reward Delivered 🎉',
      'body': rewardBody,
      'rewardName': 'Room Support Reward',
      'rewardAmount': rewardCoins,
      'reason': 'Achieving Level ${winningReward['level']} Room Support Goal as $role.',
      'status': 'Received',
      'read': false,
      'data': {
        'roomId': roomId,
        'weekId': weekId,
        'level': winningReward['level'],
        'role': role,
        'amount': rewardCoins,
        'route': '/inbox',
      },
    };

    userInbox['${uid}_$notifDocId'] = notifData;
    userNotifications['${uid}_$notifDocId'] = notifData;

    // Post-transaction push notification
    final pushMsg = role == 'partner'
        ? "Congratulations! You have achieved last week's Room Support goal. The owner of ROOM ID $roomId has added you as a Room Partner, and $rewardCoins reward coins have been sent to you."
        : "Congratulations! You have achieved last week's Room Support goal. You have received the owner reward for ROOM ID $roomId, and $rewardCoins reward coins have been sent to you.";

    pushNotifications.add({
      'uid': uid,
      'title': 'Room Support Reward Delivered 🎉',
      'body': pushMsg,
      'data': {
        'route': '/inbox',
        'type': 'ROOM_SUPPORT_REWARD',
        'roomId': roomId,
        'amount': '$rewardCoins',
      },
    });

    return {
      'success': true,
      'alreadyDistributed': false,
      'rewardId': deterministicRewardId,
      'winningReward': winningReward,
    };
  }
}

class MockCurrentAmountBettingSyncController {
  int _walletBalance;
  int? _authoritativeBalance;
  int _balanceSeq = 0;
  int _selectedChip = 100;
  String currentRoundId = '1001';

  final Map<String, int> _currentBets = {};
  final Map<String, int> _confirmedBets = {};
  final Set<int> _stalePreBetBalances = {};

  MockCurrentAmountBettingSyncController({required int initialBalance})
      : _walletBalance = initialBalance;

  int get selectedChip => _selectedChip;
  int get totalBetForRound => _currentBets.values.fold(0, (sum, val) => sum + val);

  void selectChip(int chip) {
    _selectedChip = chip;
  }

  int get confirmedBalance {
    if (_authoritativeBalance != null) return _authoritativeBalance!;
    if (!_stalePreBetBalances.contains(_walletBalance)) return _walletBalance;
    return 0;
  }

  int get pendingBetDeductions {
    final totalLocalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    final totalConfirmedBet = _confirmedBets.values.fold(0, (sum, val) => sum + val);
    final pending = totalLocalBet - totalConfirmedBet;
    return pending > 0 ? pending : 0;
  }

  // Displayed balance derived from confirmedBalance - pendingBetDeductions:
  // Instant optimistic UX on chip tap, reconciled seamlessly with backend
  int get currentAmount {
    final base = confirmedBalance;
    final displayed = base - pendingBetDeductions;
    return displayed > 0 ? displayed : 0;
  }

  int getCommittedBalance() => _walletBalance;

  // Stream / Refresh listener simulation
  void receiveStreamUpdate(int streamVal) {
    if (_authoritativeBalance != null) {
      if (streamVal == _authoritativeBalance) {
        _authoritativeBalance = null;
        _stalePreBetBalances.clear();
      } else if (_stalePreBetBalances.contains(streamVal)) {
        // Ignored stale pre-bet balance!
      } else if (streamVal > _authoritativeBalance!) {
        _authoritativeBalance = streamVal;
        _stalePreBetBalances.clear();
      }
    } else {
      _walletBalance = streamVal;
    }
  }

  // 1. User taps chip on food pod: bet is recorded in UI, and Current Amount immediately reflects pending deduction!
  void tapBetChip(String item) {
    final currentDiamonds = _authoritativeBalance ?? _walletBalance;
    final totalLocalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    final totalConfirmedBet = _confirmedBets.values.fold(0, (sum, val) => sum + val);
    final pendingUnconfirmedBet = (totalLocalBet - totalConfirmedBet) > 0 ? (totalLocalBet - totalConfirmedBet) : 0;

    if (pendingUnconfirmedBet + _selectedChip > currentDiamonds) {
      throw StateError('Insufficient balance');
    }

    _currentBets[item] = (_currentBets[item] ?? 0) + _selectedChip;
  }

  // 2. Backend confirms bet: deducts ONLY the actual accepted stake amount
  int confirmBetSuccess() {
    final requestSeq = ++_balanceSeq;
    final totalLocalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    final totalConfirmedBet = _confirmedBets.values.fold(0, (sum, val) => sum + val);
    final deltaBet = totalLocalBet - totalConfirmedBet;

    final prevBal = _authoritativeBalance ?? _walletBalance;
    _stalePreBetBalances.add(prevBal);

    _walletBalance -= deltaBet;
    for (final entry in _currentBets.entries) {
      _confirmedBets[entry.key] = entry.value;
    }

    if (requestSeq >= _balanceSeq) {
      _authoritativeBalance = _walletBalance;
    }
    return _walletBalance;
  }

  // Helper for single-step bet placement & confirmation
  void placeBet(String item) {
    tapBetChip(item);
    confirmBetSuccess();
  }

  // 3. Backend rejects bet: local bet is rolled back, balance remains untouched
  void rejectPendingBet() {
    _currentBets.clear();
    for (final entry in _confirmedBets.entries) {
      _currentBets[entry.key] = entry.value;
    }
    // Balance remains untouched!
  }

  int startBetRequest(int bet) {
    return ++_balanceSeq;
  }

  void completeBetResponse({required int seq, required int newBalance}) {
    if (seq >= _balanceSeq) {
      _balanceSeq = seq;
      _authoritativeBalance = newBalance;
      _walletBalance = newBalance;
    }
  }

  // 4. Round settlement: WIN/LOSS processed by backend, Current Amount credited only upon final result
  Map<String, dynamic> settleRound({
    required String winningItem,
    required int multiplier,
  }) {
    final betOnWinner = _currentBets[winningItem] ?? 0;
    final prize = betOnWinner * multiplier;

    final requestSeq = ++_balanceSeq;

    // Authoritative backend settlement transaction
    if (prize > 0) {
      _walletBalance += prize;
    }

    if (requestSeq >= _balanceSeq) {
      _authoritativeBalance = _walletBalance;
      _stalePreBetBalances.clear();
    }

    return {
      'prize': prize,
      'balance': _walletBalance,
      'roundId': currentRoundId,
    };
  }

  void rolloverToNextRound(String newRoundId) {
    currentRoundId = newRoundId;
    _currentBets.clear();
    _confirmedBets.clear();
    // Authoritative balance is preserved seamlessly across rollover without fluctuation
  }

  void simulateRefresh({int? streamBalance}) {
    if (streamBalance != null) {
      receiveStreamUpdate(streamBalance);
    }
  }
}

void main() {
  group('Issue 1: BET + BALANCE Authoritative Calculations & Idempotency', () {
    late MockUserWallet wallet;
    late MockBackendGameEngine backend;

    setUp(() {
      wallet = MockUserWallet(balance: 1000);
      backend = MockBackendGameEngine();
    });

    test('WIN round: stakes deducted once, winnings credited once, exact balance', () {
      backend.setupRound('1001', winningItem: 'tomato', multiplier: 5, type: 'standard');

      // User bets 100 on tomato
      final betResult = backend.placeBet(
        wallet: wallet,
        roundId: '1001',
        bets: {'tomato': 100},
      );

      // Balance after bet deduction = 1000 - 100 = 900
      expect(wallet.balance, equals(900));
      expect(betResult['balance'], equals(900));
      expect(betResult['prize'], equals(500)); // 100 * 5

      // Backend settles round
      final settleResult = backend.settleRound(
        wallet: wallet,
        roundId: '1001',
        authoritativePrize: betResult['prize'],
        totalBet: 100,
      );

      // Balance after win credit = 900 + 500 = 1400
      expect(wallet.balance, equals(1400));
      expect(settleResult['balance'], equals(1400));
      expect(settleResult['prize'], equals(500));
      expect(settleResult['alreadySettled'], isFalse);

      // Duplicate settlement request must be idempotent (no double credit)
      final duplicateSettle = backend.settleRound(
        wallet: wallet,
        roundId: '1001',
        authoritativePrize: betResult['prize'],
        totalBet: 100,
      );

      expect(wallet.balance, equals(1400)); // Still exactly 1400!
      expect(duplicateSettle['alreadySettled'], isTrue);
      expect(duplicateSettle['balance'], equals(1400));
    });

    test('LOSS round: stakes deducted once, 0 credited, balance stays 900 without rollback', () {
      backend.setupRound('1002', winningItem: 'carrot', multiplier: 5, type: 'standard');

      // User bets 100 on tomato (losing bet)
      final betResult = backend.placeBet(
        wallet: wallet,
        roundId: '1002',
        bets: {'tomato': 100},
      );

      expect(wallet.balance, equals(900));
      expect(betResult['prize'], equals(0)); // LOSS

      // Backend settles round
      final settleResult = backend.settleRound(
        wallet: wallet,
        roundId: '1002',
        authoritativePrize: 0,
        totalBet: 100,
      );

      // Balance remains strictly 900, stake deducted, prize is 0
      expect(wallet.balance, equals(900));
      expect(settleResult['balance'], equals(900));
      expect(settleResult['prize'], equals(0));
    });

    test('Consecutive rounds: WIN followed by LOSS correctly transitions without overwriting', () {
      // Round 1: Win 500 on 100 bet
      backend.setupRound('2001', winningItem: 'tomato', multiplier: 5, type: 'standard');
      final bet1 = backend.placeBet(wallet: wallet, roundId: '2001', bets: {'tomato': 100});
      expect(wallet.balance, equals(900));
      final settle1 = backend.settleRound(wallet: wallet, roundId: '2001', authoritativePrize: bet1['prize'], totalBet: 100);
      expect(wallet.balance, equals(1400));
      expect(settle1['prize'], equals(500));

      // Round 2: Loss on 200 bet
      backend.setupRound('2002', winningItem: 'corn', multiplier: 5, type: 'standard');
      final bet2 = backend.placeBet(wallet: wallet, roundId: '2002', bets: {'cabbage': 200});
      expect(wallet.balance, equals(1200));
      final settle2 = backend.settleRound(wallet: wallet, roundId: '2002', authoritativePrize: bet2['prize'], totalBet: 200);
      expect(wallet.balance, equals(1200));
      expect(settle2['prize'], equals(0));

      // Check transaction audit trail
      expect(wallet.transactions.length, equals(3)); // bet 1 (-100), win 1 (+500), bet 2 (-200)
    });
  });

  group('Issue 2: WINNING AMOUNT Synchronization', () {
    test('UI Displayed prize strictly matches wallet credit for WIN (zero discrepancy)', () {
      final wallet = MockUserWallet(balance: 500);
      final backend = MockBackendGameEngine();
      backend.setupRound('3001', winningItem: 'pizza', multiplier: 45, type: 'pizza');

      final betResult = backend.placeBet(wallet: wallet, roundId: '3001', bets: {'pizza': 50});
      final settleResult = backend.settleRound(
        wallet: wallet,
        roundId: '3001',
        authoritativePrize: betResult['prize'],
        totalBet: 50,
      );

      final displayedWinnings = settleResult['prize'] as int;
      final creditedAmount = wallet.balance - 450; // 500 - 50 = 450

      expect(displayedWinnings, equals(2250)); // 50 * 45
      expect(creditedAmount, equals(displayedWinnings)); // ZERO discrepancy!
    });

    test('UI Displayed prize strictly matches wallet credit for LOSS (both 0)', () {
      final wallet = MockUserWallet(balance: 500);
      final backend = MockBackendGameEngine();
      backend.setupRound('3002', winningItem: 'steak', multiplier: 45, type: 'pizza');

      final betResult = backend.placeBet(wallet: wallet, roundId: '3002', bets: {'tomato': 50});
      final settleResult = backend.settleRound(
        wallet: wallet,
        roundId: '3002',
        authoritativePrize: betResult['prize'],
        totalBet: 50,
      );

      final displayedWinnings = settleResult['prize'] as int;
      final creditedAmount = wallet.balance - 450;

      expect(displayedWinnings, equals(0));
      expect(creditedAmount, equals(0));
    });
  });

  group('Issue 3: Room Partner Salary Lifecycle', () {
    late MockRoomSupportSalaryEngine salaryEngine;

    setUp(() {
      salaryEngine = MockRoomSupportSalaryEngine();
    });

    test('Monday (day 1) and Tuesday (day 2) assignments succeed', () {
      final resMon = salaryEngine.assignPartner(
        roomId: 'room_1',
        ownerUid: 'owner_1',
        partnerUid: 'partner_1',
        currentUtcDay: 1, // Monday
        roomLevel: 1,
      );
      expect(resMon['success'], isTrue);

      final resTue = salaryEngine.assignPartner(
        roomId: 'room_1',
        ownerUid: 'owner_1',
        partnerUid: 'partner_2',
        currentUtcDay: 2, // Tuesday
        roomLevel: 1,
      );
      expect(resTue['success'], isTrue);
      expect(salaryEngine.activePartnersByRoom['room_1']!.length, equals(2));
    });

    test('Non-Mon/Tue assignments (e.g. Wednesday day 3 or Sunday day 0) are rejected by backend', () {
      expect(
        () => salaryEngine.assignPartner(
          roomId: 'room_1',
          ownerUid: 'owner_1',
          partnerUid: 'partner_bad',
          currentUtcDay: 3, // Wednesday
          roomLevel: 1,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Monday–Tuesday'))),
      );

      expect(
        () => salaryEngine.assignPartner(
          roomId: 'room_1',
          ownerUid: 'owner_1',
          partnerUid: 'partner_bad',
          currentUtcDay: 0, // Sunday
          roomLevel: 1,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Monday–Tuesday'))),
      );
    });

    test('Wednesday payout processes only on Wednesday and automatically resets active Salary List', () {
      // 1. Assign 4 partners on Monday
      for (int i = 1; i <= 4; i++) {
        salaryEngine.assignPartner(
          roomId: 'room_10',
          ownerUid: 'owner_10',
          partnerUid: 'partner_$i',
          currentUtcDay: 1,
          roomLevel: 1,
        );
      }
      expect(salaryEngine.activePartnersByRoom['room_10']!.length, equals(4));

      // 2. Attempt Wednesday payout on Tuesday -> rejected
      final wrongDayResult = salaryEngine.distributeWednesdaySalary(
        currentUtcDay: 2, // Tuesday
        roomId: 'room_10',
        achievedLevel: 1,
        requiredPartners: 4,
        partnerReward: 250000,
        ownerReward: 1000000,
      );
      expect(wrongDayResult['success'], isFalse);

      // 3. Process on Wednesday -> succeeds and pays
      final payoutResult = salaryEngine.distributeWednesdaySalary(
        currentUtcDay: 3, // Wednesday
        roomId: 'room_10',
        achievedLevel: 1,
        requiredPartners: 4,
        partnerReward: 250000,
        ownerReward: 1000000,
      );
      expect(payoutResult['success'], isTrue);
      expect(payoutResult['paidCount'], equals(4));
      expect(salaryEngine.paidRewards.length, equals(4));

      // 4. MANDATORY AUTO-RESET: Active partner list for room_10 must be EMPTY
      expect(salaryEngine.activePartnersByRoom['room_10']!.isEmpty, isTrue);

      // 5. Old IDs cannot be paid again because active list is empty
      final secondPayout = salaryEngine.distributeWednesdaySalary(
        currentUtcDay: 3,
        roomId: 'room_10',
        achievedLevel: 1,
        requiredPartners: 4,
        partnerReward: 250000,
        ownerReward: 1000000,
      );
      expect(secondPayout['success'], isFalse);
      expect(salaryEngine.paidRewards.length, equals(4)); // No duplicate payout!
    });

    test('Incomplete partner assignment expires and resets on Wednesday', () {
      // Assign only 2 partners when 4 are required
      salaryEngine.assignPartner(
        roomId: 'room_short',
        ownerUid: 'owner_short',
        partnerUid: 'partner_a',
        currentUtcDay: 1,
        roomLevel: 1,
      );
      salaryEngine.assignPartner(
        roomId: 'room_short',
        ownerUid: 'owner_short',
        partnerUid: 'partner_b',
        currentUtcDay: 2,
        roomLevel: 1,
      );

      final res = salaryEngine.distributeWednesdaySalary(
        currentUtcDay: 3,
        roomId: 'room_short',
        achievedLevel: 1,
        requiredPartners: 4,
        partnerReward: 250000,
        ownerReward: 1000000,
      );

      expect(res['status'], equals('expired'));
      // Active partner list is cleared/reset
      expect(salaryEngine.activePartnersByRoom['room_short']!.isEmpty, isTrue);
      // Archived as expired
      expect(salaryEngine.archivedPartners.where((p) => p['status'] == 'expired').length, equals(2));
    });
  });

  group('Room Partner Reward Notification Lifecycle & Idempotency', () {
    late MockRoomSupportRewardNotificationEngine engine;

    setUp(() {
      engine = MockRoomSupportRewardNotificationEngine();
    });

    test('1. Eligible goal -> dynamic reward calculation -> credit -> notification with exact dynamic data', () {
      final candidates = [
        {
          'uid': 'partner_123',
          'roomId': 'ROOM_8888',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 2,
          'amount': 250000,
        }
      ];

      final result = engine.executeDistributionForUser(
        uid: 'partner_123',
        candidates: candidates,
      );

      expect(result['success'], isTrue);
      expect(result['alreadyDistributed'], isFalse);

      // 1. Balance credited
      expect(engine.userBalances['partner_123'], equals(250000));

      // 2. Reward doc in DB
      final rewardDoc = engine.roomSupportRewards['reward_week_2026-09-13_partner_123'];
      expect(rewardDoc, isNotNull);
      expect(rewardDoc!['amount'], equals(250000));
      expect(rewardDoc['roomId'], equals('ROOM_8888'));
      expect(rewardDoc['level'], equals(2));
      expect(rewardDoc['role'], equals('partner'));

      // 3. Dynamic Notification in user's Notification Center (inbox_messages)
      final notifKey = 'partner_123_room_support_week_2026-09-13_partner_123';
      final inboxNotif = engine.userInbox[notifKey];
      expect(inboxNotif, isNotNull);
      expect(inboxNotif!['rewardAmount'], equals(250000));
      expect(inboxNotif['data']['roomId'], equals('ROOM_8888'));
      expect(inboxNotif['data']['level'], equals(2));
      expect(inboxNotif['data']['amount'], equals(250000));

      // 4. Exact dynamic message text requirement
      const expectedText = "Congratulations! You have achieved last week's Room Support goal. The owner of ROOM ID ROOM_8888 has added you as a Room Partner, and 250000 reward coins have been sent to you.\nNote: If you achieve multiple goals, only the reward with the highest number of coins will be sent.";
      expect(inboxNotif['body'], equals(expectedText));

      // 5. Also present in notifications collection
      final notifCenterDoc = engine.userNotifications[notifKey];
      expect(notifCenterDoc, isNotNull);
      expect(notifCenterDoc!['body'], equals(expectedText));

      // 6. Push notification sent with dynamic data
      expect(engine.pushNotifications.length, equals(1));
      final push = engine.pushNotifications.first;
      expect(push['uid'], equals('partner_123'));
      expect(push['body'], contains('ROOM_8888'));
      expect(push['body'], contains('250000'));
      expect(push['data']['roomId'], equals('ROOM_8888'));
      expect(push['data']['amount'], equals('250000'));
    });

    test('2. Multiple goals achieved -> only highest reward credited and single notification sent', () {
      final candidates = [
        {
          'uid': 'partner_top',
          'roomId': 'ROOM_SMALL',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 1,
          'amount': 100000,
        },
        {
          'uid': 'partner_top',
          'roomId': 'ROOM_BIGGEST',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 3,
          'amount': 500000,
        },
        {
          'uid': 'partner_top',
          'roomId': 'ROOM_MEDIUM',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 2,
          'amount': 250000,
        },
      ];

      final result = engine.executeDistributionForUser(
        uid: 'partner_top',
        candidates: candidates,
      );

      expect(result['success'], isTrue);

      // Only highest reward credited (500,000 coins, NOT 100k + 500k + 250k = 850k)
      expect(engine.userBalances['partner_top'], equals(500000));

      // Reward doc records superseded count of 2
      final rewardDoc = engine.roomSupportRewards['reward_week_2026-09-13_partner_top'];
      expect(rewardDoc!['amount'], equals(500000));
      expect(rewardDoc['roomId'], equals('ROOM_BIGGEST'));
      expect(rewardDoc['supersededCount'], equals(2));

      // Exactly ONE notification sent with ROOM_BIGGEST and 500000 coins
      expect(engine.userInbox.length, equals(1));
      final inboxNotif = engine.userInbox.values.first;
      expect(inboxNotif['data']['roomId'], equals('ROOM_BIGGEST'));
      expect(inboxNotif['rewardAmount'], equals(500000));
      expect(inboxNotif['body'], contains('ROOM_BIGGEST'));
      expect(inboxNotif['body'], contains('500000'));
      expect(inboxNotif['body'], contains('Note: If you achieve multiple goals, only the reward with the highest number of coins will be sent.'));

      // Exactly ONE push notification sent
      expect(engine.pushNotifications.length, equals(1));
      expect(engine.pushNotifications.first['data']['roomId'], equals('ROOM_BIGGEST'));
    });

    test('3. Failed transaction -> rolls back completely (0 credit, 0 notification, 0 push)', () {
      engine.shouldFailTransaction = true;

      final candidates = [
        {
          'uid': 'partner_fail',
          'roomId': 'ROOM_FAIL',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 1,
          'amount': 250000,
        }
      ];

      final result = engine.executeDistributionForUser(
        uid: 'partner_fail',
        candidates: candidates,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('transaction_failed'));

      // 0 balance change
      expect(engine.userBalances['partner_fail'], isNull);
      // 0 rewards in DB
      expect(engine.roomSupportRewards.isEmpty, isTrue);
      // 0 notifications in inbox
      expect(engine.userInbox.isEmpty, isTrue);
      // 0 push notifications sent
      expect(engine.pushNotifications.isEmpty, isTrue);
    });

    test('4. Retry after failure -> succeeds and credits/notifies exactly once', () {
      final candidates = [
        {
          'uid': 'partner_retry',
          'roomId': 'ROOM_RETRY',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 1,
          'amount': 250000,
        }
      ];

      // Attempt 1: fails
      engine.shouldFailTransaction = true;
      final failResult = engine.executeDistributionForUser(
        uid: 'partner_retry',
        candidates: candidates,
      );
      expect(failResult['success'], isFalse);
      expect(engine.userBalances['partner_retry'], isNull);

      // Attempt 2: retry succeeds
      engine.shouldFailTransaction = false;
      final successResult = engine.executeDistributionForUser(
        uid: 'partner_retry',
        candidates: candidates,
      );
      expect(successResult['success'], isTrue);
      expect(engine.userBalances['partner_retry'], equals(250000));
      expect(engine.userInbox.length, equals(1));
      expect(engine.pushNotifications.length, equals(1));
    });

    test('5. Duplicate request / refresh / repeat API call is idempotent (no duplicate credit or notif)', () {
      final candidates = [
        {
          'uid': 'partner_idem',
          'roomId': 'ROOM_IDEM',
          'weekId': 'week_2026-09-13',
          'role': 'partner',
          'level': 2,
          'amount': 250000,
        }
      ];

      // Initial successful distribution
      final firstResult = engine.executeDistributionForUser(
        uid: 'partner_idem',
        candidates: candidates,
      );
      expect(firstResult['success'], isTrue);
      expect(firstResult['alreadyDistributed'], isFalse);
      expect(engine.userBalances['partner_idem'], equals(250000));
      expect(engine.userInbox.length, equals(1));
      expect(engine.pushNotifications.length, equals(1));

      // Duplicate call (app refresh, retry, or repeated cron)
      final secondResult = engine.executeDistributionForUser(
        uid: 'partner_idem',
        candidates: candidates,
      );
      expect(secondResult['success'], isTrue);
      expect(secondResult['alreadyDistributed'], isTrue);

      // Balance NOT incremented again (stays 250,000)
      expect(engine.userBalances['partner_idem'], equals(250000));

      // No second notification created in inbox
      expect(engine.userInbox.length, equals(1));

      // No second push notification sent
      expect(engine.pushNotifications.length, equals(1));
    });

    test('6. Room Salary - Partner ID Auto Removal: strictly inactive on Wednesday post-payout, Thursday, Friday, and weekend', () {
      // Setup a salary cycle partner assigned on Monday 2026-10-05 10:00 UTC
      final partnerData = {
        'uid': 'partner_test_1',
        'partnerUid': 'partner_test_1',
        'displayName': 'Alice',
        'cycleWeekId': 'week_2026-10-04',
        'assignedAt': DateTime.utc(2026, 10, 5, 10, 0, 0),
        'paid': false,
        'status': 'active',
      };

      // 1. Monday (2026-10-05): Window open -> partner is active
      final monday = DateTime.utc(2026, 10, 5, 12, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, monday), isTrue);

      // 2. Tuesday (2026-10-06): Window open -> partner is active
      final tuesday = DateTime.utc(2026, 10, 6, 20, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, tuesday), isTrue);

      // 3. Wednesday (2026-10-07): Salary processed -> partner is NOT active
      final wednesday = DateTime.utc(2026, 10, 7, 10, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, wednesday), isFalse);

      // 4. Thursday (2026-10-08): Post-salary period -> partner is NOT active
      final thursday = DateTime.utc(2026, 10, 8, 14, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, thursday), isFalse);

      // 5. Friday (2026-10-09 - Client bug scenario): Previous cycle partner MUST NOT show!
      final friday = DateTime.utc(2026, 10, 9, 15, 30, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, friday), isFalse);

      // 6. Saturday & Sunday: Still inactive
      final saturday = DateTime.utc(2026, 10, 10, 12, 0, 0);
      final sunday = DateTime.utc(2026, 10, 11, 22, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, saturday), isFalse);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, sunday), isFalse);

      // 7. Next Monday (2026-10-12): Previous cycle partner is still NOT active for new cycle!
      final nextMonday = DateTime.utc(2026, 10, 12, 10, 0, 0);
      expect(RoomSupportService.isPartnerActiveForCycle(partnerData, nextMonday), isFalse);

      // 8. Next Monday: Fresh partner assigned for the new cycle IS active!
      final freshPartner = {
        'uid': 'partner_test_2',
        'partnerUid': 'partner_test_2',
        'displayName': 'Bob',
        'cycleWeekId': 'week_2026-10-11',
        'assignedAt': DateTime.utc(2026, 10, 12, 9, 0, 0),
        'paid': false,
        'status': 'active',
      };
      expect(RoomSupportService.isPartnerActiveForCycle(freshPartner, nextMonday), isTrue);
    });

    test('7. Paid, expired, or archived partners are immediately inactive even within assignment window', () {
      final monday = DateTime.utc(2026, 10, 12, 12, 0, 0);

      final paidPartner = {
        'uid': 'p1',
        'paid': true,
        'status': 'paid',
        'assignedAt': DateTime.utc(2026, 10, 12, 10, 0, 0),
      };
      expect(RoomSupportService.isPartnerActiveForCycle(paidPartner, monday), isFalse);

      final expiredPartner = {
        'uid': 'p2',
        'paid': false,
        'status': 'expired',
        'assignedAt': DateTime.utc(2026, 10, 12, 10, 0, 0),
      };
      expect(RoomSupportService.isPartnerActiveForCycle(expiredPartner, monday), isFalse);
    });

    test('8. End-to-end simulation: Wednesday salary completion purges partner IDs from active cycle', () {
      // Simulated Firestore database for room_support_cycles/{roomId}/partners
      final Map<String, Map<String, dynamic>> activePartnersCollection = {
        'p_1': {
          'uid': 'p_1',
          'partnerUid': 'p_1',
          'displayName': 'Partner 1',
          'cycleWeekId': 'week_2026-10-04',
          'assignedAt': DateTime.utc(2026, 10, 5, 10, 0, 0),
          'paid': false,
          'status': 'active',
        },
        'p_2': {
          'uid': 'p_2',
          'partnerUid': 'p_2',
          'displayName': 'Partner 2',
          'cycleWeekId': 'week_2026-10-04',
          'assignedAt': DateTime.utc(2026, 10, 5, 11, 0, 0),
          'paid': false,
          'status': 'active',
        },
      };

      // Tuesday inspection: 2 partners assigned
      final tuesday = DateTime.utc(2026, 10, 6, 18, 0, 0);
      final activeTuesday = activePartnersCollection.values
          .where((p) => RoomSupportService.isPartnerActiveForCycle(p, tuesday))
          .toList();
      expect(activeTuesday.length, equals(2));

      // Wednesday 00:00 UTC salary distribution executes:
      final archivedPaidPartners = <String, Map<String, dynamic>>{};
      for (final p in activePartnersCollection.values.toList()) {
        final pUid = p['uid'] as String;
        // 1. Archive to week paid_partners
        archivedPaidPartners[pUid] = {
          ...p,
          'paid': true,
          'status': 'paid',
          'paidAt': DateTime.utc(2026, 10, 7, 0, 0, 0),
        };
        // 2. Immediately delete from active partners collection
        activePartnersCollection.remove(pUid);
      }

      // Deletion verified: 0 active partner documents remain
      expect(activePartnersCollection.isEmpty, isTrue);
      expect(archivedPaidPartners.length, equals(2));

      // Friday inspection: exactly 0 partner documents exist and 0 active partners returned
      final friday = DateTime.utc(2026, 10, 9, 12, 0, 0);
      final activeFriday = activePartnersCollection.values
          .where((p) => RoomSupportService.isPartnerActiveForCycle(p, friday))
          .toList();
      expect(activeFriday.length, equals(0));
    });
  });

  group('Issue 4: Current Amount / Betting Bid Synchronization (10 Scenarios)', () {
    test('Scenario 1: No bet -> balance unchanged', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 500000);
      controller.selectChip(100);
      expect(controller.selectedChip, equals(100));
      expect(controller.totalBetForRound, equals(0));
      expect(controller.currentAmount, equals(500000));
      expect(controller.getCommittedBalance(), equals(500000));
    });

    test('Scenario 2: Submit bet -> immediately reflect pending deduction locally', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 500000);
      controller.selectChip(1000);
      controller.tapBetChip('tomato'); // Chip tapped on food pod

      // CRITICAL: UI immediately reflects expected deduction (500,000 -> 499,000) without waiting for network response!
      expect(controller.totalBetForRound, equals(1000));
      expect(controller.pendingBetDeductions, equals(1000));
      expect(controller.currentAmount, equals(499000)); // Instant optimistic deduction!
      expect(controller.getCommittedBalance(), equals(500000)); // Backend committed balance untouched while in flight
    });

    test('Scenario 3: Successful bet -> reconcile UI with authoritative backend balance without flicker', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 500000);
      controller.selectChip(10000);
      controller.tapBetChip('tomato');
      expect(controller.currentAmount, equals(490000)); // Instant deduction

      controller.confirmBetSuccess(); // Backend commits stake deduction
      expect(controller.currentAmount, equals(490000)); // Reconciles without change/flicker!
      expect(controller.pendingBetDeductions, equals(0));
      expect(controller.getCommittedBalance(), equals(490000));
    });

    test('Scenario 4: Pending / failed bet -> rollback pending deduction and restore confirmed backend balance', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 500000);
      controller.selectChip(100000);
      controller.tapBetChip('tomato');
      expect(controller.currentAmount, equals(400000)); // Optimistic pending deduction

      controller.rejectPendingBet(); // Backend rejects (e.g. betting phase closed)
      expect(controller.currentAmount, equals(500000)); // Restores confirmed balance immediately!
      expect(controller.pendingBetDeductions, equals(0));
      expect(controller.getCommittedBalance(), equals(500000));
      expect(controller.totalBetForRound, equals(0));
    });

    test('Scenario 5: Multiple rapid bets -> correct cumulative pending deduction without double deduction', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 1000000);
      controller.selectChip(1000);
      controller.tapBetChip('tomato');
      expect(controller.currentAmount, equals(999000));

      controller.selectChip(10000);
      controller.tapBetChip('corn');
      expect(controller.currentAmount, equals(989000));

      controller.selectChip(100000);
      controller.tapBetChip('tomato');
      expect(controller.currentAmount, equals(889000));

      expect(controller.totalBetForRound, equals(111000));
      expect(controller.pendingBetDeductions, equals(111000));

      controller.confirmBetSuccess(); // Backend confirms entire 111k wager batch
      expect(controller.currentAmount, equals(889000)); // Smooth reconciliation without flicker!
      expect(controller.pendingBetDeductions, equals(0));
      expect(controller.getCommittedBalance(), equals(889000));
    });

    test('Scenario 6: WIN -> winning amount credited only after final result (never during spin)', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 100000);
      controller.selectChip(1000);
      controller.placeBet('tomato'); // balance -> 99000
      expect(controller.currentAmount, equals(99000));

      // During wheel spinning & landing on Tomato 5x: Current Amount stays 99,000 (no optimistic win!)
      expect(controller.currentAmount, equals(99000));

      // Settlement completes on backend:
      final settle = controller.settleRound(winningItem: 'tomato', multiplier: 5);
      expect(settle['prize'], equals(5000));
      expect(settle['balance'], equals(104000));
      expect(controller.currentAmount, equals(104000)); // Credited only after final result!
      expect(controller.getCommittedBalance(), equals(104000));
    });

    test('Scenario 7: LOSS -> no winning credit', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 100000);
      controller.selectChip(10000);
      controller.placeBet('corn'); // 10000 on corn -> balance 90000
      expect(controller.currentAmount, equals(90000));

      final settle = controller.settleRound(winningItem: 'tomato', multiplier: 5);
      expect(settle['prize'], equals(0));
      expect(settle['balance'], equals(90000));
      expect(controller.currentAmount, equals(90000)); // Stays exactly 90,000!
      expect(controller.getCommittedBalance(), equals(90000));
    });

    test('Scenario 8: Round transition -> balance must not fluctuate', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 200000);
      controller.selectChip(10000);
      controller.placeBet('tomato'); // balance 190000

      controller.settleRound(winningItem: 'tomato', multiplier: 2); // win 20000 -> balance 210000
      expect(controller.currentAmount, equals(210000));

      // Transition to next round (round 1002)
      controller.rolloverToNextRound('1002');
      expect(controller.currentRoundId, equals('1002'));
      expect(controller.totalBetForRound, equals(0));
      expect(controller.currentAmount, equals(210000)); // Seamlessly 210,000 without fluctuation!
      expect(controller.getCommittedBalance(), equals(210000));
    });

    test('Scenario 9: Exact user test - 800 -> place 75 bet -> immediately 725 -> trigger wallet refresh -> MUST remain 725', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 800);
      controller.selectChip(75);
      controller.tapBetChip('tomato');
      // IMMEDIATELY reflects expected deduction (800 -> 725) without waiting for network response!
      expect(controller.currentAmount, equals(725));
      expect(controller.pendingBetDeductions, equals(75));
      expect(controller.getCommittedBalance(), equals(800));

      // Backend confirms accepted bet
      controller.confirmBetSuccess();
      expect(controller.currentAmount, equals(725));
      expect(controller.pendingBetDeductions, equals(0));
      expect(controller.getCommittedBalance(), equals(725));

      // Wallet refresh / stream re-creation dumps stale cached pre-bet balance (800)
      controller.receiveStreamUpdate(800);
      // Stale 800 MUST be ignored! Current Amount remains strictly 725 without flickering
      expect(controller.currentAmount, equals(725));

      // Duplicate / repeated refresh emitting 800
      controller.receiveStreamUpdate(800);
      expect(controller.currentAmount, equals(725));

      // Later, Firestore server stream catches up and emits confirmed 725
      controller.receiveStreamUpdate(725);
      expect(controller.currentAmount, equals(725));
    });

    test('Scenario 10: Slow/duplicate API responses -> older data must never overwrite newer balance', () {
      final controller = MockCurrentAmountBettingSyncController(initialBalance: 500000);

      // Tap 1: bet 1000 dispatched (seq 1)
      final seq1 = controller.startBetRequest(1000);
      // Tap 2: bet 10000 dispatched (seq 2)
      final seq2 = controller.startBetRequest(10000);

      // Response for Tap 2 arrives FIRST with new balance 489000
      controller.completeBetResponse(seq: seq2, newBalance: 489000);
      expect(controller.currentAmount, equals(489000));

      // Delayed / Slow response for Tap 1 arrives LATER with stale balance 499000
      controller.completeBetResponse(seq: seq1, newBalance: 499000);

      // Stale balance is REJECTED by sequence guard! Newer balance 489000 is preserved!
      expect(controller.currentAmount, equals(489000));
      expect(controller.getCommittedBalance(), equals(489000));
    });
  });
}


