import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Yummy Bingo Paytable & Payline Calculations', () {
    final Map<String, Map<int, int>> yummySymbols = {
      'wild':   { 3: 50, 4: 200, 5: 1000 },
      'dice':   { 3: 40, 4: 150, 5: 600 },
      'burger': { 3: 20, 4: 80,  5: 300 },
      'fries':  { 3: 15, 4: 60,  5: 250 },
      'cake':   { 3: 12, 4: 50,  5: 200 },
      'banana': { 3: 10, 4: 40,  5: 150 },
      'lemon':  { 3: 8,  4: 30,  5: 100 },
      'cherry': { 3: 5,  4: 20,  5: 80 },
      'clover': { 3: 5,  4: 15,  5: 50 },
    };

    final List<List<int>> paylines = [
      [1, 1, 1, 1, 1], // Center row
      [0, 0, 0, 0, 0], // Top row
      [2, 2, 2, 2, 2], // Bottom row
      [0, 1, 2, 1, 0], // V-shape
      [2, 1, 0, 1, 2], // Inverted-V
      [0, 0, 1, 2, 2], // Zig-zag top
      [2, 2, 1, 0, 0], // Zig-zag bot
      [1, 0, 0, 0, 1], // High crest
      [1, 2, 2, 2, 1], // Low valley
    ];

    test('Paylines count is exactly 9 with 5 reel indices each', () {
      expect(paylines.length, equals(9));
      for (final line in paylines) {
        expect(line.length, equals(5));
        expect(line.every((row) => row >= 0 && row <= 2), isTrue);
      }
    });

    test('Wild substitutes and evaluates 5 of a kind correctly', () {
      final matrix = [
        ['wild', 'wild', 'wild'],
        ['wild', 'wild', 'wild'],
        ['wild', 'wild', 'wild'],
        ['wild', 'wild', 'wild'],
        ['wild', 'wild', 'wild'],
      ];

      // Center row line 1: all wilds
      final centerRow = [matrix[0][1], matrix[1][1], matrix[2][1], matrix[3][1], matrix[4][1]];
      expect(centerRow, equals(['wild', 'wild', 'wild', 'wild', 'wild']));

      final payoutMultiplier = yummySymbols['wild']![5];
      expect(payoutMultiplier, equals(1000));

      const betPerLine = 2000;
      final win = payoutMultiplier! * betPerLine;
      expect(win, equals(2000000));
    });

    test('Evaluates 3 of a kind with Wild match', () {
      // 2 burgers + 1 wild + cherry + clover
      final lineSymbols = ['burger', 'burger', 'wild', 'cherry', 'clover'];
      String first = lineSymbols[0];
      int matchCount = 1;

      for (int i = 1; i < lineSymbols.length; i++) {
        final cur = lineSymbols[i];
        if (cur == first || cur == 'wild' || (first == 'wild' && cur != 'wild')) {
          if (first == 'wild' && cur != 'wild') first = cur;
          matchCount++;
        } else {
          break;
        }
      }

      expect(matchCount, equals(3));
      expect(first, equals('burger'));
      expect(yummySymbols[first]![matchCount], equals(20));
    });
  });
}
