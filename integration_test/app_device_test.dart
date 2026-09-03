import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/features/leaderboards/presentation/screens/room_gift_leaderboard_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:hello_chat/firebase_options.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  group('📱 On-Device Automated UI Integration Test', () {
    testWidgets('Renders RoomGiftLeaderboardScreen and verifies DAILY, WEEKLY, MONTHLY tabs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RoomGiftLeaderboardScreen(
              roomId: 'test_room_123',
              roomName: 'Top Sender Ranking',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Widget is rendered on mobile screen
      expect(find.byType(RoomGiftLeaderboardScreen), findsOneWidget);

      // Verify Top Sender Ranking Tabs (DAILY, WEEKLY, MONTHLY)
      expect(find.text('DAILY'), findsOneWidget);
      expect(find.text('WEEKLY'), findsOneWidget);
      expect(find.text('MONTHLY'), findsOneWidget);

      // Automatically tap WEEKLY tab
      await tester.tap(find.text('WEEKLY'));
      await tester.pumpAndSettle();

      // Automatically tap MONTHLY tab
      await tester.tap(find.text('MONTHLY'));
      await tester.pumpAndSettle();

      print('🎉 SUCCESS: Automated On-Device UI Integration Test Passed on connected phone!');
    });
  });
}
