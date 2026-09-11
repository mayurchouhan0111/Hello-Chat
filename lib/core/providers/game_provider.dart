import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
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
      {'id': '1', 'name': 'Tomato', 'multiplier': 5, 'weight': 250, 'emoji': '🍅', 'category': 'salad'},
      {'id': '2', 'name': 'Hotdog', 'multiplier': 10, 'weight': 100, 'emoji': '🌭', 'category': 'pizza'},
      {'id': '3', 'name': 'Skewer', 'multiplier': 15, 'weight': 50, 'emoji': '🍢', 'category': 'pizza'},
      {'id': '4', 'name': 'Chicken', 'multiplier': 25, 'weight': 30, 'emoji': '🍗', 'category': 'pizza'},
      {'id': '5', 'name': 'Steak', 'multiplier': 45, 'weight': 20, 'emoji': '🥩', 'category': 'pizza'},
      {'id': '6', 'name': 'Carrot', 'multiplier': 5, 'weight': 250, 'emoji': '🥕', 'category': 'salad'},
      {'id': '7', 'name': 'Corn', 'multiplier': 5, 'weight': 250, 'emoji': '🌽', 'category': 'salad'},
      {'id': '8', 'name': 'Cabbage', 'multiplier': 5, 'weight': 150, 'emoji': '🥬', 'category': 'salad'},
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
      .limit(100)
      .snapshots()
      .map((snap) {
        final rawDocs = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['docId'] = d.id;
          return data;
        }).toList();

        // Robust in-memory sorting by roundId descending (newest rounds first), then timestamp
        rawDocs.sort((a, b) {
          final rA = int.tryParse(a['roundId']?.toString() ?? '') ?? 0;
          final rB = int.tryParse(b['roundId']?.toString() ?? '') ?? 0;
          if (rA != rB) return rB.compareTo(rA);

          final tA = a['timestamp'];
          final tB = b['timestamp'];
          if (tA is Timestamp && tB is Timestamp) {
            final cmp = tB.compareTo(tA);
            if (cmp != 0) return cmp;
          }
          final sA = int.tryParse(a['serialNumber']?.toString() ?? '') ?? 0;
          final sB = int.tryParse(b['serialNumber']?.toString() ?? '') ?? 0;
          return sB.compareTo(sA);
        });

        // Deduplicate by roundId so multiple bet events in the same round never double-count winnings or render duplicate cards
        final seenRounds = <String>{};
        final deduplicated = <Map<String, dynamic>>[];
        for (final item in rawDocs) {
          final roundId = item['roundId']?.toString();
          if (roundId != null && roundId.isNotEmpty) {
            if (seenRounds.contains(roundId)) {
              continue;
            }
            seenRounds.add(roundId);
          }
          deduplicated.add(item);
        }
        return deduplicated;
      })
      .handleError((e) {
        debugPrint("userGameHistoryProvider error: $e");
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
      .asyncMap((snap) async {
        final docs = snap.docs.map((d) => d.data()).toList();
        if (docs.isNotEmpty) {
          docs.sort((a, b) {
            final aW = (a['totalWinnings'] as num?)?.toInt() ?? (a['amount'] as num?)?.toInt() ?? 0;
            final bW = (b['totalWinnings'] as num?)?.toInt() ?? (b['amount'] as num?)?.toInt() ?? 0;
            if (bW != aW) return bW.compareTo(aW);
            final aB = (a['totalBets'] as num?)?.toInt() ?? 0;
            final bB = (b['totalBets'] as num?)?.toInt() ?? 0;
            return bB.compareTo(aB);
          });
          return docs.take(100).toList();
        }

        // Fallback: Check todayWinners from games_meta/lucky_spin
        try {
          final statsDoc = await FirebaseFirestore.instance.collection('games_meta').doc('lucky_spin').get();
          if (statsDoc.exists && statsDoc.data() != null) {
            final todayWinners = (statsDoc.data()!['todayWinners'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ?? [];
            if (todayWinners.isNotEmpty) {
              todayWinners.sort((a, b) {
                final aW = (a['amount'] as num?)?.toInt() ?? 0;
                final bW = (b['amount'] as num?)?.toInt() ?? 0;
                return bW.compareTo(aW);
              });
              return todayWinners;
            }
          }
        } catch (_) {}

        return <Map<String, dynamic>>[];
      });
});

// 🏆 Current Round Top 3 Players (Highest Bettors) Stream Provider
final luckySpinCurrentRoundWinnersProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, roundId) {
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
          final aWin = (a['winnings'] as num?)?.toInt() ?? (a['prize'] as num?)?.toInt() ?? 0;
          final bWin = (b['winnings'] as num?)?.toInt() ?? (b['prize'] as num?)?.toInt() ?? 0;
          return bWin.compareTo(aWin);
        });
        return list.take(3).toList();
      });
});

// 👥 Participating Players in Current Round Stream Provider
final luckySpinRoundPlayersProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, roundId) {
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
