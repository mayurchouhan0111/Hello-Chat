import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/room_user_options_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🛡️ Room Admin Role & Badge Access Control Tests', () {
    final now = DateTime.now();

    UserModel createDummyUser(String uid, String name) {
      return UserModel(
        uid: uid,
        createdAt: now,
        phoneNumber: null,
        username: name,
        displayName: name,
        bio: '',
        country: 'MY',
        profilePhotoUrl: '',
        gender: 'male',
        diamondBalance: 0,
        diamondStock: 0,
        beansBalance: 0,
        xp: 0,
        dailyXP: 0,
        weeklyXP: 0,
        monthlyXP: 0,
        benchXP: 0,
        princeXP: 0,
        dailyPrinceXP: 0,
        weeklyPrinceXP: 0,
        monthlyPrinceXP: 0,
        level: 1,
        followerCount: 0,
        followingCount: 0,
        friendsCount: 0,
        status: 'online',
        badges: [],
        profileFrame: '',
        chatBubble: '',
        entryAnimation: '',
        badgeIcon: '',
        tags: [],
        vipTier: 'none',
        isBanned: false,
        lastActive: now,
        lastVipClaim: '',
        isAgencyOwner: false,
        isFamilyOwner: false,
        combatPoints: 0,
        blockedUids: [],
        referralCode: 'REF',
        totalReferralEarnings: 0,
        cpLevel: 0,
        cpPoints: 0,
        visitorCount: 0,
        recentVisitors: [],
        languages: [],
        isReseller: false,
        isVerified: false,
        verificationStatus: 'unverified',
        walletBalance: 0,
        role: 'user',
        usdCommissionBalance: 0,
        pendingWithdrawalBalance: 0,
        totalCommissionEarned: 0,
        totalRechargeGenerated: 0,
        totalWithdrawnUSD: 0,
      );
    }

    test('RoomModel parses admins and admin_ids and correctly checks roles', () {
      final room = RoomModel.fromMap({
        'roomId': 'room_101',
        'createdBy': 'owner_1',
        'ownerUid': 'owner_1',
        'name': 'Test Room',
        'capacity': 10,
        'currentUsersCount': 3,
        'backgroundMusic': false,
        'isPrivate': false,
        'status': 'active',
        'admin_ids': ['admin_user_1', 'admin_user_2'],
        'moderators': [],
        'bannedUids': [],
      });

      expect(room.adminIds, contains('admin_user_1'));
      expect(room.adminIds, contains('admin_user_2'));
      expect(room.isUserAdmin('admin_user_1'), isTrue);
      expect(room.isUserAdmin('owner_1'), isFalse, reason: 'Owner must not be considered an admin');
      expect(room.isUserAdmin('normal_user'), isFalse);
      expect(room.isUserOwner('owner_1'), isTrue);
    });

    testWidgets('Normal participant does NOT display Admin badge even when viewer is admin', (WidgetTester tester) async {
      const roomId = 'room_test_1';
      final normalParticipant = Participant(
        uid: 'normal_audience_1',
        displayName: 'Normal Audience',
        seatIndex: -1,
        joinedAt: now,
        lastActive: now,
        isMuted: false,
        role: 'audience',
        isAdmin: false,
      );

      final testRoom = RoomModel(
        roomId: roomId,
        createdBy: 'host_owner',
        ownerUid: 'host_owner',
        name: 'Live Room',
        theme: 'classic',
        coverUrl: '',
        isPrivate: false,
        capacity: 10,
        currentUsersCount: 2,
        backgroundMusic: false,
        createdAt: now,
        status: 'active',
        admins: ['designated_admin_1'],
        moderators: [],
        bannedUids: [],
      );

      final dummyUser = createDummyUser('normal_audience_1', 'Normal Audience');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider(roomId).overrideWith((ref) => Stream.value(testRoom)),
            userProfileProvider('normal_audience_1').overrideWith((ref) => Stream.value(dummyUser)),
            followingStreamProvider('').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomUserOptionsSheet(
                participant: normalParticipant,
                roomId: roomId,
                isHost: false,
                isAdmin: true, // Viewer is an admin!
                isModerator: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Normal audience MUST NOT have the Admin badge or Owner badge
      expect(find.text("Normal Audience"), findsOneWidget);
      expect(find.text("Admin"), findsNothing, reason: 'Normal user should NEVER display Admin badge');
      expect(find.text("Owner"), findsNothing, reason: 'Normal user is not room owner');
    });

    testWidgets('Explicit room admin displays cyan Admin badge', (WidgetTester tester) async {
      const roomId = 'room_test_2';
      final adminParticipant = Participant(
        uid: 'designated_admin_1',
        displayName: 'Designated Admin',
        seatIndex: 2,
        joinedAt: now,
        lastActive: now,
        isMuted: false,
        role: 'admin',
        isAdmin: true,
      );

      final testRoom = RoomModel(
        roomId: roomId,
        createdBy: 'host_owner',
        ownerUid: 'host_owner',
        name: 'Live Room',
        theme: 'classic',
        coverUrl: '',
        isPrivate: false,
        capacity: 10,
        currentUsersCount: 2,
        backgroundMusic: false,
        createdAt: now,
        status: 'active',
        admins: ['designated_admin_1'],
        moderators: [],
        bannedUids: [],
      );

      final dummyAdmin = createDummyUser('designated_admin_1', 'Designated Admin');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider(roomId).overrideWith((ref) => Stream.value(testRoom)),
            userProfileProvider('designated_admin_1').overrideWith((ref) => Stream.value(dummyAdmin)),
            followingStreamProvider('').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomUserOptionsSheet(
                participant: adminParticipant,
                roomId: roomId,
                isHost: false,
                isAdmin: false, // Viewer is a normal member
                isModerator: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Target user is in room.admins, so they MUST display the Admin badge
      expect(find.text("Designated Admin"), findsOneWidget);
      expect(find.text("Admin"), findsOneWidget, reason: 'Designated room admin MUST display Admin badge');
      expect(find.text("Owner"), findsNothing);
    });

    testWidgets('Room Owner displays Owner badge and never Admin badge', (WidgetTester tester) async {
      const roomId = 'room_test_3';
      final ownerParticipant = Participant(
        uid: 'host_owner',
        displayName: 'Room Host',
        seatIndex: 0,
        joinedAt: now,
        lastActive: now,
        isMuted: false,
        role: 'owner',
        isAdmin: false,
      );

      final testRoom = RoomModel(
        roomId: roomId,
        createdBy: 'host_owner',
        ownerUid: 'host_owner',
        name: 'Live Room',
        theme: 'classic',
        coverUrl: '',
        isPrivate: false,
        capacity: 10,
        currentUsersCount: 2,
        backgroundMusic: false,
        createdAt: now,
        status: 'active',
        admins: [],
        moderators: [],
        bannedUids: [],
      );

      final dummyHost = createDummyUser('host_owner', 'Room Host');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoomStreamProvider(roomId).overrideWith((ref) => Stream.value(testRoom)),
            userProfileProvider('host_owner').overrideWith((ref) => Stream.value(dummyHost)),
            followingStreamProvider('').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomUserOptionsSheet(
                participant: ownerParticipant,
                roomId: roomId,
                isHost: true,
                isAdmin: true,
                isModerator: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Owner MUST display Owner badge, NOT Admin
      expect(find.text("Owner"), findsOneWidget, reason: 'Room creator must display Owner badge');
      expect(find.text("Admin"), findsNothing, reason: 'Room owner must not display Admin badge');
    });
  });
}
