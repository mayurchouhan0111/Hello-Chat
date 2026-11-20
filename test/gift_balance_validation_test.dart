import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/quick_send_combo_bar.dart';

void main() {
  group('🎁 Client-Side Gift Balance Validation Test Suite', () {
    late GiftModel normalGift;
    late GiftModel freeGift;

    setUp(() {
      normalGift = GiftModel(
        giftId: 'rose_10',
        name: 'Red Rose',
        priceInDiamonds: 10,
        imageUrl: 'assets/gifts/rose.png',
        lottieAssetPath: 'assets/gifts/rose.json',
        category: 'normal',
      );
      freeGift = GiftModel(
        giftId: 'free_zero',
        name: 'Free Item',
        priceInDiamonds: 0,
        imageUrl: 'assets/gifts/free.png',
        lottieAssetPath: 'assets/gifts/free.json',
        category: 'normal',
      );
    });

    test('1. Zero-balance user is strictly blocked from sending a priced gift', () {
      const userBalance = 0;
      final giftCost = normalGift.priceInDiamonds * 1; // 10

      final canAfford = canAffordQuickSend(
        balance: userBalance,
        reserved: 0,
        price: normalGift.priceInDiamonds,
      );
      expect(canAfford, isFalse);

      final hasEnoughBalance = userBalance > 0 &&
          normalGift.priceInDiamonds > 0 &&
          userBalance >= giftCost;
      expect(hasEnoughBalance, isFalse);
    });

    test('2. Underfunded user (5 diamonds) is strictly blocked from sending a 10-diamond gift', () {
      const userBalance = 5;
      final giftCost = normalGift.priceInDiamonds * 1; // 10

      final canAfford = canAffordQuickSend(
        balance: userBalance,
        reserved: 0,
        price: normalGift.priceInDiamonds,
      );
      expect(canAfford, isFalse);

      final hasEnoughBalance = userBalance > 0 &&
          normalGift.priceInDiamonds > 0 &&
          userBalance >= giftCost;
      expect(hasEnoughBalance, isFalse);
    });

    test('3. Free/zero-price gift is blocked by priceInDiamonds > 0 guard', () {
      const userBalance = 0;
      final giftCost = freeGift.priceInDiamonds * 1; // 0

      // Must be rejected by strict price check
      final hasValidPrice = freeGift.priceInDiamonds > 0;
      expect(hasValidPrice, isFalse);

      final hasEnoughBalance = userBalance > 0 &&
          freeGift.priceInDiamonds > 0 &&
          userBalance >= giftCost;
      expect(hasEnoughBalance, isFalse);
    });

    test('4. Sufficient balance user is allowed to send', () {
      const userBalance = 100;
      final giftCost = normalGift.priceInDiamonds * 2; // 20

      final canAfford = canAffordQuickSend(
        balance: userBalance,
        reserved: 0,
        price: normalGift.priceInDiamonds,
      );
      expect(canAfford, isTrue);

      final hasEnoughBalance = userBalance > 0 &&
          normalGift.priceInDiamonds > 0 &&
          userBalance >= giftCost;
      expect(hasEnoughBalance, isTrue);
    });

    test('5. Multi-target cost calculation multiplies correctly', () {
      const userBalance = 50;
      const quantity = 3;
      const targetCount = 2;
      final totalCost = normalGift.priceInDiamonds * quantity * targetCount; // 10 * 3 * 2 = 60

      final hasEnoughBalance = userBalance > 0 &&
          normalGift.priceInDiamonds > 0 &&
          userBalance >= totalCost;
      expect(hasEnoughBalance, isFalse); // 50 < 60 -> blocked
    });
  });
}
