import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/seat_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🏷️ Task 3: Admin Seat Label Badge Tests', () {
    testWidgets('OccupiedSeatWidget displays Admin label for room admins', (WidgetTester tester) async {
      final adminParticipant = Participant(
        uid: 'admin_user_99',
        displayName: 'Room Admin User',
        seatIndex: 1,
        joinedAt: DateTime.now(),
        lastActive: DateTime.now(),
        isMuted: false,
        role: 'admin',
        isAdmin: true,
      );

      final dummyUser = UserModel(
        uid: 'admin_user_99',
        createdAt: DateTime.now(),
        phoneNumber: null,
        username: 'admin_user_99',
        displayName: 'Room Admin User',
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
        lastActive: DateTime.now(),
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
        role: 'admin',
        usdCommissionBalance: 0,
        pendingWithdrawalBalance: 0,
        totalCommissionEarned: 0,
        totalRechargeGenerated: 0,
        totalWithdrawnUSD: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedUserProfileProvider('admin_user_99').overrideWith((ref) => Stream.value(dummyUser)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OccupiedSeatWidget(
                participant: adminParticipant,
                index: 1,
                radius: 24,
                iconSize: 14,
                fontSize: 10,
                currentUid: 'admin_user_99',
                onSeatTap: (_) {},
                onSeatLongPress: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Room Admin User'), findsOneWidget);
    });
  });
}
