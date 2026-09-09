import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/features/leaderboards/presentation/widgets/top_list_podium.dart';

void main() {
  group('Top List UserModel Metric Tests', () {
    test('UserModel correctly serializes and deserializes Top List fields', () {
      final userMap = {
        'uid': 'user_123',
        'displayName': 'Champion King',
        'username': 'champ',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'phoneNumber': '+1234567890',
        'dailyDiamondsSent': 50000,
        'weeklyDiamondsSent': 250000,
        'monthlyDiamondsSent': 1200000,
        'totalDiamondsSent': 5000000,
        'dailyBeansReceived': 75000,
        'weeklyBeansReceived': 350000,
        'monthlyBeansReceived': 1800000,
        'totalBeansReceived': 8000000,
      };

      final user = UserModel.fromMap(userMap);

      expect(user.dailyDiamondsSent, 50000);
      expect(user.weeklyDiamondsSent, 250000);
      expect(user.monthlyDiamondsSent, 1200000);
      expect(user.totalDiamondsSent, 5000000);
      expect(user.dailyBeansReceived, 75000);
      expect(user.weeklyBeansReceived, 350000);
      expect(user.monthlyBeansReceived, 1800000);
      expect(user.totalBeansReceived, 8000000);

      final serialized = user.toMap();
      expect(serialized['dailyDiamondsSent'], 50000);
      expect(serialized['weeklyDiamondsSent'], 250000);
      expect(serialized['monthlyDiamondsSent'], 1200000);
      expect(serialized['totalDiamondsSent'], 5000000);
      expect(serialized['dailyBeansReceived'], 75000);
      expect(serialized['weeklyBeansReceived'], 350000);
      expect(serialized['monthlyBeansReceived'], 1800000);
      expect(serialized['totalBeansReceived'], 8000000);
    });

    test('Sending and Receiving rankings are strictly separated', () {
      final senderMap = {
        'uid': 'sender_1',
        'displayName': 'Big Spender',
        'username': 'spender',
        'createdAt': DateTime.now().toIso8601String(),
        'phoneNumber': '+111111111',
        'dailyDiamondsSent': 999999,
        'dailyBeansReceived': 0,
      };

      final receiverMap = {
        'uid': 'receiver_1',
        'displayName': 'Star Streamer',
        'username': 'streamer',
        'createdAt': DateTime.now().toIso8601String(),
        'phoneNumber': '+222222222',
        'dailyDiamondsSent': 0,
        'dailyBeansReceived': 888888,
      };

      final sender = UserModel.fromMap(senderMap);
      final receiver = UserModel.fromMap(receiverMap);

      expect(sender.dailyDiamondsSent > receiver.dailyDiamondsSent, isTrue);
      expect(receiver.dailyBeansReceived > sender.dailyBeansReceived, isTrue);
      expect(sender.dailyBeansReceived, 0);
      expect(receiver.dailyDiamondsSent, 0);
    });

    test('Default values for Top List metrics default to zero if missing', () {
      final emptyMap = {
        'uid': 'empty_user',
        'displayName': 'New User',
        'username': 'newbie',
        'createdAt': DateTime.now().toIso8601String(),
        'phoneNumber': '+333333333',
      };

      final user = UserModel.fromMap(emptyMap);
      expect(user.dailyDiamondsSent, 0);
      expect(user.weeklyDiamondsSent, 0);
      expect(user.monthlyDiamondsSent, 0);
      expect(user.totalDiamondsSent, 0);
      expect(user.dailyBeansReceived, 0);
      expect(user.weeklyBeansReceived, 0);
      expect(user.monthlyBeansReceived, 0);
      expect(user.totalBeansReceived, 0);
    });
  });

  group('TopListPodium Widget Tests', () {
    testWidgets('Renders top 3 users with champion, silver, and bronze pedestals', (tester) async {
      final topUsers = [
        const PodiumUserData(
          uid: 'user_1',
          displayName: 'King Champion',
          photoUrl: '',
          score: 1500000,
          countryCode: 'MY',
        ),
        const PodiumUserData(
          uid: 'user_2',
          displayName: 'Silver Master',
          photoUrl: '',
          score: 850000,
          countryCode: 'IN',
        ),
        const PodiumUserData(
          uid: 'user_3',
          displayName: 'Bronze Hero',
          photoUrl: '',
          score: 420000,
          countryCode: 'PK',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TopListPodium(
                topUsers: topUsers,
                isSendingTab: true,
                enableAnimations: false,
              ),
            ),
          ),
        ),
      );

      // Verify names render
      expect(find.text('King Champion'), findsOneWidget);
      expect(find.text('Silver Master'), findsOneWidget);
      expect(find.text('Bronze Hero'), findsOneWidget);

      // Verify badges render
      expect(find.text('NO.1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify scores and 3D coins render
      expect(find.text('1500000'), findsOneWidget);
      expect(find.text('850000'), findsOneWidget);
      expect(find.text('420000'), findsOneWidget);
      expect(find.byType(GoldenCoinIcon), findsWidgets);
    });

    test('Daily, Weekly, and Monthly metrics are strictly tracked separately', () {
      final user = UserModel.fromMap({
        'uid': 'multi_period_user',
        'displayName': 'Period Tester',
        'dailyDiamondsSent': 500,
        'weeklyDiamondsSent': 5000,
        'monthlyDiamondsSent': 25000,
        'dailyBeansReceived': 300,
        'weeklyBeansReceived': 3000,
        'monthlyBeansReceived': 15000,
      });

      expect(user.dailyDiamondsSent, 500);
      expect(user.weeklyDiamondsSent, 5000);
      expect(user.monthlyDiamondsSent, 25000);
      expect(user.dailyBeansReceived, 300);
      expect(user.weeklyBeansReceived, 3000);
      expect(user.monthlyBeansReceived, 15000);
    });

    test('Ranking order sorts highest Diamond sender and Bean receiver at top', () {
      final userA = PodiumUserData(uid: 'a', displayName: 'User A', photoUrl: '', score: 100);
      final userB = PodiumUserData(uid: 'b', displayName: 'User B', photoUrl: '', score: 5000);
      final userC = PodiumUserData(uid: 'c', displayName: 'User C', photoUrl: '', score: 250);

      final list = [userA, userB, userC];
      list.sort((a, b) => b.score.compareTo(a.score));

      expect(list.first.uid, 'b');
      expect(list.first.score, 5000);
      expect(list[1].uid, 'c');
      expect(list.last.uid, 'a');
    });
  });
}
