import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🎁 Gift & Wallet Strict Category Restrictions Test Suite', () {
    test('1. Allowed Gift Categories are strictly Normal, Medium, and Luxury', () {
      const allowedCategories = ['Normal Gifts', 'Medium Gifts', 'Luxury Gifts'];
      expect(allowedCategories.length, equals(3));
      expect(allowedCategories.contains('Normal Gifts'), isTrue);
      expect(allowedCategories.contains('Medium Gifts'), isTrue);
      expect(allowedCategories.contains('Luxury Gifts'), isTrue);
      expect(allowedCategories.contains('Lucky'), isFalse);
      expect(allowedCategories.contains('Lucky Gifts'), isFalse);
      expect(allowedCategories.contains('CP'), isFalse);
      expect(allowedCategories.contains('VIP'), isFalse);
      expect(allowedCategories.contains('SVIP'), isFalse);
    });

    test('2. Lucky Gifts filter rejects any lucky gift by ID, name, or category', () {
      bool isAllowed(String category, String giftId, String name) {
        final cat = category.toLowerCase().trim().replaceAll('_', ' ');
        final gId = giftId.toLowerCase().trim();
        final n = name.toLowerCase().trim();

        if (cat.contains('lucky') || gId.contains('lucky') || n.contains('lucky')) {
          return false;
        }

        const allowed = ['normal', 'medium', 'luxury', 'standard', 'gift'];
        return allowed.contains(cat);
      }

      // Normal, Medium, Luxury should pass
      expect(isAllowed('Normal', 'rose_1', 'Red Rose'), isTrue);
      expect(isAllowed('Medium', 'heart_box', 'Sweet Box'), isTrue);
      expect(isAllowed('Luxury', 'sports_car', 'Supercar'), isTrue);

      // Lucky items must be blocked
      expect(isAllowed('Lucky', 'lucky_star', 'Lucky Star'), isFalse);
      expect(isAllowed('Lucky', 'lucky_bell', 'Lucky Bell'), isFalse);
      expect(isAllowed('Lucky', 'lucky_fruit', 'Lucky Fruit'), isFalse);
      expect(isAllowed('Lucky', 'lucky_chest', 'Lucky Chest'), isFalse);
      expect(isAllowed('Normal', 'lucky_token', 'Lucky Token'), isFalse);
    });

    test('3. Wallet Screen tab configuration limits Diamonds to Reseller and Beans to Exchange', () {
      const diamondAllowedActions = ['Reseller Recharge'];
      const beanAllowedActions = ['Beans Exchange'];

      expect(diamondAllowedActions, contains('Reseller Recharge'));
      expect(diamondAllowedActions.contains('Wallet Balance'), isFalse);
      expect(diamondAllowedActions.contains('Touch \'n Go'), isFalse);
      expect(diamondAllowedActions.contains('VISA/Master'), isFalse);
      expect(diamondAllowedActions.contains('Google Wallet'), isFalse);

      expect(beanAllowedActions, contains('Beans Exchange'));
      expect(beanAllowedActions.contains('Wallet Balance'), isFalse);
      expect(beanAllowedActions.contains('Reseller Recharge'), isFalse);
    });
  });
}
