import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/features/games/presentation/widgets/games_panel.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';
import 'package:hello_chat/features/games/presentation/screens/lucky_draw_screen.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Game Feature Unit & Widget Tests', () {
    testWidgets('GamesPanel renders Spin Wheel and Lucky Draw options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserStreamProvider.overrideWith((ref) => Stream.value(null))],
          child: const MaterialApp(
            home: Scaffold(
              body: GamesPanel(roomId: 'test_room_123'),
            ),
          ),
        ),
      );

      expect(find.text('FEATURED GAMES'), findsOneWidget);
      expect(find.text('Spin Wheel'), findsOneWidget);
      expect(find.text('Lucky Draw'), findsOneWidget);
      expect(find.text('Win up to 10x prizes!'), findsOneWidget);
      expect(find.text('High stakes jackpot!'), findsOneWidget);
    });

    test('GameResult model creation and equality', () {
      final result = GameResult(
        multiplier: 5.0,
        prize: 500,
        label: 'multi_fruit',
      );

      expect(result.multiplier, equals(5.0));
      expect(result.prize, equals(500));
      expect(result.label, equals('multi_fruit'));
    });

    test('GameNotifier initial state is AsyncValue.data(null)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(gameActionProvider);
      expect(state.value, isNull);
    });
  });
}
