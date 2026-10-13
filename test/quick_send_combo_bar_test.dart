import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/quick_send_combo_bar.dart';

/// The combo bar dispatches one gift per tap and reserves each gift's cost
/// immediately, because the Firestore balance arrives long after a tap burst.
/// Without that reservation a burst is approved against one stale balance and
/// the server rejects the tail. These assertions fail if that math regresses.
void main() {
  group('canAffordQuickSend', () {
    test('allows a tap when the balance covers the gift', () {
      expect(canAffordQuickSend(balance: 500, reserved: 0, price: 100), isTrue);
    });

    test('allows the exact last affordable tap', () {
      expect(canAffordQuickSend(balance: 100, reserved: 0, price: 100), isTrue);
    });

    test('blocks one diamond short', () {
      expect(canAffordQuickSend(balance: 99, reserved: 0, price: 100), isFalse);
    });

    test('blocks a zero balance', () {
      expect(canAffordQuickSend(balance: 0, reserved: 0, price: 100), isFalse);
    });

    test('a free gift is always affordable', () {
      expect(canAffordQuickSend(balance: 0, reserved: 0, price: 0), isTrue);
    });

    test('in-flight reservations shrink what the next tap may spend', () {
      // 3 taps of a 100-diamond gift are queued; the balance still reads 300
      // because Firestore has not caught up. Only 3 more taps may be accepted.
      expect(canAffordQuickSend(balance: 300, reserved: 0, price: 100), isTrue);
      expect(canAffordQuickSend(balance: 300, reserved: 100, price: 100), isTrue);
      expect(canAffordQuickSend(balance: 300, reserved: 200, price: 100), isTrue);
      expect(canAffordQuickSend(balance: 300, reserved: 300, price: 100), isFalse);
    });

    test('a burst can never reserve more than the balance', () {
      var balance = 250;
      var reserved = 0;
      var accepted = 0;
      // Simulate 10 rapid taps against a balance that never refreshes.
      for (var i = 0; i < 10; i++) {
        if (canAffordQuickSend(balance: balance, reserved: reserved, price: 100)) {
          reserved += 100;
          accepted++;
        }
      }
      expect(accepted, 2);
      expect(reserved, lessThanOrEqualTo(balance));
    });
  });

  test('combo window matches extended combo banner timeout', () {
    expect(kQuickSendComboWindow.inMilliseconds, 5500);
  });
}
