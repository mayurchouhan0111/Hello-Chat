import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/rocket_completion_vap_overlay.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/rocket_launch_overlay.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/room_welcome_banner.dart';

void main() {
  group('Phase 7: Real-Time Room Welcome Message Banner Tests', () {
    testWidgets('RoomWelcomeBanner falls back to default platform notice when empty',
        (tester) async {
      final room = RoomModel.fromMap({
        'roomId': 'test-room-empty',
        'ownerUid': 'owner1',
        'capacity': 16,
        'welcomeMessage': '',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider('test-room-empty')
                .overrideWith((ref) => Stream.value(room)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RoomWelcomeBanner(roomId: 'test-room-empty'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(RoomWelcomeBanner), findsOneWidget);
      expect(find.text(RoomWelcomeBanner.defaultPlatformWelcomeText), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    });

    testWidgets('RoomWelcomeBanner displays real-time welcomeMessage',
        (tester) async {
      const welcomeText = '🎉 Welcome to our VIP music room!';
      final room = RoomModel.fromMap({
        'roomId': 'test-room-live',
        'ownerUid': 'owner1',
        'capacity': 16,
        'welcomeMessage': welcomeText,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider('test-room-live')
                .overrideWith((ref) => Stream.value(room)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RoomWelcomeBanner(roomId: 'test-room-live'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(welcomeText), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    });

    test('RoomModel parses and serializes welcome message audit metadata', () {
      final now = DateTime(2026, 11, 21, 12, 0, 0);
      final room = RoomModel(
        roomId: 'room-1',
        createdBy: 'user-1',
        ownerUid: 'user-1',
        name: 'Test Room',
        theme: 'classic_purple',
        coverUrl: '',
        isPrivate: false,
        capacity: 16,
        currentUsersCount: 1,
        backgroundMusic: false,
        createdAt: now,
        status: 'active',
        admins: [],
        moderators: [],
        bannedUids: [],
        welcomeMessage: 'Welcome everyone to the official room!',
        welcomeMessageUpdatedAt: now,
        welcomeMessageUpdatedBy: 'admin-uid-1',
      );

      final map = room.toMap();
      expect(map['welcomeMessage'], 'Welcome everyone to the official room!');
      expect(map['welcomeMessageUpdatedBy'], 'admin-uid-1');
      expect(map['welcomeMessageUpdatedAt'], isNotNull);

      final recreated = RoomModel.fromMap(map);
      expect(
          recreated.welcomeMessage, 'Welcome everyone to the official room!');
      expect(recreated.welcomeMessageUpdatedBy, 'admin-uid-1');
      expect(recreated.welcomeMessageUpdatedAt, now);
    });
  });

  group('Phase 4: Rocket Launch Text Removal & Deterministic Lifecycle Tests',
      () {
    testWidgets(
        'RocketLaunchOverlay does not display unwanted post-launch text',
        (tester) async {
      final room = RoomModel.fromMap({
        'roomId': 'room-rocket',
        'ownerUid': 'owner1',
        'capacity': 16,
        'rocketLevel': 1,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider('room-rocket')
                .overrideWith((ref) => Stream.value(room)),
            currentUserProfileProvider
                .overrideWith((ref) => Stream.value(null)),
            userProfileProvider('owner1')
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RocketLaunchOverlay(
                level: 1,
                roomId: 'room-rocket',
                ticketId: 'ticket-1',
                onComplete: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Unwanted post-launch texts MUST NOT be present
      expect(find.text('LAUNCHED!'), findsNothing);
      expect(find.textContaining('ROCKET LAUNCHED'), findsNothing);
      expect(find.textContaining('ROCKET LANDED'), findsNothing);
      expect(find.textContaining('Preparing Reward Settlement'), findsNothing);
      expect(find.textContaining('EXPLODING IN'), findsNothing);
    });

    testWidgets(
        'RocketCompletionVapOverlay does not display unwanted post-launch text',
        (tester) async {
      final room = RoomModel.fromMap({
        'roomId': 'room-rocket',
        'ownerUid': 'owner1',
        'capacity': 16,
        'rocketLevel': 2,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider('room-rocket')
                .overrideWith((ref) => Stream.value(room)),
            currentUserProfileProvider
                .overrideWith((ref) => Stream.value(null)),
            userProfileProvider('owner1')
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RocketCompletionVapOverlay(
                level: 2,
                roomId: 'room-rocket',
                ticketId: 'ticket-2',
                onComplete: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Unwanted post-launch texts MUST NOT be present
      expect(find.textContaining('ROCKET LAUNCHED!'), findsNothing);
      expect(find.textContaining('LEVEL 3 ROCKET LAUNCHED!'), findsNothing);
      expect(find.textContaining('ROCKET LANDED'), findsNothing);
      expect(find.textContaining('Preparing Reward Settlement'), findsNothing);
      expect(find.textContaining('EXPLODING IN'), findsNothing);
    });

    test('RocketVapConfig preloads active and next level assets cleanly',
        () async {
      await expectLater(
        RocketVapConfig.preloadActiveAndNext(0),
        completes,
      );
      await expectLater(
        RocketVapConfig.preloadActiveAndNext(4),
        completes,
      );
    });
  });
}
