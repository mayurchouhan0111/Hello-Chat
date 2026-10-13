import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/chat_widget.dart';

/// `sendGiftWithCombo` writes one Firestore document per tap, so a 3x combo is
/// three messages. The chat must still paint ONE row, because the row's "xN" is
/// kept moving by GiftComboController.
///
/// These messages routinely arrive together in a single snapshot when taps are
/// fast. The incremental path used to decide each message's fold before queuing
/// any of them, so nothing in the batch could see the message ahead of it and
/// every tap became its own row. That regression is what these assertions catch.
RoomMessage _gift({required String id, required DateTime at, int comboCount = 1}) =>
    RoomMessage(
      msgId: id,
      uid: 'u1',
      text: 'Sent to bob x1',
      type: 'gift',
      giftId: 'rose',
      animationUrl: 'https://x/anim.json',
      targetUid: 'u2',
      quantity: 1,
      comboCount: comboCount,
      createdAt: at,
    );

RoomMessage _chat(String id, DateTime at) => RoomMessage(
      msgId: id,
      uid: 'u1',
      text: 'hello',
      type: 'text',
      createdAt: at,
    );

Widget _wrap(List<RoomMessage> messages) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        cachedUserProfileProvider.overrideWith((ref, uid) => Stream<UserModel?>.value(null)),
        currentRoomStreamProvider.overrideWith((ref, roomId) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: Scaffold(body: ChatWidget(messages: messages, roomId: 'room1')),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 1, 1, 12);

  testWidgets('three combo taps in one snapshot render a single chat row', (tester) async {
    final seed = [_chat('m0', t0)];

    // First reconcile: `_prevMessages` is still empty, so this seeds.
    await tester.pumpWidget(_wrap(seed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Second reconcile: all three combo taps land together - the buggy path.
    await tester.pumpWidget(_wrap([
      _chat('m0', t0),
      _gift(id: 'g1', at: t0.add(const Duration(seconds: 1))),
      _gift(id: 'g2', at: t0.add(const Duration(seconds: 2))),
      _gift(id: 'g3', at: t0.add(const Duration(seconds: 3))),
    ]));
    await tester.pump();

    // Drain the 300ms queue timer generously - the buggy code queues three
    // rows and would show all three, the fixed code one.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Sent to bob'), findsOneWidget,
        reason: 'one combo stream must paint one chat row, not one per tap');
  });

  testWidgets('a later combo still folds into the row already on screen', (tester) async {
    await tester.pumpWidget(_wrap([_chat('m0', t0)]));
    await tester.pump();

    // First tap of the combo becomes the row.
    await tester.pumpWidget(_wrap([
      _chat('m0', t0),
      _gift(id: 'g1', at: t0.add(const Duration(seconds: 1))),
    ]));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Sent to bob'), findsOneWidget);

    // Second tap arrives in its own snapshot a second later: still the same
    // stream, so it must fold into the row rather than append a new one.
    await tester.pumpWidget(_wrap([
      _chat('m0', t0),
      _gift(id: 'g1', at: t0.add(const Duration(seconds: 1))),
      _gift(id: 'g2', at: t0.add(const Duration(seconds: 2))),
    ]));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Sent to bob'), findsOneWidget);
  });
}
