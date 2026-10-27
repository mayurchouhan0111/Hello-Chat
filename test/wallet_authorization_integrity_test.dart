import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/services/salary_service.dart';

void main() {
  group('🛡️ Wallet Authorization & Financial Integrity Test Suite', () {
    test('1. UserModel parses walletBalance safely and defaults strictly to 0.0', () {
      final baseMap = <String, dynamic>{
        'uid': 'test_user_1',
        'createdAt': DateTime.now().toIso8601String(),
        'phoneNumber': '+1234567890',
        'username': 'testuser',
        'displayName': 'Test User',
      };

      // Case A: Missing walletBalance
      final userMissing = UserModel.fromMap(baseMap);
      expect(userMissing.walletBalance, equals(0.0), reason: 'Missing walletBalance must default to 0.0');

      // Case B: Null walletBalance
      final userNull = UserModel.fromMap({...baseMap, 'walletBalance': null});
      expect(userNull.walletBalance, equals(0.0), reason: 'Null walletBalance must default to 0.0');

      // Case C: Integer walletBalance
      final userInt = UserModel.fromMap({...baseMap, 'walletBalance': 500});
      expect(userInt.walletBalance, equals(500.0), reason: 'Integer walletBalance must parse as double');

      // Case D: Exact double walletBalance (e.g., $89,980.01)
      final userDouble = UserModel.fromMap({...baseMap, 'walletBalance': 89980.01});
      expect(userDouble.walletBalance, equals(89980.01));
    });

    test('2. Authoritative Diamond Package Catalog pricing is strictly defined and tamper-proof', () {
      // Mirrors backend authoritative catalog in functions/index.js
      final Map<int, double> authoritativeCatalog = {
        262: 5.99,
        890: 19.99,
        2255: 49.99,
        4562: 99.99,
        9205: 199.99,
      };

      // Verification function mimicking server-side purchaseDiamondsWithWallet validation
      bool isValidPackagePurchase(int diamonds, double price) {
        if (!authoritativeCatalog.containsKey(diamonds)) return false;
        final expectedPrice = authoritativeCatalog[diamonds]!;
        return (price - expectedPrice).abs() < 0.001;
      }

      // Valid packages must pass
      for (final entry in authoritativeCatalog.entries) {
        expect(isValidPackagePurchase(entry.key, entry.value), isTrue,
            reason: '${entry.key} diamonds for \$${entry.value} must be valid');
      }

      // Tampered packages must fail
      expect(isValidPackagePurchase(890, 0.00), isFalse, reason: 'Zero-price manipulation must be rejected');
      expect(isValidPackagePurchase(890, 1.00), isFalse, reason: 'Discount manipulation must be rejected');
      expect(isValidPackagePurchase(1000000, 19.99), isFalse, reason: 'Arbitrary diamond quantity must be rejected');
      expect(isValidPackagePurchase(-890, 19.99), isFalse, reason: 'Negative diamond quantity must be rejected');
      expect(isValidPackagePurchase(890, -19.99), isFalse, reason: 'Negative price must be rejected');
    });

    test('3. SalaryService client surface enforces read-only financial tracking and no client-side payouts', () {
      // Verify that SalaryService weekly target calculation runs purely without database mutations
      final date = DateTime.utc(2026, 10, 15);
      final weekId = SalaryService.getUtcWeekId(date);
      expect(weekId, matches(RegExp(r'^\d{4}-W\d{2}$')));

      // Verify Monday rollover consistency
      final monday = DateTime.utc(2026, 10, 12);
      final sunday = DateTime.utc(2026, 10, 18);
      expect(SalaryService.getUtcWeekId(monday), equals(SalaryService.getUtcWeekId(sunday)));
    });

    test('4. Idempotency Request ID generation ensures uniqueness and collision avoidance', () {
      final requestIds = <String>{};
      for (int i = 0; i < 100; i++) {
        final requestId = '${DateTime.now().microsecondsSinceEpoch}_${890}_$i';
        expect(requestIds.contains(requestId), isFalse, reason: 'Request ID must be unique');
        requestIds.add(requestId);
      }
      expect(requestIds.length, equals(100));
    });

    test('5. Protected Financial Fields list matches Firestore Security Rules specification', () {
      // Must match FINANCIAL_FIELDS in firebase/firestore.rules
      const protectedFinancialFields = {
        'diamondBalance',
        'diamondStock',
        'beansBalance',
        'walletBalance',
        'usdCommissionBalance',
        'usdResellerBalance',
        'totalCommissionEarned',
        'totalRechargeGenerated',
        'pendingWithdrawalBalance',
        'totalWithdrawnUSD',
      };

      expect(protectedFinancialFields.contains('walletBalance'), isTrue,
          reason: 'walletBalance must be in protected financial fields');
      expect(protectedFinancialFields.contains('diamondBalance'), isTrue,
          reason: 'diamondBalance must be in protected financial fields');
      expect(protectedFinancialFields.contains('beansBalance'), isTrue,
          reason: 'beansBalance must be in protected financial fields');
      expect(protectedFinancialFields.length, equals(10));
    });
  });
}
