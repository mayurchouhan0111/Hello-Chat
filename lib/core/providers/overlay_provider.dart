import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomOverlayState {
  final String? roomId;
  final bool isMinimized;

  RoomOverlayState({this.roomId, this.isMinimized = false});

  RoomOverlayState copyWith({String? roomId, bool? isMinimized}) {
    return RoomOverlayState(
      roomId: roomId ?? this.roomId,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

class RoomOverlayNotifier extends StateNotifier<RoomOverlayState> {
  RoomOverlayNotifier() : super(RoomOverlayState());

  void minimize(String roomId) {
    state = RoomOverlayState(roomId: roomId, isMinimized: true);
  }

  void restore() {
    state = state.copyWith(isMinimized: false);
  }

  void clear() {
    state = RoomOverlayState();
  }
}

final roomOverlayProvider = StateNotifierProvider<RoomOverlayNotifier, RoomOverlayState>((ref) {
  return RoomOverlayNotifier();
});
