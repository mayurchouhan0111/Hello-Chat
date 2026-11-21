import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/room_support_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/floating_lucky_bag_widget.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/live_room_layout.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/rocket_progress_widget.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/seat_grid.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(393, 852),
    Size(430, 932),
    Size(740, 360)
  ]) {
    testWidgets('Framed seats and room actions stay separated at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = RoomModel.fromMap(
          {'roomId': 'room', 'ownerUid': 'owner', 'capacity': 16});
      const frame = AssetImage('assets/SVIP Kit/SVIP 6/SVIP 6 Frame.png');
      final owner = Participant(
          uid: 'owner',
          role: 'owner',
          displayName: 'Long owner display name',
          diamondsReceived: 1500000,
          profileFrame: frame.assetName,
          seatIndex: 0,
          joinedAt: DateTime(2026),
          lastActive: DateTime(2026),
          isMuted: true);
      final guest = Participant(
          uid: 'guest',
          role: 'admin',
          displayName: 'Long guest display name',
          diamondsReceived: 12345,
          profileFrame: frame.assetName,
          seatIndex: 15,
          comboCount: 520,
          joinedAt: DateTime(2026),
          lastActive: DateTime(2026),
          isMuted: true);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            roomParticipantsProvider(room.roomId)
                .overrideWith((ref) => Stream.value([owner, guest])),
            userProfileProvider('guest')
                .overrideWith((ref) => Stream.value(null)),
            roomSupportConfigProvider.overrideWith((ref) => Stream.value(null)),
            roomSupportCycleProvider(room.roomId)
                .overrideWith((ref) => Stream.value(null)),
            activeRoomLuckyBagProvider(room.roomId)
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
              home: MediaQuery(
            data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                textScaler: const TextScaler.linear(2),
                disableAnimations: true),
            child: Scaffold(
                body: LiveRoomLayout(
              room: room,
              header: const SizedBox(height: 76, child: Icon(Icons.star)),
              chat: const Text('Chat'),
              actionBar:
                  const SizedBox(height: 54, child: Text('Room actions')),
              seats: Column(children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 144),
                    child: RoomSeatPortrait(
                        participant: owner,
                        profile: null,
                        isOwner: true,
                        extent: 88,
                        fontSize: 12)),
                SeatGrid(
                    roomId: room.roomId,
                    ownerUid: owner.uid,
                    capacity: room.capacity,
                    onSeatTap: (_) {},
                    onSeatLongPress: (_) {},
                    onUserLongPress: (_) {}),
              ]),
            )),
          ))));
      await tester.pump();
      final ownerFrame = tester.getRect(find.image(frame).first);
      expect(ownerFrame.top,
          greaterThan(tester.getRect(find.byIcon(Icons.star)).bottom));
      expect(ownerFrame.bottom,
          lessThan(tester.getRect(find.text(owner.displayName)).top));
      expect(
          ownerFrame.bottom,
          lessThan(
              tester.getRect(find.byIcon(Icons.mic_off_rounded).first).top));
      // Verify owner ID row is completely removed (never displays "ID:", numeric ID, or "ID unavailable")
      expect(find.textContaining('ID:'), findsNothing);
      expect(find.text('ID unavailable'), findsNothing);
      final stage = find.byType(SingleChildScrollView);
      final rocket = tester.getRect(find.byType(RocketProgressWidget));
      final support = tester.getRect(find.byTooltip('Room Support'));
      expect(tester.getRect(stage).bottom, lessThan(rocket.top));
      expect(rocket.bottom, lessThan(support.top));
      expect(rocket.center.dx, support.center.dx);
      expect(support.bottom,
          lessThan(tester.getRect(find.text('Room actions')).top));

      await tester.drag(stage, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text(guest.displayName).hitTestable(), findsOneWidget);
      expect(tester.getRect(find.image(frame).last).bottom,
          lessThan(tester.getRect(find.text(guest.displayName)).top));
      expect(tester.getRect(find.text('12.3k')).bottom, lessThan(rocket.top));
      expect(tester.getRect(find.byType(RocketProgressWidget)), rocket);
      expect(tester.takeException(), isNull);
    });
  }
}
