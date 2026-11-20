import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/features/games/presentation/widgets/game_top_winner_banner.dart';
import 'package:hello_chat/features/games/presentation/widgets/spin_wheel_food_icon.dart';

void main() {
  test('wheel foods resolve to the exact Greedy BIGO reference sprite cells',
      () {
    expect(
      SpinWheelFoodIcon.assetFor('Tomato'),
      'assets/games/icons/greedy_bigo_food_sprite.png',
    );
    expect(SpinWheelFoodIcon.spriteIndexFor('Hotdog'), 0);
    expect(SpinWheelFoodIcon.spriteIndexFor('Tomato'), 1);
    expect(SpinWheelFoodIcon.spriteIndexFor('Skewer'), 2);
    expect(SpinWheelFoodIcon.spriteIndexFor('Chicken'), 3);
    expect(SpinWheelFoodIcon.spriteIndexFor('Steak'), 4);
    expect(SpinWheelFoodIcon.spriteIndexFor('Carrot'), 5);
    expect(SpinWheelFoodIcon.spriteIndexFor('Corn'), 6);
    expect(SpinWheelFoodIcon.spriteIndexFor('Leaf'), 7);
    expect(SpinWheelFoodIcon.spriteIndexFor('Salad'), 8);
    expect(SpinWheelFoodIcon.spriteIndexFor('Pizza'), 9);
  });

  testWidgets('all ten extracted food cells render without asset errors',
      (tester) async {
    const foods = [
      'Hotdog',
      'Tomato',
      'Skewer',
      'Chicken',
      'Steak',
      'Carrot',
      'Corn',
      'Leaf',
      'Salad',
      'Pizza',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final food in foods)
              SpinWheelFoodIcon(food: food, size: 64),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpinWheelFoodIcon), findsNWidgets(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'global Top-1 event follows the four-second gift banner lifecycle',
      (tester) async {
    final events = StreamController<Map<String, dynamic>?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          luckySpinWinnerEventProvider.overrideWith((ref) => events.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GlobalWheelWinnerBanner()),
        ),
      ),
    );

    expect(find.byType(GameTopWinnerBanner), findsNothing);
    events.add({
      'eventId': 'spin_test_round',
      'roundId': 'test_round',
      'amount': 125000,
      'avatar': '',
      'announcedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pump();
    expect(find.byType(GameTopWinnerBanner), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3999));
    expect(find.byType(GameTopWinnerBanner), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    // The gift banner's 420ms slide/fade exit keeps the outgoing child alive.
    expect(find.byType(GameTopWinnerBanner), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 421));
    expect(find.byType(GameTopWinnerBanner), findsNothing);

    await events.close();
  });
}
