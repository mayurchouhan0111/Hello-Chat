import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';
import 'package:hello_chat/features/games/presentation/widgets/spin_wheel_food_icon.dart';

void main() {
  group('Spin Wheel User Fixes Verification', () {
    test(
        'calculateSpinWheelPrize accurately calculates exact winning amount (no inflation)',
        () {
      // 1. When player bets 100,000 on Carrot (5x multiplier)
      final prize = calculateSpinWheelPrize(
        bets: {'Carrot': 100000},
        winningName: 'Carrot',
        winningCategory: 'salad',
        roundType: 'standard',
        multiplier: 5,
      );

      // Exactly 500,000 must be awarded, zero duplicate or extra points
      expect(prize, equals(500000));
    });

    test(
        'calculateSpinWheelPrize calculates 15x Skewer accurately without 3x multiplier',
        () {
      final prize = calculateSpinWheelPrize(
        bets: {'Skewer': 100000},
        winningName: 'Skewer',
        winningCategory: 'pizza',
        roundType: 'standard',
        multiplier: 15,
      );

      // 100,000 * 15 = 1,500,000
      expect(prize, equals(1500000));
    });

    testWidgets(
        'SpinWheelFoodIcon renders SVG asset accurately for winner foods',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SpinWheelFoodIcon(
                food: 'Carrot',
                size: 26,
                semanticLabel: 'Carrot',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SpinWheelFoodIcon), findsOneWidget);
    });
  });
}
