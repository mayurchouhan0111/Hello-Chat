import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';

class GameService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Starts a "Spin the Wheel" game. 
  /// Result is calculated server-side via Cloud Functions to prevent cheating.
  Future<Map<String, dynamic>> playSpinWheel({
    required int betAmount,
    Map<String, int>? bets,
    String? roomId,
  }) async {
    final result = await callFunction('playSpinWheel', {
      'betAmount': betAmount,
      'bets': bets,
      'roomId': roomId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Entry for "Lucky Draw" mini-game.
  Future<Map<String, dynamic>> playLuckyDraw({
    required int betAmount,
    String? roomId,
  }) async {
    final result = await callFunction('playLuckyDraw', {
      'betAmount': betAmount,
      'roomId': roomId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Fetches game history from the user's private subcollection.
  Stream<List<Map<String, dynamic>>> getGameHistory(String uid) {
    return _db.collection('users')
        .doc(uid)
        .collection('game_history')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Configures game limits (Admin only via Cloud Functions).
  Future<void> updateGameConfig({
    required String gameId,
    required Map<String, dynamic> config,
  }) async {
    await callFunction('updateGameConfig', {
      'gameId': gameId,
      'config': config,
    });
  }
}

final gameServiceProvider = Provider<GameService>((ref) => GameService());

final gameHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(gameServiceProvider).getGameHistory(uid);
});
