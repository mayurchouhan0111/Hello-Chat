import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/floating_room_overlay_manager.dart';

class RoomOverlayState {
  final String? roomId;
  final bool isMinimized;

  RoomOverlayState({this.roomId, this.isMinimized = false});

  RoomOverlayState copyWith({String? roomId, bool? isMinimized, bool clearRoomId = false}) {
    return RoomOverlayState(
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

class RoomOverlayNotifier extends StateNotifier<RoomOverlayState> {
  RoomOverlayNotifier() : super(RoomOverlayState());

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  void minimize(String roomId, {BuildContext? ctx}) {
    debugPrint('[RoomOverlayNotifier] minimize called with roomId: $roomId');
    state = RoomOverlayState(roomId: roomId, isMinimized: true);
    
    final contextToUse = ctx ?? _context;
    if (contextToUse != null && contextToUse.mounted) {
      floatingRoomOverlayManager.showOverlay(contextToUse, roomId);
    } else {
      debugPrint('[RoomOverlayNotifier] Context not available for overlay');
    }
  }

  void restore() {
    debugPrint('[RoomOverlayNotifier] restore called');
    state = state.copyWith(isMinimized: false);
    _context = null;
    floatingRoomOverlayManager.removeOverlay();
  }

  void clear() {
    debugPrint('[RoomOverlayNotifier] clear called');
    state = RoomOverlayState();
    _context = null;
    floatingRoomOverlayManager.removeOverlay();
  }

  @override
  void dispose() {
    floatingRoomOverlayManager.removeOverlay();
    super.dispose();
  }
}

final roomOverlayProvider = StateNotifierProvider<RoomOverlayNotifier, RoomOverlayState>((ref) {
  return RoomOverlayNotifier();
});