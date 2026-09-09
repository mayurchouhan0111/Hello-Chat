import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Teen Patti Game Logic & Hand Ranking Engine', () {
    const rankOrder = {
      '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7,
      '8': 8, '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14
    };

    int evaluateHand(List<String> ranks, List<String> suits) {
      final v = ranks.map((r) => rankOrder[r]!).toList()..sort((a, b) => b.compareTo(a));
      final isFlush = suits[0] == suits[1] && suits[1] == suits[2];
      final isA23 = v[0] == 14 && v[1] == 3 && v[2] == 2;
      final isStraight = (v[0] - v[1] == 1 && v[1] - v[2] == 1) || isA23;
      final isThreeOfAKind = v[0] == v[1] && v[1] == v[2];
      final isPair = v[0] == v[1] || v[1] == v[2] || v[0] == v[2];

      if (isThreeOfAKind) return 6000000 + v[0];
      if (isFlush && isStraight) return 5000000 + (isA23 ? 3 : v[0]);
      if (isStraight) return 4000000 + (isA23 ? 3 : v[0]);
      if (isFlush) return 3000000 + v[0] * 400 + v[1] * 20 + v[2];
      if (isPair) {
        final pairVal = (v[0] == v[1] || v[0] == v[2]) ? v[0] : v[1];
        final kicker = (v[0] == v[1]) ? v[2] : (v[1] == v[2] ? v[0] : v[1]);
        return 2000000 + pairVal * 100 + kicker;
      }
      return 1000000 + v[0] * 400 + v[1] * 20 + v[2];
    }

    test('Rankings: Trail > Pure Sequence > Sequence > Color > Pair > High Card', () {
      final trail = evaluateHand(['A', 'A', 'A'], ['hearts', 'spades', 'diamonds']);
      final pureSeq = evaluateHand(['A', 'K', 'Q'], ['hearts', 'hearts', 'hearts']);
      final seq = evaluateHand(['A', 'K', 'Q'], ['hearts', 'spades', 'clubs']);
      final color = evaluateHand(['A', '10', '8'], ['spades', 'spades', 'spades']);
      final pair = evaluateHand(['K', 'K', '5'], ['diamonds', 'clubs', 'spades']);
      final highCard = evaluateHand(['A', 'Q', '9'], ['hearts', 'clubs', 'spades']);

      expect(trail > pureSeq, isTrue, reason: 'Trail beats Pure Sequence');
      expect(pureSeq > seq, isTrue, reason: 'Pure Sequence beats Regular Sequence');
      expect(seq > color, isTrue, reason: 'Regular Sequence beats Color');
      expect(color > pair, isTrue, reason: 'Color beats Pair');
      expect(pair > highCard, isTrue, reason: 'Pair beats High Card');
    });

    test('Trail hierarchy: AAA beats KKK beats 222', () {
      final aaa = evaluateHand(['A', 'A', 'A'], ['hearts', 'spades', 'diamonds']);
      final kkk = evaluateHand(['K', 'K', 'K'], ['hearts', 'spades', 'diamonds']);
      final two = evaluateHand(['2', '2', '2'], ['hearts', 'spades', 'diamonds']);

      expect(aaa > kkk, isTrue);
      expect(kkk > two, isTrue);
    });

    test('Pair kicker resolution: KKQ beats KKJ', () {
      final kkq = evaluateHand(['K', 'K', 'Q'], ['hearts', 'diamonds', 'clubs']);
      final kkj = evaluateHand(['K', 'K', 'J'], ['hearts', 'diamonds', 'spades']);

      expect(kkq > kkj, isTrue);
    });

    test('High card kicker resolution: AK9 beats AK8', () {
      final ak9 = evaluateHand(['A', 'K', '9'], ['hearts', 'diamonds', 'clubs']);
      final ak8 = evaluateHand(['A', 'K', '8'], ['hearts', 'spades', 'clubs']);

      expect(ak9 > ak8, isTrue);
    });

    test('A-2-3 special straight ranking', () {
      final a23 = evaluateHand(['A', '2', '3'], ['hearts', 'diamonds', 'clubs']);
      final akq = evaluateHand(['A', 'K', 'Q'], ['hearts', 'diamonds', 'clubs']);
      final qj10 = evaluateHand(['Q', 'J', '10'], ['hearts', 'diamonds', 'clubs']);

      expect(akq > qj10, isTrue);
      expect(qj10 > a23, isTrue, reason: 'A-2-3 is lower than Q-J-10 sequence');
    });

    test('Blind vs Seen betting logic calculation', () {
      const currentBet = 1000;
      int calculateStake(bool isSeen, bool isRaise) {
        final betAmount = isRaise ? currentBet * 2 : currentBet;
        return isSeen ? betAmount : (betAmount ~/ 2);
      }

      expect(calculateStake(false, false), equals(500), reason: 'Blind Chaal is half stake');
      expect(calculateStake(true, false), equals(1000), reason: 'Seen Chaal is full stake');
      expect(calculateStake(false, true), equals(1000), reason: 'Blind Raise is 2x blind');
      expect(calculateStake(true, true), equals(2000), reason: 'Seen Raise is 2x seen');
    });

    test('Turn cycle correctly skips folded and empty seats', () {
      final seats = [
        {'uid': 'u1', 'folded': false}, // Seat 0
        null,                           // Seat 1 empty
        {'uid': 'u2', 'folded': true},  // Seat 2 folded
        {'uid': 'u3', 'folded': false}, // Seat 3 active
        null,                           // Seat 4 empty
        {'uid': 'u4', 'folded': false}, // Seat 5 active
      ];

      int getNextTurn(int currentSeat) {
        for (int i = 1; i <= 6; i++) {
          final check = (currentSeat + i) % 6;
          final player = seats[check];
          if (player != null && player['folded'] == false) {
            return check;
          }
        }
        return currentSeat;
      }

      expect(getNextTurn(0), equals(3), reason: 'Seat 0 advances to 3 (skips empty 1 and folded 2)');
      expect(getNextTurn(3), equals(5), reason: 'Seat 3 advances to 5 (skips empty 4)');
      expect(getNextTurn(5), equals(0), reason: 'Seat 5 wraps around to 0');
    });
  });
}
