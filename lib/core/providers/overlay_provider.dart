import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/floating_room_overlay_manager.dart';

class RoomOverlayState {
  final String? roomId;
  final bool isMinimized;
  final Set<String> activeRoomSessions;

  RoomOverlayState({
    this.roomId,
    this.isMinimized = false,
    this.activeRoomSessions = const {},
  });

  RoomOverlayState copyWith({
    String? roomId,
    bool? isMinimized,
    bool clearRoomId = false,
    Set<String>? activeRoomSessions,
  }) {
    return RoomOverlayState(
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      isMinimized: isMinimized ?? this.isMinimized,
      activeRoomSessions: activeRoomSessions ?? this.activeRoomSessions,
    );
  }
}

class RoomOverlayNotifier extends StateNotifier<RoomOverlayState> {
  RoomOverlayNotifier() : super(RoomOverlayState());

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  bool isRestoringSession(String roomId) {
    return state.activeRoomSessions.contains(roomId);
  }

  void registerActiveSession(String roomId) {
    final updated = Set<String>.from(state.activeRoomSessions)..add(roomId);
    state = state.copyWith(activeRoomSessions: updated);
  }

  void endSession(String roomId) {
    final updated = Set<String>.from(state.activeRoomSessions)..remove(roomId);
    state = state.copyWith(
      activeRoomSessions: updated,
      clearRoomId: state.roomId == roomId,
      isMinimized: state.roomId == roomId ? false : state.isMinimized,
    );
    if (state.roomId == roomId) {
      floatingRoomOverlayManager.removeOverlay();
    }
  }

  void minimize(String roomId, {BuildContext? ctx}) {
    debugPrint('[RoomOverlayNotifier] minimize called with roomId: $roomId');
    final updated = Set<String>.from(state.activeRoomSessions)..add(roomId);
    state = state.copyWith(roomId: roomId, isMinimized: true, activeRoomSessions: updated);
    
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
    state = state.copyWith(clearRoomId: true, isMinimized: false);
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