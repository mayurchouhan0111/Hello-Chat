import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

enum GameType { spinWheel, luckyDraw }

class GameResult {
  final double multiplier;
  final int prize;
  final String label;

  GameResult({required this.multiplier, required this.prize, required this.label});
}

class GameNotifier extends StateNotifier<AsyncValue<GameResult?>> {
  GameNotifier() : super(const AsyncValue.data(null));

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // 1. Play Spin Wheel (Now calling Secure Cloud Function)
  Future<void> playSpinWheel(int betAmount) async {
    state = const AsyncValue.loading();
    try {
      final result = await _functions.httpsCallable('playSpinWheel').call({
        'betAmount': betAmount,
      });

      final data = result.data as Map<String, dynamic>;
      final gameResult = GameResult(
        multiplier: (data['prize'] as int) / betAmount,
        prize: data['prize'] as int,
        label: data['label'] as String,
      );

      state = AsyncValue.data(gameResult);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // 2. Play Lucky Draw (Now calling Secure Cloud Function)
  Future<void> playLuckyDraw(int betAmount) async {
    state = const AsyncValue.loading();
    try {
      final result = await _functions.httpsCallable('playLuckyDraw').call({
        'betAmount': betAmount,
      });

      final data = result.data as Map<String, dynamic>;
      final isWin = data['isWin'] as bool;
      final prize = data['prize'] as int;

      state = AsyncValue.data(GameResult(
        multiplier: isWin ? (prize / betAmount) : 0,
        prize: prize,
        label: isWin ? "Win (${prize / betAmount}x)" : "Loss",
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final gameActionProvider = StateNotifierProvider<GameNotifier, AsyncValue<GameResult?>>((ref) {
  return GameNotifier();
});

final gameHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('game_history')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
