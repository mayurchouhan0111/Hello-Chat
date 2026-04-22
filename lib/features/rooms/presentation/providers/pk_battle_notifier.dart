import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/services/room_service.dart';

/// State class representing the PK battle.
class PkBattleState {
  final bool pkActive;
  final String? pkWinnerUid;
  final Map<String, int> pkScores;

  const PkBattleState({
    required this.pkActive,
    this.pkWinnerUid,
    required this.pkScores,
  });

  PkBattleState copyWith({
    bool? pkActive,
    String? pkWinnerUid,
    Map<String, int>? pkScores,
  }) {
    return PkBattleState(
      pkActive: pkActive ?? this.pkActive,
      pkWinnerUid: pkWinnerUid ?? this.pkWinnerUid,
      pkScores: pkScores ?? Map<String, int>.from(this.pkScores),
    );
  }
}

/// Riverpod StateNotifier that encapsulates PK battle logic.
class PkBattleNotifier extends StateNotifier<PkBattleState> {
  final Ref ref;

  PkBattleNotifier(this.ref)
      : super(const PkBattleState(pkActive: false, pkScores: {}));

  /// Initialise the state from a RoomModel snapshot.
  void initialiseFromRoom(RoomModel room) {
    state = PkBattleState(
      pkActive: room.pkActive ?? false,
      pkWinnerUid: room.pkWinnerUid,
      pkScores: Map<String, int>.from(room.pkScores ?? {}),
    );
  }

  /// Called when the user attacks / sends a PK challenge.
  Future<void> sendChallenge({required String roomId, required String targetUid}) async {
    await ref.read(roomServiceProvider).invitePKChallenge(roomId: roomId, targetUid: targetUid);
  }

  /// Called when the PK battle ends (either forced or natural).
  Future<void> endBattle(String roomId, {String? forcedWinnerUid}) async {
    await ref.read(roomServiceProvider).endPKBattle(roomId, forcedWinnerUid: forcedWinnerUid);
  }

  /// Update local scores – used by UI when a gift is sent.
  void updateScore(String uid, int delta) {
    final newScores = Map<String, int>.from(state.pkScores);
    newScores.update(uid, (v) => v + delta, ifAbsent: () => delta);
    state = state.copyWith(pkScores: newScores);
  }
}

/// Provider for the PK battle notifier.
final pkBattleProvider = StateNotifierProvider<PkBattleNotifier, PkBattleState>((ref) {
  return PkBattleNotifier(ref);
});
