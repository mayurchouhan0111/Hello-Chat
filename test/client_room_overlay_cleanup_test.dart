import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';
import 'package:hello_chat/core/services/floating_room_overlay_manager.dart';

void main() {
  testWidgets('ending the displayed session removes its actual overlay entry', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      pageContext = context;
      return const SizedBox.shrink();
    })));
    final notifier = RoomOverlayNotifier();
    addTearDown(notifier.dispose);
    notifier.minimize('displayed', ctx: pageContext);
    expect(floatingRoomOverlayManager.currentRoomId, 'displayed');
    expect(floatingRoomOverlayManager.isInitialized, isTrue);
    notifier.endSession('displayed');
    expect(floatingRoomOverlayManager.currentRoomId, isNull);
    expect(floatingRoomOverlayManager.isInitialized, isFalse);
    expect(notifier.state.roomId, isNull);
    expect(notifier.isRestoringSession('displayed'), isFalse);
    await tester.pump();
  });
}
