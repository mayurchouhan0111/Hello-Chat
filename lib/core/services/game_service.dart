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
    String? roundId,
    String? roomId,
  }) async {
    final result = await callFunction('playSpinWheel', {
      'betAmount': betAmount,
      'bets': bets,
      'roundId': roundId,
      'roomId': roomId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Settles winnings for a completed Spin Wheel round.
  Future<Map<String, dynamic>> settleSpinWheelRound({
    required String roundId,
  }) async {
    final result = await callFunction('settleSpinWheelRound', {
      'roundId': roundId,
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

  /// Entry for "Yummy Bingo" 5-reel slot game.
  Future<Map<String, dynamic>> playYummyBingo({
    required int lines,
    required int betPerLine,
    String? roomId,
  }) async {
    final result = await callFunction('playYummyBingo', {
      'lines': lines,
      'betPerLine': betPerLine,
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

  /// Sits user at a Teen Patti table seat in the given room.
  Future<Map<String, dynamic>> joinTeenPattiSeat({
    required String roomId,
    required int seatIndex,
  }) async {
    final result = await callFunction('joinTeenPattiSeat', {
      'roomId': roomId,
      'seatIndex': seatIndex,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Leaves seat at Teen Patti table.
  Future<Map<String, dynamic>> leaveTeenPattiSeat({
    required String roomId,
  }) async {
    final result = await callFunction('leaveTeenPattiSeat', {
      'roomId': roomId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Starts a new Teen Patti round (deals cards and collects boot).
  Future<Map<String, dynamic>> startTeenPattiRound({
    required String roomId,
  }) async {
    final result = await callFunction('startTeenPattiRound', {
      'roomId': roomId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Sends in-game player action (see, chaal, raise, fold, show).
  Future<Map<String, dynamic>> sendTeenPattiAction({
    required String roomId,
    required String action,
    int? amount,
  }) async {
    final result = await callFunction('teenPattiAction', {
      'roomId': roomId,
      'action': action,
      'amount': amount,
    });
    return Map<String, dynamic>.from(result);
  }

  /// Real-time stream of the room's public Teen Patti table document.
  Stream<Map<String, dynamic>?> streamTeenPattiTable(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('games')
        .doc('teen_patti')
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  /// Real-time stream of the user's private hole cards for the room table.
  Stream<List<dynamic>> streamMyTeenPattiCards(String roomId, String uid) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('games')
        .doc('teen_patti')
        .collection('private_cards')
        .doc(uid)
        .snapshots()
        .map((snapshot) => (snapshot.data()?['cards'] as List<dynamic>?) ?? []);
  }
}

final gameServiceProvider = Provider<GameService>((ref) => GameService());

final gameHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(gameServiceProvider).getGameHistory(uid);
});

final teenPattiTableProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, roomId) {
  return ref.watch(gameServiceProvider).streamTeenPattiTable(roomId);
});

final myTeenPattiCardsProvider = StreamProvider.family<List<dynamic>, ({String roomId, String uid})>((ref, arg) {
  return ref.watch(gameServiceProvider).streamMyTeenPattiCards(arg.roomId, arg.uid);
});
