import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/base_firebase_service.dart';
import '../../core/services/game_service.dart';

enum GameType { spinWheel, luckyDraw }

class GameResult {
  final double multiplier;
  final int prize;
  final String label;

  GameResult({required this.multiplier, required this.prize, required this.label});
}

// 🎮 Game Action Notifier (For spinning and playing)
class GameNotifier extends StateNotifier<AsyncValue<GameResult?>> with BaseFirebaseService {
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

final gameActionProvider = StateNotifierProvider<GameNotifier, AsyncValue<GameResult?>>((ref) {
  return GameNotifier();
});

// ⚙️ Game Settings Stream Provider
final gameSettingsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
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
      {'id': '1', 'name': 'Apple', 'multiplier': 2, 'weight': 550, 'emoji': '🍎'},
      {'id': '2', 'name': 'Orange', 'multiplier': 3, 'weight': 250, 'emoji': '🍊'},
      {'id': '3', 'name': 'Banana', 'multiplier': 5, 'weight': 100, 'emoji': '🍌'},
      {'id': '4', 'name': 'Watermelon', 'multiplier': 8, 'weight': 50, 'emoji': '🍉'},
      {'id': '5', 'name': 'Grape', 'multiplier': 10, 'weight': 30, 'emoji': '🍇'},
      {'id': '6', 'name': 'Peach', 'multiplier': 12, 'weight': 10, 'emoji': '🍑'},
      {'id': '7', 'name': 'Strawberry', 'multiplier': 15, 'weight': 9, 'emoji': '🍓'},
      {'id': '8', 'name': 'Pineapple', 'multiplier': 100, 'weight': 1, 'emoji': '🍍'},
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
          'segments': (data['segments'] is List && (data['segments'] as List).isNotEmpty)
              ? data['segments']
              : defaultSettings['segments'],
        };
      });
});

// 📊 Lucky Spin Stats Stream Provider (Full Stats & History)
final luckySpinStatsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
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
        data['lastWinnerName'] = data['lastWinnerName'] ?? data['lastRound']?['winnerName'] ?? "None";
        data['lastWinnerAmount'] = data['lastWinnerAmount'] ?? data['lastRound']?['winnerAmount'] ?? 0;
        return data;
      });
});

// 📜 User's private game history
final userGameHistoryProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('game_history')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList())
      .handleError((e) {
        return <Map<String, dynamic>>[];
      });
});

// 🎫 Lucky Draw Settings Provider
final luckyDrawSettingsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
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

// 🏆 Daily Top Players / Winners Leaderboard Stream Provider
final luckySpinLeaderboardProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .collection('daily_players')
      .snapshots()
      .map((snap) {
        final docs = snap.docs.map((d) => d.data()).toList();
        docs.sort((a, b) {
          final aW = (a['totalWinnings'] as num?)?.toInt() ?? 0;
          final bW = (b['totalWinnings'] as num?)?.toInt() ?? 0;
          if (bW != aW) return bW.compareTo(aW);
          final aB = (a['totalBets'] as num?)?.toInt() ?? 0;
          final bB = (b['totalBets'] as num?)?.toInt() ?? 0;
          return bB.compareTo(aB);
        });
        return docs.take(100).toList();
      });
});

// 🏆 Current Round Bets / Winners Stream Provider (Top 3)
final luckySpinCurrentRoundWinnersProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, roundId) {
  if (roundId.isEmpty) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .collection('current_round_bets')
      .where('roundId', isEqualTo: roundId)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => d.data())
            .where((a) => ((a['winnings'] as num?)?.toInt() ?? 0) > 0)
            .toList();
        list.sort((a, b) {
          final aWinnings = (a['winnings'] as num?)?.toInt() ?? 0;
          final bWinnings = (b['winnings'] as num?)?.toInt() ?? 0;
          return bWinnings.compareTo(aWinnings);
        });
        return list.take(3).toList();
      });
});
