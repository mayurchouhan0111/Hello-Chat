import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Query, Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/base_firebase_service.dart';
import '../../core/services/game_recovery_service.dart';
import '../../core/services/game_service.dart';
import 'auth_provider.dart';

enum GameType { spinWheel, luckyDraw }

class GameResult {
  final double multiplier;
  final int prize;
  final String label;

  GameResult(
      {required this.multiplier, required this.prize, required this.label});
}

// 🎮 Game Action Notifier (For spinning and playing)
class GameNotifier extends StateNotifier<AsyncValue<GameResult?>>
    with BaseFirebaseService {
  GameNotifier() : super(const AsyncValue.data(null));

  Future<void> playSpinWheel(int betAmount) async {
    state = const AsyncValue.loading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(false); // Ensure cached auth token
      }

      final data = await callFunction('playSpinWheel', {
        'betAmount': betAmount,
      }) as Map<String, dynamic>;

      final gameResult = GameResult(
        multiplier: (data['prize'] as int) / betAmount,
        prize: data['prize'] as int,
        label: data['label'] as String,
      );

      state = AsyncValue.data(gameResult);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> playLuckyDraw(int betAmount) async {
    state = const AsyncValue.loading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(false);
      }

      final data = await callFunction('playLuckyDraw', {
        'betAmount': betAmount,
      }) as Map<String, dynamic>;

      final isWin = data['isWin'] as bool;
      final prize = data['prize'] as int;

      state = AsyncValue.data(GameResult(
        multiplier: isWin ? (prize / betAmount) : 0,
        prize: prize,
        label: isWin ? "Win (${prize / betAmount}x)" : "Loss",
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final gameActionProvider =
    StateNotifierProvider<GameNotifier, AsyncValue<GameResult?>>((ref) {
  return GameNotifier();
});

// ⚙️ Game Settings Stream Provider
final gameSettingsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final defaultSettings = {
    'isActive': true,
    'minWager': 10,
    'maxWager': 5000,
    'maxWinCap': 50000,
    'dailyProfitLimit': 100000,
    'roundDurationMs': 40000,
    'bettingDurationSeconds': 10,
    'revealDurationSeconds': 5,
    'segments': [
      {
        'id': '1',
        'name': 'Hotdog',
        'multiplier': 10,
        'weight': 100,
        'emoji': '🌭',
        'category': 'pizza'
      },
      {
        'id': '2',
        'name': 'Skewer',
        'multiplier': 15,
        'weight': 50,
        'emoji': '🍢',
        'category': 'pizza'
      },
      {
        'id': '3',
        'name': 'Chicken',
        'multiplier': 25,
        'weight': 30,
        'emoji': '🍗',
        'category': 'pizza'
      },
      {
        'id': '4',
        'name': 'Steak',
        'multiplier': 45,
        'weight': 20,
        'emoji': '🥩',
        'category': 'pizza'
      },
      {
        'id': '5',
        'name': 'Carrot',
        'multiplier': 5,
        'weight': 250,
        'emoji': '🥕',
        'category': 'salad'
      },
      {
        'id': '6',
        'name': 'Corn',
        'multiplier': 5,
        'weight': 250,
        'emoji': '🌽',
        'category': 'salad'
      },
      {
        'id': '7',
        'name': 'Cabbage',
        'multiplier': 5,
        'weight': 150,
        'emoji': '🥬',
        'category': 'salad'
      },
      {
        'id': '8',
        'name': 'Tomato',
        'multiplier': 5,
        'weight': 250,
        'emoji': '🍅',
        'category': 'salad'
      },
    ]
  };

  return FirebaseFirestore.instance
      .collection('game_settings')
      .doc('lucky_spin')
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) {
      return defaultSettings;
    }
    final data = snap.data()!;
    return {
      ...defaultSettings,
      ...data,
      'segments':
          (data['segments'] is List && (data['segments'] as List).isNotEmpty)
              ? data['segments']
              : defaultSettings['segments'],
    };
  });
});

// 📊 Lucky Spin Stats Stream Provider (Full Stats & History)
final luckySpinStatsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) {
      return {
        'currentRound': 1,
        'totalPool': 0,
        'todayWinners': [],
        'recentResults': [],
        'history': [],
      };
    }
    final data = Map<String, dynamic>.from(snap.data()!);
    data['recentResults'] = (data['recentResults'] as List? ?? []).isNotEmpty
        ? data['recentResults']
        : (data['history'] ?? []);
    data['lastWinnerName'] =
        data['lastWinnerName'] ?? data['lastRound']?['winnerName'] ?? "None";
    data['lastWinnerAmount'] =
        data['lastWinnerAmount'] ?? data['lastRound']?['winnerAmount'] ?? 0;
    return data;
  });
});

/// App-scoped coordinator that guarantees any Spin Wheel bet placed before
/// a round completes is flushed and automatically settled at round completion
/// (~35.3s), even if the user leaves [SpinWheelScreen] early.
class SpinWheelBackgroundSettler {
  SpinWheelBackgroundSettler(this._ref);

  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};
  final Set<String> _settled = {};
  bool _disposed = false;

  static const int roundDurationMs = 40000;
  static const int roundRevealOffsetMs = 35300;

  void trackRound(String roundId, {int serverTimeOffsetMs = 0}) {
    if (_disposed || roundId.isEmpty || _settled.contains(roundId)) return;
    final roundNum = int.tryParse(roundId);
    if (roundNum == null || roundNum <= 0) return;

    final revealEpochMs = (roundNum * roundDurationMs) + roundRevealOffsetMs;
    final nowMs = DateTime.now().millisecondsSinceEpoch + serverTimeOffsetMs;
    final delayMs = revealEpochMs - nowMs;

    if (delayMs <= 0) {
      _timers.remove(roundId)?.cancel();
      unawaited(settleNow(roundId));
      return;
    }

    if (_timers.containsKey(roundId)) return;
    _timers[roundId] = Timer(Duration(milliseconds: delayMs + 250), () {
      _timers.remove(roundId);
      if (!_disposed) {
        unawaited(settleNow(roundId));
      }
    });
    debugPrint(
        '[SPIN_WHEEL_SETTLER] Scheduled background settlement for round $roundId in ${delayMs + 250}ms');
  }

  Future<void> flushBetAndScheduleSettlement({
    required String roundId,
    required Map<String, int> bets,
    String? roomId,
    int serverTimeOffsetMs = 0,
  }) async {
    if (_disposed || bets.isEmpty || roundId.isEmpty) return;
    final totalBet = bets.values.fold<int>(0, (sum, v) => sum + v);
    if (totalBet <= 0) return;

    String effectiveRoundId = roundId;
    try {
      final result = await _ref.read(gameServiceProvider).playSpinWheel(
            betAmount: totalBet,
            bets: bets,
            roundId: roundId,
            roomId: roomId,
            txnId: 'bet_$roundId',
          );
      final serverRound = result['roundId']?.toString();
      if (serverRound != null && serverRound.isNotEmpty) {
        effectiveRoundId = serverRound;
      }
      await GameRecoveryService().clearBetState();
      debugPrint(
          '[SPIN_WHEEL_SETTLER] Flushed on-exit bets for round $effectiveRoundId (totalBet=$totalBet)');
    } catch (e) {
      debugPrint(
          '[SPIN_WHEEL_SETTLER] Exit bet flush note for round $roundId: $e');
    } finally {
      if (!_disposed) {
        trackRound(effectiveRoundId, serverTimeOffsetMs: serverTimeOffsetMs);
      }
    }
  }

  Future<void> settleNow(String roundId, {int attempt = 0}) async {
    if (_disposed ||
        roundId.isEmpty ||
        _settled.contains(roundId) ||
        _inFlight.contains(roundId)) {
      return;
    }
    _inFlight.add(roundId);
    try {
      final res = await _ref
          .read(gameServiceProvider)
          .settleSpinWheelRound(roundId: roundId);
      if (res['settled'] == true) {
        _settled.add(roundId);
        _timers.remove(roundId)?.cancel();
        _ref.invalidate(luckySpinStatsProvider);
        _ref.invalidate(luckySpinLeaderboardProvider);
        debugPrint(
            '[SPIN_WHEEL_SETTLER] Auto-settled exited/pending round $roundId (prize=${res['prize']}, balance=${res['balance']})');
      }
    } catch (e) {
      debugPrint(
          '[SPIN_WHEEL_SETTLER] Auto-settle attempt ${attempt + 1} failed for round $roundId: $e');
      if (!_disposed && attempt < 3) {
        _timers.remove(roundId)?.cancel();
        _timers[roundId] = Timer(const Duration(seconds: 3), () {
          _timers.remove(roundId);
          unawaited(settleNow(roundId, attempt: attempt + 1));
        });
      }
    } finally {
      _inFlight.remove(roundId);
    }
  }

  void syncFromHistory(
    List<Map<String, dynamic>> history, {
    int serverTimeOffsetMs = 0,
  }) {
    if (_disposed) return;
    for (final item in history) {
      final isSpin = item['game'] == 'spin_wheel' ||
          (item['docId']?.toString().startsWith('spin_') ?? false);
      if (!isSpin) continue;

      final rId = item['roundId']?.toString() ??
          item['docId']?.toString().replaceFirst('spin_', '') ??
          '';
      if (rId.isEmpty) continue;

      final isSettled = item['settled'] == true ||
          item['status'] == 'ROUND_SETTLED' ||
          item['status'] == 'REVERTED';
      if (isSettled) {
        _settled.add(rId);
        _timers.remove(rId)?.cancel();
        continue;
      }

      trackRound(rId, serverTimeOffsetMs: serverTimeOffsetMs);
    }
  }

  void dispose() {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final spinWheelBackgroundSettlerProvider =
    Provider<SpinWheelBackgroundSettler>((ref) {
  final settler = SpinWheelBackgroundSettler(ref);
  ref.onDispose(settler.dispose);
  return settler;
});

// 📜 User's private game history
final userGameHistoryProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  // Keep alive so active stream isn't destroyed when sub-widgets toggle or rebuild
  ref.keepAlive();

  final user = ref.watch(authStateProvider).value ??
      FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final settler = ref.read(spinWheelBackgroundSettlerProvider);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('game_history')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) {
    final rawDocs = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['docId'] = d.id;
      return data;
    }).toList();

    // Robust in-memory sorting: roundId descending (newest rounds first), then timestamp / createdAt, then serialNumber
    rawDocs.sort((a, b) {
      final rA = int.tryParse(a['roundId']?.toString() ?? '') ?? 0;
      final rB = int.tryParse(b['roundId']?.toString() ?? '') ?? 0;
      if (rA > 0 && rB > 0 && rA != rB) return rB.compareTo(rA);

      final tA = a['timestamp'];
      final tB = b['timestamp'];
      if (tA is Timestamp && tB is Timestamp) {
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

    // Deduplicate by roundId so multiple bet events in the same round never double-count winnings or render duplicate cards.
    // Prefer the settled record over a staged (unsettled) record for the same round, so the realtime ledger
    // only surfaces ROUND_SETTLED (or REVERTED) outcomes and never a mid-round pending bet.
    final seenRounds = <String>{};
    final deduplicated = <Map<String, dynamic>>[];
    for (final item in rawDocs) {
      final roundId = item['roundId']?.toString();
      if (roundId != null && roundId.isNotEmpty) {
        if (seenRounds.contains(roundId)) {
          final existingIndex = deduplicated
              .indexWhere((e) => e['roundId']?.toString() == roundId);
          final isSettled = item['settled'] == true ||
              item['status'] == 'ROUND_SETTLED' ||
              item['status'] == 'REVERTED';
          if (existingIndex >= 0 && isSettled) {
            deduplicated[existingIndex] = item;
          }
          continue;
        }
        seenRounds.add(roundId);
      }
      deduplicated.add(item);
    }

    // Automatically track & settle any completed unsettled Spin Wheel rounds
    settler.syncFromHistory(deduplicated);

    return deduplicated;
  }).handleError((e) {
    debugPrint("userGameHistoryProvider error: $e");
    return <Map<String, dynamic>>[];
  });
});

// 🎫 Lucky Draw Settings Provider
final luckyDrawSettingsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final defaultDrawSettings = {
    'isActive': true,
    'ticketPrices': [10, 50, 100, 500],
    'currentPrizePool': 1250450,
    'frequencyMinutes': 30,
  };

  return FirebaseFirestore.instance
      .collection('game_settings')
      .doc('lucky_draw')
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return defaultDrawSettings;
    return {
      ...defaultDrawSettings,
      ...snap.data()!,
    };
  });
});

// Both the daily sheet and all room banners use the same settled standings.
Query<Map<String, dynamic>> _wheelStandings() => FirebaseFirestore.instance
    .collection('games_meta/lucky_spin/daily_players')
    .orderBy('totalWinnings', descending: true)
    .orderBy('totalBets', descending: true);

final luckySpinLeaderboardProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return _wheelStandings().limit(100).snapshots().map((snapshot) => [
        for (final row in snapshot.docs) {...row.data(), 'uid': row.id},
      ]);
});

final luckySpinLeaderProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final service = ref.watch(gameServiceProvider);
  return _wheelStandings().limit(1).snapshots().asyncMap((snapshot) async {
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    if (((data['totalWinnings'] as num?) ?? 0) <= 0) return null;
    if (data['totalWins'] is! num) {
      // Older leaderboard documents need one server-side receipt count.
      await service.callFunction('hydrateLuckySpinLeader');
      return null; // The updated document arrives on this same subscription.
    }
    return {...data, 'uid': doc.id};
  });
});

/// One server-authored Top-1 event per completed wheel round. Room UIs treat
/// this as a transient broadcast, never as a persistent leaderboard card.
final luckySpinWinnerEventProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .snapshots()
      .map((snapshot) {
    final event = snapshot.data()?['topWinnerEvent'];
    if (event is! Map) return null;
    return Map<String, dynamic>.from(event);
  });
});

// 🏆 Current Round Top 3 Players (Highest Bettors) Stream Provider
final luckySpinCurrentRoundWinnersProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, roundId) {
  if (roundId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .collection('round_player_bets')
      .where('roundId', isEqualTo: roundId)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((d) => d.data()).toList();
    // Top 3 players who placed the highest bets in the completed round
    list.sort((a, b) {
      final aBet = (a['totalBet'] as num?)?.toInt() ?? 0;
      final bBet = (b['totalBet'] as num?)?.toInt() ?? 0;
      if (bBet != aBet) return bBet.compareTo(aBet);
      final aWin = (a['winnings'] as num?)?.toInt() ??
          (a['prize'] as num?)?.toInt() ??
          0;
      final bWin = (b['winnings'] as num?)?.toInt() ??
          (b['prize'] as num?)?.toInt() ??
          0;
      return bWin.compareTo(aWin);
    });
    return list.take(3).toList();
  });
});

// 👥 Participating Players in Current Round Stream Provider
final luckySpinRoundPlayersProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, roundId) {
  if (roundId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .collection('round_player_bets')
      .where('roundId', isEqualTo: roundId)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((d) => d.data()).toList();
    list.sort((a, b) {
      final aBet = (a['totalBet'] as num?)?.toInt() ?? 0;
      final bBet = (b['totalBet'] as num?)?.toInt() ?? 0;
      return bBet.compareTo(aBet);
    });
    return list;
  });
});
