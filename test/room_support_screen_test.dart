import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/room_support_provider.dart';
import 'package:hello_chat/features/rooms/presentation/screens/room_support_screen.dart';

void main() {
  testWidgets('RoomSupportScreen renders with full room data', (tester) async {
    final mockRoom = RoomModel(
      roomId: 'test_room_123',
      createdBy: 'owner_123',
      ownerUid: 'owner_123',
      name: 'Test Room',
      theme: 'default',
      coverUrl: '',
      isPrivate: false,
      capacity: 8,
      currentUsersCount: 5,
      backgroundMusic: false,
      createdAt: DateTime.now(),
      status: 'active',
      admins: [],
      moderators: [],
      bannedUids: [],
      weeklyEarnings: 15000,
    );

    final mockUser = UserModel(
      uid: 'owner_123',
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
      phoneNumber: '+1234567890',
      username: 'owner',
      displayName: 'Owner',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoomStreamProvider('test_room_123').overrideWith((ref) => Stream.value(mockRoom)),
          currentUserProfileProvider.overrideWith((ref) => Stream.value(mockUser)),
          roomSupportConfigProvider.overrideWith((ref) => Stream.value({
            'levels': [
              <dynamic, dynamic>{
                'level': 1,
                'coinsTarget': 10000000,
                'partnerSlots': 4,
                'ownerReward': 1000000,
                'partnerReward': 250000,
                'totalReward': 2000000,
              },
            ],
          })),
          roomSupportCycleProvider('test_room_123').overrideWith((ref) => Stream.value({
            'totalCoins': 50000,
            'level': 0,
            'lastWeekLevel': 0,
            'visitorCount': 10,
          })),
          roomSupportPartnersProvider('test_room_123').overrideWith((ref) => Stream.value([])),
          roomSupportHistoryProvider('test_room_123').overrideWith((ref) => Stream.value([])),
          roomSupportRankingsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: RoomSupportScreen(roomId: 'test_room_123'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final err = tester.takeException();
    if (err != null) {
      debugPrint('TEST THREW EXCEPTION: $err');
    }
    expect(err, isNull);
  });
}
