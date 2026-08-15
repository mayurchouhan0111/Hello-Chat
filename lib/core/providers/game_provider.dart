import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
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

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> playSpinWheel(int betAmount) async {
    state = const AsyncValue.loading();
    try {
      final user = _auth.currentUser;
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
      final user = _auth.currentUser;
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
  return FirebaseFirestore.instance
      .collection('game_settings')
      .doc('lucky_spin')
      .snapshots()
      .map((snap) {
        if (!snap.exists) {
          return {
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
        }
        return snap.data()!;
      });
});

// 📊 Lucky Spin Stats Stream Provider
final luckySpinStatsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .snapshots()
      .map((snap) {
        if (!snap.exists) {
          return {
            'currentRound': 1,
            'totalPool': 0,
            'todayWinners': [],
          };
        }
        final data = Map<String, dynamic>.from(snap.data()!);
        data.remove('activeRoundOutcome');
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
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

// 🎫 Lucky Draw Settings Provider
final luckyDrawSettingsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('game_settings')
      .doc('lucky_draw')
      .snapshots()
      .map((snap) => snap.exists ? snap.data()! : {
        'isActive': true,
        'ticketPrices': [10, 50, 100, 500],
        'currentPrizePool': 0,
        'frequencyMinutes': 30,
      });
});

// 🏆 Daily Top Players Leaderboard Stream Provider
final luckySpinLeaderboardProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('games_meta')
      .doc('lucky_spin')
      .collection('daily_players')
      .orderBy('totalBets', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
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
